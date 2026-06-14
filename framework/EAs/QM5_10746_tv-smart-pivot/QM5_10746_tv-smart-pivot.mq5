#property strict
#property version   "5.0"
#property description "QM5_10746 TradingView Smart Money Pivot Breakout"

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
input int    qm_ea_id                   = 10746;
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
input int    strategy_pivot_period      = 20;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 0.75;
input double strategy_sl_percent        = 1.0;
input double strategy_rr_target         = 2.0;
input int    strategy_min_same_dir_bars = 20;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card has no extra session/spread/regime filter beyond framework gates.
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   static double last_pivot_high = 0.0;
   static double last_pivot_low = 0.0;
   static int bars_since_long_entry = 100000;
   static int bars_since_short_entry = 100000;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_pivot_period < 2 ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_sl_percent <= 0.0 ||
      strategy_rr_target <= 0.0 ||
      strategy_min_same_dir_bars < 0)
      return false;

   if(bars_since_long_entry < 100000)
      bars_since_long_entry++;
   if(bars_since_short_entry < 100000)
      bars_since_short_entry++;

   const int candidate_shift = strategy_pivot_period + 1;
   const double candidate_high = iHigh(_Symbol, _Period, candidate_shift); // perf-allowed: confirmed pivot structural read inside QM_IsNewBar-gated EntrySignal.
   const double candidate_low = iLow(_Symbol, _Period, candidate_shift);   // perf-allowed: confirmed pivot structural read inside QM_IsNewBar-gated EntrySignal.
   bool is_pivot_high = (candidate_high > 0.0);
   bool is_pivot_low = (candidate_low > 0.0);

   for(int i = 1; i <= strategy_pivot_period; ++i)
     {
      const double right_high = iHigh(_Symbol, _Period, i); // perf-allowed: bounded 20-bar pivot confirmation inside QM_IsNewBar-gated EntrySignal.
      const double left_high = iHigh(_Symbol, _Period, candidate_shift + i); // perf-allowed: bounded 20-bar pivot confirmation inside QM_IsNewBar-gated EntrySignal.
      const double right_low = iLow(_Symbol, _Period, i); // perf-allowed: bounded 20-bar pivot confirmation inside QM_IsNewBar-gated EntrySignal.
      const double left_low = iLow(_Symbol, _Period, candidate_shift + i); // perf-allowed: bounded 20-bar pivot confirmation inside QM_IsNewBar-gated EntrySignal.

      if(right_high <= 0.0 || left_high <= 0.0 || right_low <= 0.0 || left_low <= 0.0)
         return false;

      if(right_high > candidate_high || left_high > candidate_high)
         is_pivot_high = false;
      if(right_low < candidate_low || left_low < candidate_low)
         is_pivot_low = false;
     }

   if(is_pivot_high)
      last_pivot_high = candidate_high;
   if(is_pivot_low)
      last_pivot_low = candidate_low;

   const double close_last = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar breakout check inside QM_IsNewBar-gated EntrySignal.
   const double close_prev = iClose(_Symbol, _Period, 2); // perf-allowed: closed-bar breakout cross check inside QM_IsNewBar-gated EntrySignal.
   if(close_last <= 0.0 || close_prev <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   if(last_pivot_high > 0.0 &&
      close_prev <= last_pivot_high &&
      close_last > last_pivot_high &&
      bars_since_long_entry >= strategy_min_same_dir_bars)
     {
      const double entry = ask;
      const double stop_dist = MathMax(strategy_atr_sl_mult * atr_value, entry * strategy_sl_percent / 100.0);
      const double sl = NormalizeDouble(entry - stop_dist, _Digits);
      const double tp = NormalizeDouble(entry + stop_dist * strategy_rr_target, _Digits);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
         return false;

      req.type = QM_BUY;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = sl;
      req.tp = tp;
      req.reason = "TV_SMART_PIVOT_LONG_BREAKOUT";
      bars_since_long_entry = 0;
      return true;
     }

   if(last_pivot_low > 0.0 &&
      close_prev >= last_pivot_low &&
      close_last < last_pivot_low &&
      bars_since_short_entry >= strategy_min_same_dir_bars)
     {
      const double entry = bid;
      const double stop_dist = MathMax(strategy_atr_sl_mult * atr_value, entry * strategy_sl_percent / 100.0);
      const double sl = NormalizeDouble(entry + stop_dist, _Digits);
      const double tp = NormalizeDouble(entry - stop_dist * strategy_rr_target, _Digits);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry || tp >= entry)
         return false;

      req.type = QM_SELL;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = sl;
      req.tp = tp;
      req.reason = "TV_SMART_PIVOT_SHORT_BREAKOUT";
      bars_since_short_entry = 0;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing, BE, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card exits via fixed 2R TP, stop loss, and framework Friday close only.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   (void)broker_time;
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
