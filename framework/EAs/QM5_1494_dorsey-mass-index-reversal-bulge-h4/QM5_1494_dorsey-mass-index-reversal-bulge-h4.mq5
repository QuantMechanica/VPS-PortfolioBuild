#property strict
#property version   "5.0"
#property description "QM5_1494 Dorsey Mass Index Reversal Bulge H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  - closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        - risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() - use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly -
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1494;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf              = PERIOD_H4;
input int             strategy_mass_ema_period        = 9;
input int             strategy_mass_sum_period        = 25;
input int             strategy_bulge_lookback         = 16;
input double          strategy_bulge_setup_threshold  = 27.0;
input double          strategy_bulge_trigger_threshold = 26.5;
input int             strategy_atr_period             = 14;
input int             strategy_atr_baseline_bars      = 200;
input double          strategy_atr_floor_mult         = 0.60;
input int             strategy_daily_sma_period       = 50;
input int             strategy_daily_sma_slope_bars   = 5;
input int             strategy_cooldown_bars          = 30;
input double          strategy_atr_sl_mult            = 2.0;
input double          strategy_tp1_atr_mult           = 1.5;
input double          strategy_tp1_fraction           = 0.60;
input int             strategy_time_stop_bars         = 24;
input double          strategy_spread_atr_fraction    = 0.15;
input int             strategy_warmup_bars            = 250;

MqlRates g_h4_rates[];
double   g_mass_index[];
double   g_close_ema[];
bool     g_mass_ready = false;
int      g_cached_signal_dir = 0;
int      g_cached_peak_shift = -1;
double   g_cached_atr = 0.0;
ulong    g_tp1_ticket = 0;
bool     g_tp1_done = false;

int Strategy_MaxInt(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

int Strategy_MinBarsRequired()
  {
   int bars = strategy_warmup_bars;
   bars = Strategy_MaxInt(bars, strategy_atr_baseline_bars + strategy_atr_period + 5);
   bars = Strategy_MaxInt(bars, strategy_bulge_lookback + strategy_mass_sum_period + strategy_mass_ema_period * 6 + 10);
   bars = Strategy_MaxInt(bars, strategy_cooldown_bars + strategy_bulge_lookback + strategy_mass_sum_period + 10);
   return bars;
  }

bool Strategy_InputsValid()
  {
   if(strategy_signal_tf != PERIOD_H4)
      return false;
   if(strategy_mass_ema_period <= 1 ||
      strategy_mass_sum_period <= 1 ||
      strategy_bulge_lookback <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_baseline_bars < 20 ||
      strategy_daily_sma_period <= 0 ||
      strategy_daily_sma_slope_bars <= 0 ||
      strategy_cooldown_bars < 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_tp1_atr_mult <= 0.0 ||
      strategy_tp1_fraction <= 0.0 ||
      strategy_tp1_fraction >= 1.0 ||
      strategy_time_stop_bars <= 0 ||
      strategy_spread_atr_fraction <= 0.0 ||
      strategy_warmup_bars < 250)
      return false;
   if(strategy_bulge_setup_threshold <= strategy_bulge_trigger_threshold ||
      strategy_atr_floor_mult <= 0.0)
      return false;
   return true;
  }

bool Strategy_CopyH4Rates(const int bars_needed)
  {
   ArrayFree(g_h4_rates);
   ResetLastError();
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, bars_needed, g_h4_rates); // perf-allowed: closed-bar Mass Index state
   if(copied < bars_needed)
      return false;
   ArraySetAsSeries(g_h4_rates, true);
   return true;
  }

double Strategy_TrueRange(const int shift)
  {
   const int n = ArraySize(g_h4_rates);
   if(shift < 0 || shift + 1 >= n)
      return 0.0;
   const double hl = g_h4_rates[shift].high - g_h4_rates[shift].low;
   const double hc = MathAbs(g_h4_rates[shift].high - g_h4_rates[shift + 1].close);
   const double lc = MathAbs(g_h4_rates[shift].low - g_h4_rates[shift + 1].close);
   return MathMax(hl, MathMax(hc, lc));
  }

double Strategy_ATRAt(const int shift)
  {
   if(shift < 0 || shift + strategy_atr_period >= ArraySize(g_h4_rates))
      return 0.0;
   double total = 0.0;
   for(int i = 0; i < strategy_atr_period; ++i)
     {
      const double tr = Strategy_TrueRange(shift + i);
      if(tr <= 0.0)
         return 0.0;
      total += tr;
     }
   return total / (double)strategy_atr_period;
  }

double Strategy_ATRBaseline(const int shift)
  {
   if(shift < 0 || shift + strategy_atr_baseline_bars + strategy_atr_period >= ArraySize(g_h4_rates))
      return 0.0;
   double total = 0.0;
   for(int i = 0; i < strategy_atr_baseline_bars; ++i)
     {
      const double atr = Strategy_ATRAt(shift + i);
      if(atr <= 0.0)
         return 0.0;
      total += atr;
     }
   return total / (double)strategy_atr_baseline_bars;
  }

bool Strategy_RebuildMassCache()
  {
   g_mass_ready = false;
   g_cached_signal_dir = 0;
   g_cached_peak_shift = -1;
   g_cached_atr = 0.0;

   if(!Strategy_InputsValid())
      return false;

   const int bars_needed = Strategy_MinBarsRequired();
   if(!Strategy_CopyH4Rates(bars_needed))
      return false;

   const int n = ArraySize(g_h4_rates);
   double hl_ema[];
   double hl_ema2[];
   double ratio[];
   ArrayResize(g_mass_index, n);
   ArrayResize(g_close_ema, n);
   ArrayResize(hl_ema, n);
   ArrayResize(hl_ema2, n);
   ArrayResize(ratio, n);
   ArraySetAsSeries(g_mass_index, true);
   ArraySetAsSeries(g_close_ema, true);
   ArraySetAsSeries(hl_ema, true);
   ArraySetAsSeries(hl_ema2, true);
   ArraySetAsSeries(ratio, true);

   const double alpha = 2.0 / ((double)strategy_mass_ema_period + 1.0);
   for(int i = n - 1; i >= 0; --i)
     {
      const double hl = g_h4_rates[i].high - g_h4_rates[i].low;
      if(hl <= 0.0 || g_h4_rates[i].close <= 0.0)
         return false;
      if(i == n - 1)
        {
         hl_ema[i] = hl;
         hl_ema2[i] = hl_ema[i];
         g_close_ema[i] = g_h4_rates[i].close;
        }
      else
        {
         hl_ema[i] = alpha * hl + (1.0 - alpha) * hl_ema[i + 1];
         hl_ema2[i] = alpha * hl_ema[i] + (1.0 - alpha) * hl_ema2[i + 1];
         g_close_ema[i] = alpha * g_h4_rates[i].close + (1.0 - alpha) * g_close_ema[i + 1];
        }
      if(hl_ema2[i] <= 0.0)
         return false;
      ratio[i] = hl_ema[i] / hl_ema2[i];
     }

   for(int i = n - 1; i >= 0; --i)
     {
      if(i + strategy_mass_sum_period - 1 >= n)
        {
         g_mass_index[i] = 0.0;
         continue;
        }
      double sum = 0.0;
      for(int k = 0; k < strategy_mass_sum_period; ++k)
         sum += ratio[i + k];
      g_mass_index[i] = sum;
     }

   g_cached_atr = Strategy_ATRAt(0);
   if(g_cached_atr <= 0.0)
      return false;

   g_mass_ready = true;
   return true;
  }

int Strategy_PeakShiftForSignal(const int signal_shift)
  {
   if(!g_mass_ready)
      return -1;
   const int n = ArraySize(g_mass_index);
   if(signal_shift < 0 || signal_shift + strategy_bulge_lookback >= n)
      return -1;

   int peak_shift = -1;
   double peak_mass = -DBL_MAX;
   for(int shift = signal_shift + 1; shift <= signal_shift + strategy_bulge_lookback; ++shift)
     {
      if(g_mass_index[shift] > peak_mass)
        {
         peak_mass = g_mass_index[shift];
         peak_shift = shift;
        }
     }

   if(peak_shift < 0 || peak_mass <= strategy_bulge_setup_threshold)
      return -1;
   return peak_shift;
  }

bool Strategy_BulgeTriggeredAt(const int signal_shift)
  {
   if(!g_mass_ready || signal_shift < 0 || signal_shift + 1 >= ArraySize(g_mass_index))
      return false;
   return (g_mass_index[signal_shift] < strategy_bulge_trigger_threshold &&
           g_mass_index[signal_shift + 1] >= strategy_bulge_trigger_threshold &&
           Strategy_PeakShiftForSignal(signal_shift) >= 0);
  }

bool Strategy_RecentBulgeTriggered()
  {
   for(int shift = 1; shift <= strategy_cooldown_bars; ++shift)
     {
      if(Strategy_BulgeTriggeredAt(shift))
         return true;
     }
   return false;
  }

int Strategy_DirectionFromPeak(const int peak_shift)
  {
   if(peak_shift < 0 || peak_shift >= ArraySize(g_h4_rates))
      return 0;
   const double close_peak = g_h4_rates[peak_shift].close;
   const double ema_peak = g_close_ema[peak_shift];
   if(close_peak <= 0.0 || ema_peak <= 0.0)
      return 0;
   if(ema_peak > close_peak)
      return 1;
   if(close_peak > ema_peak)
      return -1;
   return 0;
  }

bool Strategy_MacroBiasAllows(const int direction)
  {
   const double d1_close = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_daily_sma_period, 1, PRICE_CLOSE);
   const double d1_sma_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_daily_sma_period, 1 + strategy_daily_sma_slope_bars, PRICE_CLOSE);
   if(d1_close <= 0.0 || d1_sma <= 0.0 || d1_sma_prior <= 0.0)
      return false;

   if(direction > 0)
      return (d1_close > d1_sma && d1_sma > d1_sma_prior);
   if(direction < 0)
      return (d1_close < d1_sma && d1_sma < d1_sma_prior);
   return false;
  }

bool Strategy_ATRFloorAllows()
  {
   const double atr_baseline = Strategy_ATRBaseline(0);
   if(g_cached_atr <= 0.0 || atr_baseline <= 0.0)
      return false;
   return (g_cached_atr > strategy_atr_floor_mult * atr_baseline);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_InputsValid())
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid)
      return true;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;
   if((ask - bid) > atr * strategy_spread_atr_fraction)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_RebuildMassCache())
      return false;
   if(QM_SMA(_Symbol, strategy_signal_tf, 1, strategy_warmup_bars, PRICE_CLOSE) <= 0.0)
      return false;
   if(!Strategy_BulgeTriggeredAt(0))
      return false;
   if(Strategy_RecentBulgeTriggered())
      return false;
   if(!Strategy_ATRFloorAllows())
      return false;

   const int peak_shift = Strategy_PeakShiftForSignal(0);
   const int direction = Strategy_DirectionFromPeak(peak_shift);
   if(direction == 0 || !Strategy_MacroBiasAllows(direction))
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const double sl_dist = g_cached_atr * strategy_atr_sl_mult;
   if(sl_dist <= 0.0)
      return false;

   g_cached_signal_dir = direction;
   g_cached_peak_shift = peak_shift;
   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = (direction > 0) ? NormalizeDouble(ask - sl_dist, _Digits)
                            : NormalizeDouble(bid + sl_dist, _Digits);
   req.tp = 0.0;
   req.reason = StringFormat("dorsey_mass_bulge dir=%d peak=%d mass=%.2f atr=%.8f",
                             direction, peak_shift, g_mass_index[0], g_cached_atr);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_tp1_ticket = 0;
   g_tp1_done = false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   bool saw_own_position = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      saw_own_position = true;
      if(g_tp1_ticket != ticket)
        {
         g_tp1_ticket = ticket;
         g_tp1_done = false;
        }
      if(g_tp1_done)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
      if(open_price <= 0.0 || volume <= 0.0 || bid <= 0.0 || ask <= 0.0 || atr <= 0.0)
         continue;

      const double target = is_buy ? (open_price + strategy_tp1_atr_mult * atr)
                                   : (open_price - strategy_tp1_atr_mult * atr);
      const bool reached = is_buy ? (bid >= target) : (ask <= target);
      if(!reached)
         continue;

      const double lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_tp1_fraction);
      if(lots > 0.0 && lots < volume)
        {
         if(QM_TM_PartialClose(ticket, lots, QM_EXIT_PARTIAL))
            g_tp1_done = true;
        }
     }

   if(!saw_own_position)
     {
      g_tp1_ticket = 0;
      g_tp1_done = false;
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_elapsed = iBarShift(_Symbol, strategy_signal_tf, open_time, false);
      if(!g_tp1_done && bars_elapsed >= strategy_time_stop_bars)
         return true;

      const double ema9 = QM_EMA(_Symbol, strategy_signal_tf, strategy_mass_ema_period, 1, PRICE_CLOSE);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ema9 <= 0.0 || bid <= 0.0 || ask <= 0.0)
         continue;

      if(is_buy && bid < ema9)
         return true;
      if(!is_buy && ask > ema9)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        60,
                        60,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
