#property strict
#property version   "5.0"
#property description "QM5_10867 TradingView XAUUSD Quant SMC Trader"

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
input int    qm_ea_id                   = 10867;
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
input int    strategy_pivot_lookback       = 5;
input int    strategy_pivot_scan_bars      = 80;
input int    strategy_atr_period           = 14;
input double strategy_sweep_wick_min_atr   = 0.40;
input int    strategy_ema_slope_period     = 20;    // 0 disables EMA slope confirmation.
input double strategy_stop_atr_buffer      = 0.20;
input double strategy_min_stop_atr         = 1.00;
input double strategy_target_r             = 1.50;
input int    strategy_session_start_hour   = 13;
input int    strategy_session_end_hour     = 17;
input int    strategy_cooldown_bars        = 5;

int      g_last_smc_signal = 0;                 // +1 long, -1 short, 0 none.
datetime g_last_smc_signal_time = 0;
datetime g_exit_signal_consumed_time = 0;
bool     g_had_open_position = false;
int      g_cooldown_bars_remaining = 0;

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &ptype)
  {
   ptype = POSITION_TYPE_BUY;
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy_IsSessionOpen()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int start_h = (strategy_session_start_hour < 0) ? 0 : ((strategy_session_start_hour > 23) ? 23 : strategy_session_start_hour);
   const int end_h = (strategy_session_end_hour < 0) ? 0 : ((strategy_session_end_hour > 23) ? 23 : strategy_session_end_hour);
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (dt.hour >= start_h && dt.hour < end_h);
   return (dt.hour >= start_h || dt.hour < end_h);
  }

bool Strategy_IsPivotLow(const MqlRates &rates[], const int idx, const int lookback, const int copied)
  {
   if(idx < lookback || idx + lookback >= copied)
      return false;
   const double v = rates[idx].low;
   for(int j = 1; j <= lookback; ++j)
     {
      if(v >= rates[idx - j].low || v > rates[idx + j].low)
         return false;
     }
   return true;
  }

bool Strategy_IsPivotHigh(const MqlRates &rates[], const int idx, const int lookback, const int copied)
  {
   if(idx < lookback || idx + lookback >= copied)
      return false;
   const double v = rates[idx].high;
   for(int j = 1; j <= lookback; ++j)
     {
      if(v <= rates[idx - j].high || v < rates[idx + j].high)
         return false;
     }
   return true;
  }

bool Strategy_FindRecentPivots(const MqlRates &rates[],
                               const int copied,
                               const int lookback,
                               double &swing_low,
                               double &swing_high)
  {
   swing_low = 0.0;
   swing_high = 0.0;
   for(int i = lookback; i < copied - lookback; ++i)
     {
      if(swing_low <= 0.0 && Strategy_IsPivotLow(rates, i, lookback, copied))
         swing_low = rates[i].low;
      if(swing_high <= 0.0 && Strategy_IsPivotHigh(rates, i, lookback, copied))
         swing_high = rates[i].high;
      if(swing_low > 0.0 && swing_high > 0.0)
         return true;
     }
   return (swing_low > 0.0 || swing_high > 0.0);
  }

int Strategy_EvaluateSweepSignal(double &entry_ref, double &sl_ref, double &tp_ref)
  {
   entry_ref = 0.0;
   sl_ref = 0.0;
   tp_ref = 0.0;

   const int lookback = (strategy_pivot_lookback < 1) ? 1 : strategy_pivot_lookback;
   const int scan_floor = lookback * 2 + 8;
   const int scan = (strategy_pivot_scan_bars < scan_floor) ? scan_floor : strategy_pivot_scan_bars;
   const int needed = scan + (lookback * 2) + 4;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, needed, rates); // perf-allowed: bounded structural OHLC scan; Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   if(copied < lookback * 2 + 3)
      return 0;

   double swing_low = 0.0;
   double swing_high = 0.0;
   if(!Strategy_FindRecentPivots(rates, copied, lookback, swing_low, swing_high))
      return 0;

   const int atr_period = (strategy_atr_period < 1) ? 1 : strategy_atr_period;
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, atr_period, 1);
   if(atr <= 0.0)
      return 0;

   if(strategy_ema_slope_period > 0)
     {
      const double ema1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slope_period, 1);
      const double ema2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slope_period, 2);
      if(ema1 <= 0.0 || ema2 <= 0.0)
         return 0;
     }

   const double wick_min = MathMax(0.0, strategy_sweep_wick_min_atr) * atr;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double rr = MathMax(0.1, strategy_target_r);
   const double min_stop = MathMax(0.0, strategy_min_stop_atr) * atr;
   const double stop_buffer = MathMax(0.0, strategy_stop_atr_buffer) * atr;

   if(swing_low > 0.0 &&
      rates[0].low < swing_low &&
      rates[0].close > swing_low &&
      (swing_low - rates[0].low) >= wick_min)
     {
      if(strategy_ema_slope_period > 0 &&
         QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slope_period, 1) <=
         QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slope_period, 2))
         return 0;

      entry_ref = ask;
      sl_ref = rates[0].low - stop_buffer;
      if(entry_ref - sl_ref < min_stop)
         sl_ref = entry_ref - min_stop;
      tp_ref = entry_ref + ((entry_ref - sl_ref) * rr);
      g_last_smc_signal_time = rates[0].time;
      return 1;
     }

   if(swing_high > 0.0 &&
      rates[0].high > swing_high &&
      rates[0].close < swing_high &&
      (rates[0].high - swing_high) >= wick_min)
     {
      if(strategy_ema_slope_period > 0 &&
         QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slope_period, 1) >=
         QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slope_period, 2))
         return 0;

      entry_ref = bid;
      sl_ref = rates[0].high + stop_buffer;
      if(sl_ref - entry_ref < min_stop)
         sl_ref = entry_ref + min_stop;
      tp_ref = entry_ref - ((sl_ref - entry_ref) * rr);
      g_last_smc_signal_time = rates[0].time;
      return -1;
     }

   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return !Strategy_IsSessionOpen();
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

   if(g_cooldown_bars_remaining > 0)
     {
      --g_cooldown_bars_remaining;
      return false;
     }

   double entry = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   const int signal = Strategy_EvaluateSweepSignal(entry, sl, tp);
   g_last_smc_signal = signal;

   ENUM_POSITION_TYPE ptype;
   if(signal == 0 || Strategy_HasOpenPosition(ptype))
      return false;

   req.type = (signal > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = (signal > 0) ? "SMC_SWEEP_RECLAIM_LONG" : "SMC_SWEEP_RECLAIM_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   const bool has_position = Strategy_HasOpenPosition(ptype);
   if(g_had_open_position && !has_position)
      g_cooldown_bars_remaining = (strategy_cooldown_bars < 0) ? 0 : strategy_cooldown_bars;
   g_had_open_position = has_position;
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(g_last_smc_signal == 0 || g_last_smc_signal_time <= 0 ||
      g_last_smc_signal_time == g_exit_signal_consumed_time)
      return false;

   ENUM_POSITION_TYPE ptype;
   if(!Strategy_HasOpenPosition(ptype))
      return false;

   const bool opposite_long = (ptype == POSITION_TYPE_SELL && g_last_smc_signal > 0);
   const bool opposite_short = (ptype == POSITION_TYPE_BUY && g_last_smc_signal < 0);
   if(opposite_long || opposite_short)
     {
      g_exit_signal_consumed_time = g_last_smc_signal_time;
      g_cooldown_bars_remaining = (strategy_cooldown_bars < 0) ? 0 : strategy_cooldown_bars;
      return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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
