#property strict
#property version   "5.0"
#property description "QM5_10178 TradingView VWAP mean reversion forex"

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
input int    qm_ea_id                   = 10178;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_CURRENT;
input int    strategy_vwap_period              = 20;
input double strategy_band_deviation_mult      = 2.0;
input int    strategy_rsi_period               = 14;
input double strategy_rsi_long_level           = 30.0;
input double strategy_rsi_short_level          = 70.0;
input int    strategy_volume_sma_period        = 20;
input double strategy_volume_spike_mult        = 2.0;
input int    strategy_adx_period               = 14;
input double strategy_adx_max                  = 25.0;
input int    strategy_atr_period               = 14;
input double strategy_atr_stop_mult            = 1.5;
input double strategy_percent_stop             = 0.75;
input double strategy_max_spread_stop_fraction = 0.15;
input int    strategy_time_stop_bars           = 24;

double g_vwap_current = 0.0;
double g_upper_band_current = 0.0;
double g_lower_band_current = 0.0;

ENUM_TIMEFRAMES Strategy_TF()
  {
   return (strategy_signal_tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : strategy_signal_tf;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_RollingVwapBands(const int shift,
                               double &vwap,
                               double &upper_band,
                               double &lower_band)
  {
   vwap = 0.0;
   upper_band = 0.0;
   lower_band = 0.0;

   const ENUM_TIMEFRAMES tf = Strategy_TF();
   const int period = MathMax(2, strategy_vwap_period);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int needed = shift + period;
   if(CopyRates(_Symbol, tf, 0, needed, rates) < needed)
      return false;

   double pv_sum = 0.0;
   double volume_sum = 0.0;

   for(int offset = 0; offset < period; ++offset)
     {
      const int bar_shift = shift + offset;
      const double high = rates[bar_shift].high;
      const double low = rates[bar_shift].low;
      const double close = rates[bar_shift].close;
      const long tick_volume = rates[bar_shift].tick_volume;
      if(high <= 0.0 || low <= 0.0 || close <= 0.0)
         return false;

      const double volume = (tick_volume > 0) ? (double)tick_volume : 1.0;
      const double typical = (high + low + close) / 3.0;
      pv_sum += typical * volume;
      volume_sum += volume;
     }

   if(volume_sum <= 0.0)
      return false;

   vwap = pv_sum / volume_sum;

   double deviation_sum = 0.0;
   for(int offset = 0; offset < period; ++offset)
     {
      const int bar_shift = shift + offset;
      const double high = rates[bar_shift].high;
      const double low = rates[bar_shift].low;
      const double close = rates[bar_shift].close;
      const long tick_volume = rates[bar_shift].tick_volume;
      const double volume = (tick_volume > 0) ? (double)tick_volume : 1.0;
      const double typical = (high + low + close) / 3.0;
      deviation_sum += MathAbs(typical - vwap) * volume;
     }

   const double deviation = deviation_sum / volume_sum;
   upper_band = vwap + deviation * strategy_band_deviation_mult;
   lower_band = vwap - deviation * strategy_band_deviation_mult;
   return (vwap > 0.0 && upper_band > lower_band && deviation > 0.0);
  }

double Strategy_VolumeSMA(const int shift)
  {
   const ENUM_TIMEFRAMES tf = Strategy_TF();
   const int period = MathMax(1, strategy_volume_sma_period);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int needed = shift + period;
   if(CopyRates(_Symbol, tf, 0, needed, rates) < needed)
      return 0.0;

   double sum = 0.0;
   int samples = 0;
   for(int offset = 0; offset < period; ++offset)
     {
      const long tick_volume = rates[shift + offset].tick_volume;
      if(tick_volume <= 0)
         continue;
      sum += (double)tick_volume;
      samples++;
     }
   if(samples <= 0)
      return 0.0;
   return sum / samples;
  }

double Strategy_StopDistance(const QM_OrderType side, const double entry)
  {
   const double atr = QM_ATR(_Symbol, Strategy_TF(), strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return 0.0;

   const double pct_distance = entry * MathMax(0.0, strategy_percent_stop) / 100.0;
   const double atr_distance = atr * MathMax(0.0, strategy_atr_stop_mult);
   double distance = 0.0;
   if(pct_distance > 0.0 && atr_distance > 0.0)
      distance = MathMin(pct_distance, atr_distance);
   else if(pct_distance > 0.0)
      distance = pct_distance;
   else
      distance = atr_distance;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || distance <= point)
      return 0.0;

   const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(strategy_max_spread_stop_fraction > 0.0 &&
      spread > distance * strategy_max_spread_stop_fraction)
      return 0.0;

   return distance;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_vwap_period < 2 || strategy_volume_sma_period < 1 ||
      strategy_band_deviation_mult <= 0.0 || strategy_volume_spike_mult <= 0.0 ||
      strategy_atr_period <= 0 || strategy_adx_period <= 0)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   double vwap_1 = 0.0;
   double upper_1 = 0.0;
   double lower_1 = 0.0;
   double vwap_2 = 0.0;
   double upper_2 = 0.0;
   double lower_2 = 0.0;
   if(!Strategy_RollingVwapBands(1, vwap_1, upper_1, lower_1))
      return false;
   if(!Strategy_RollingVwapBands(2, vwap_2, upper_2, lower_2))
      return false;

   g_vwap_current = vwap_1;
   g_upper_band_current = upper_1;
   g_lower_band_current = lower_1;

   const ENUM_TIMEFRAMES tf = Strategy_TF();
   MqlRates recent[];
   ArraySetAsSeries(recent, true);
   if(CopyRates(_Symbol, tf, 0, 3, recent) < 3)
      return false;

   const double close_1 = recent[1].close;
   const double close_2 = recent[2].close;
   if(close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   const double adx = QM_ADX(_Symbol, tf, strategy_adx_period, 1);
   if(rsi <= 0.0 || adx <= 0.0 || adx > strategy_adx_max)
      return false;

   const double volume_sma = Strategy_VolumeSMA(1);
   const long volume_1_raw = recent[1].tick_volume;
   if(volume_sma <= 0.0 || volume_1_raw <= 0)
      return false;
   if((double)volume_1_raw > volume_sma * strategy_volume_spike_mult)
      return false;

   if(close_1 < lower_1 && close_2 >= lower_2 && rsi <= strategy_rsi_long_level)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double stop_distance = Strategy_StopDistance(QM_BUY, entry);
      if(entry <= 0.0 || stop_distance <= 0.0)
         return false;
      req.type = QM_BUY;
      req.price = entry;
      req.sl = Strategy_NormalizePrice(entry - stop_distance);
      req.tp = 0.0;
      req.reason = "TV_VWAP_MR_FOREX_LONG";
      return (req.sl > 0.0 && req.sl < entry);
     }

   if(close_1 > upper_1 && close_2 <= upper_2 && rsi >= strategy_rsi_short_level)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double stop_distance = Strategy_StopDistance(QM_SELL, entry);
      if(entry <= 0.0 || stop_distance <= 0.0)
         return false;
      req.type = QM_SELL;
      req.price = entry;
      req.sl = Strategy_NormalizePrice(entry + stop_distance);
      req.tp = 0.0;
      req.reason = "TV_VWAP_MR_FOREX_SHORT";
      return (req.sl > entry);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card forbids widening stops and specifies no trailing, partial, or BE logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int period_seconds = PeriodSeconds(Strategy_TF());
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
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(g_vwap_current > 0.0 && market > 0.0)
        {
         if((is_buy && market >= g_vwap_current) || (!is_buy && market <= g_vwap_current))
            return true;
        }

      if(strategy_time_stop_bars > 0 && period_seconds > 0)
        {
         const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         if(open_time > 0 && TimeCurrent() - open_time >= strategy_time_stop_bars * period_seconds)
            return true;
        }
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
   return false; // defer to QM_NewsAllowsTrade(...)
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
