#property strict
#property version   "5.0"
#property description "QM5_10866 TradingView SMC Fractal BOS Retest"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
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
input int    qm_ea_id                   = 10866;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
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
input int    strategy_fractal_side_bars      = 2;
input int    strategy_fractal_scan_bars      = 80;
input int    strategy_atr_period             = 14;
input double strategy_atr_buffer_mult        = 0.25;
input double strategy_min_stop_atr_mult      = 0.80;
input double strategy_target_r               = 1.50;
input int    strategy_cooldown_bars          = 3;
input double strategy_spread_stop_max_frac   = 0.15;
input bool   strategy_use_atr_median_filter  = false;
input int    strategy_atr_median_bars        = 50;

bool g_had_position = false;
int  g_cooldown_bars_remaining = 0;
bool g_pending_opposite_exit = false;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_CopyRates(MqlRates &rates[], const int bars_needed)
  {
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, bars_needed, rates); // perf-allowed: bounded fractal OHLC window, called only from framework new-bar-gated EntrySignal.
   return (copied >= bars_needed);
  }

bool Strategy_IsFractalHigh(const MqlRates &rates[], const int count, const int center, const int side_bars)
  {
   const double pivot = rates[center].high;
   if(pivot <= 0.0)
      return false;
   for(int offset = 1; offset <= side_bars; ++offset)
     {
      if(rates[center - offset].high >= pivot || rates[center + offset].high >= pivot)
         return false;
     }
   return true;
  }

bool Strategy_IsFractalLow(const MqlRates &rates[], const int count, const int center, const int side_bars)
  {
   const double pivot = rates[center].low;
   if(pivot <= 0.0)
      return false;
   for(int offset = 1; offset <= side_bars; ++offset)
     {
      if(rates[center - offset].low <= pivot || rates[center + offset].low <= pivot)
         return false;
     }
   return true;
  }

bool Strategy_FindRecentFractals(const MqlRates &rates[],
                                 const int count,
                                 const int side_bars,
                                 double &fractal_high,
                                 double &fractal_low)
  {
   fractal_high = 0.0;
   fractal_low = 0.0;
   if(count < side_bars * 2 + 3)
      return false;

   for(int center = side_bars; center < count - side_bars; ++center)
     {
      if(fractal_high <= 0.0 && Strategy_IsFractalHigh(rates, count, center, side_bars))
         fractal_high = rates[center].high;
      if(fractal_low <= 0.0 && Strategy_IsFractalLow(rates, count, center, side_bars))
         fractal_low = rates[center].low;
      if(fractal_high > 0.0 && fractal_low > 0.0)
         return true;
     }
   return (fractal_high > 0.0 && fractal_low > 0.0);
  }

bool Strategy_ATRMedianPass()
  {
   if(!strategy_use_atr_median_filter)
      return true;

   const int lookback = MathMax(5, strategy_atr_median_bars);
   double atr_values[];
   ArrayResize(atr_values, lookback);
   int samples = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, MathMax(1, strategy_atr_period), shift);
      if(atr <= 0.0)
         continue;
      atr_values[samples] = atr;
      samples++;
     }
   if(samples < 5)
      return false;

   ArrayResize(atr_values, samples);
   ArraySort(atr_values);
   const double median = (samples % 2 == 1)
                         ? atr_values[samples / 2]
                         : 0.5 * (atr_values[samples / 2 - 1] + atr_values[samples / 2]);
   const double current_atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, MathMax(1, strategy_atr_period), 1);
   return (current_atr > median);
  }

int Strategy_BOSSignal(const MqlRates &rates[], const int count, const double fractal_high, const double fractal_low)
  {
   if(count < 2 || fractal_high <= 0.0 || fractal_low <= 0.0)
      return 0;

   const double close_last = rates[0].close;
   const double close_prev = rates[1].close;
   if(close_last <= 0.0 || close_prev <= 0.0)
      return 0;

   if(close_last > fractal_high && close_prev <= fractal_high)
      return 1;
   if(close_last < fractal_low && close_prev >= fractal_low)
      return -1;
   return 0;
  }

void Strategy_UpdateCooldownState(const bool has_position)
  {
   if(g_had_position && !has_position)
      g_cooldown_bars_remaining = MathMax(0, strategy_cooldown_bars);
   else if(!has_position && g_cooldown_bars_remaining > 0)
      g_cooldown_bars_remaining--;
   g_had_position = has_position;
  }

// No Trade Filter (time, spread, news): framework owns time/news; block bad quotes.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask <= 0.0 || bid <= 0.0 || ask <= bid);
  }

// Trade Entry: confirmed fractal break of structure on the closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int side_bars = MathMax(1, strategy_fractal_side_bars);
   const int scan_bars = MathMax(side_bars * 2 + 10, strategy_fractal_scan_bars);
   MqlRates rates[];
   if(!Strategy_CopyRates(rates, scan_bars))
      return false;

   double fractal_high = 0.0;
   double fractal_low = 0.0;
   if(!Strategy_FindRecentFractals(rates, scan_bars, side_bars, fractal_high, fractal_low))
      return false;

   const bool has_position = Strategy_HasOpenPosition();
   Strategy_UpdateCooldownState(has_position);

   const int signal = Strategy_BOSSignal(rates, scan_bars, fractal_high, fractal_low);
   if(has_position)
     {
      if(signal != 0)
        {
         const int magic = QM_FrameworkMagic();
         for(int i = PositionsTotal() - 1; i >= 0; --i)
           {
            const ulong ticket = PositionGetTicket(i);
            if(ticket == 0 || !PositionSelectByTicket(ticket))
               continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol)
               continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != magic)
               continue;

            const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if((pos_type == POSITION_TYPE_BUY && signal < 0) ||
               (pos_type == POSITION_TYPE_SELL && signal > 0))
               g_pending_opposite_exit = true;
           }
        }
      return false;
     }

   if(g_cooldown_bars_remaining > 0 || signal == 0)
      return false;
   if(!Strategy_ATRMedianPass())
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, MathMax(1, strategy_atr_period), 1);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0 || atr <= 0.0)
      return false;

   if(signal > 0)
     {
      const double entry = ask;
      double stop = fractal_low - MathMax(0.0, strategy_atr_buffer_mult) * atr;
      const double min_stop = entry - MathMax(0.1, strategy_min_stop_atr_mult) * atr;
      if(stop > min_stop)
         stop = min_stop;
      const double stop_dist = entry - stop;
      if(stop_dist <= point || (ask - bid) > stop_dist * MathMax(0.0, strategy_spread_stop_max_frac))
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, stop);
      req.tp = QM_TM_NormalizePrice(_Symbol, entry + stop_dist * MathMax(0.1, strategy_target_r));
      req.reason = "TV_SMC_FRACTAL_BOS_LONG";
      return (req.sl > 0.0 && req.sl < entry && req.tp > entry);
     }

   const double entry = bid;
   double stop = fractal_high + MathMax(0.0, strategy_atr_buffer_mult) * atr;
   const double min_stop = entry + MathMax(0.1, strategy_min_stop_atr_mult) * atr;
   if(stop < min_stop)
      stop = min_stop;
   const double stop_dist = stop - entry;
   if(stop_dist <= point || (ask - bid) > stop_dist * MathMax(0.0, strategy_spread_stop_max_frac))
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = QM_TM_NormalizePrice(_Symbol, stop);
   req.tp = QM_TM_NormalizePrice(_Symbol, entry - stop_dist * MathMax(0.1, strategy_target_r));
   req.reason = "TV_SMC_FRACTAL_BOS_SHORT";
   return (req.sl > entry && req.tp > 0.0 && req.tp < entry);
  }

// Trade Management: card has no trailing, partial, or break-even rule.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: opposite confirmed BOS is latched on the new-bar entry pass.
bool Strategy_ExitSignal()
  {
   if(!g_pending_opposite_exit)
      return false;
   g_pending_opposite_exit = false;
   return true;
  }

// News Filter Hook: no card-specific override beyond the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10866_tv_smc_fractal\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
