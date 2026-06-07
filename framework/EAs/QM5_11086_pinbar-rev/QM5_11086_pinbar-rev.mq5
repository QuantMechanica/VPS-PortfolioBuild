#property strict
#property version   "5.0"
#property description "QM5_11086 EarnForex Pinbar Reversal"

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
input int    qm_ea_id                   = 11086;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input int    strategy_atr_period              = 14;
input double strategy_max_nose_body_size      = 0.33;
input double strategy_nose_body_position      = 0.40;
input bool   strategy_left_eye_opposite       = true;
input double strategy_left_eye_min_body_size  = 0.10;
input double strategy_nose_protruding         = 0.50;
input double strategy_nose_body_to_left_eye   = 1.00;
input double strategy_min_range_atr           = 0.40;
input double strategy_max_range_atr           = 3.00;
input double strategy_stop_atr_buffer         = 0.20;
input double strategy_catastrophic_atr_mult   = 2.00;
input int    strategy_time_stop_bars          = 12;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card adds no session or regime filter; spread/news/fuse gates are framework-owned.
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

   if(strategy_atr_period <= 0 || strategy_time_stop_bars <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double nose_open = iOpen(_Symbol, tf, 1);    // perf-allowed: fixed two-bar pinbar geometry, called only after framework QM_IsNewBar gate.
   const double nose_high = iHigh(_Symbol, tf, 1);    // perf-allowed: fixed two-bar pinbar geometry, called only after framework QM_IsNewBar gate.
   const double nose_low = iLow(_Symbol, tf, 1);      // perf-allowed: fixed two-bar pinbar geometry, called only after framework QM_IsNewBar gate.
   const double nose_close = iClose(_Symbol, tf, 1);  // perf-allowed: fixed two-bar pinbar geometry, called only after framework QM_IsNewBar gate.
   const double eye_open = iOpen(_Symbol, tf, 2);     // perf-allowed: fixed two-bar pinbar geometry, called only after framework QM_IsNewBar gate.
   const double eye_high = iHigh(_Symbol, tf, 2);     // perf-allowed: fixed two-bar pinbar geometry, called only after framework QM_IsNewBar gate.
   const double eye_low = iLow(_Symbol, tf, 2);       // perf-allowed: fixed two-bar pinbar geometry, called only after framework QM_IsNewBar gate.
   const double eye_close = iClose(_Symbol, tf, 2);   // perf-allowed: fixed two-bar pinbar geometry, called only after framework QM_IsNewBar gate.

   if(nose_open <= 0.0 || nose_high <= 0.0 || nose_low <= 0.0 || nose_close <= 0.0 ||
      eye_open <= 0.0 || eye_high <= 0.0 || eye_low <= 0.0 || eye_close <= 0.0)
      return false;

   const double nose_range = nose_high - nose_low;
   const double eye_range = eye_high - eye_low;
   if(nose_range <= 0.0 || eye_range <= 0.0)
      return false;
   if(nose_range < strategy_min_range_atr * atr || nose_range > strategy_max_range_atr * atr)
      return false;

   const double nose_body = MathAbs(nose_close - nose_open);
   const double eye_body = MathAbs(eye_close - eye_open);
   if(nose_body > strategy_max_nose_body_size * nose_range)
      return false;
   if(eye_body < strategy_left_eye_min_body_size * eye_range)
      return false;
   if(nose_body > strategy_nose_body_to_left_eye * eye_body)
      return false;

   const double nose_body_low = MathMin(nose_open, nose_close);
   const double nose_body_high = MathMax(nose_open, nose_close);
   const bool eye_bearish = (eye_close < eye_open);
   const bool eye_bullish = (eye_close > eye_open);
   const bool bullish_pinbar =
      (!strategy_left_eye_opposite || eye_bearish) &&
      (nose_body_low >= nose_high - strategy_nose_body_position * nose_range) &&
      ((eye_low - nose_low) >= strategy_nose_protruding * nose_range);
   const bool bearish_pinbar =
      (!strategy_left_eye_opposite || eye_bullish) &&
      (nose_body_high <= nose_low + strategy_nose_body_position * nose_range) &&
      ((nose_high - eye_high) >= strategy_nose_protruding * nose_range);

   if(!bullish_pinbar && !bearish_pinbar)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop_distance = stops_level * point;

   if(bullish_pinbar)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = nose_low - strategy_stop_atr_buffer * atr;
      if(entry <= 0.0 || sl <= 0.0)
         return false;
      if(min_stop_distance > 0.0 && (entry - sl) < min_stop_distance)
         sl = entry - strategy_catastrophic_atr_mult * atr;
      if(sl <= 0.0 || sl >= entry)
         return false;
      req.type = QM_BUY;
      req.sl = NormalizeDouble(sl, _Digits);
      req.reason = "PINBAR_REV_LONG";
      return true;
     }

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = nose_high + strategy_stop_atr_buffer * atr;
   if(entry <= 0.0 || sl <= 0.0)
      return false;
   if(min_stop_distance > 0.0 && (sl - entry) < min_stop_distance)
      sl = entry + strategy_catastrophic_atr_mult * atr;
   if(sl <= entry)
      return false;
   req.type = QM_SELL;
   req.sl = NormalizeDouble(sl, _Digits);
   req.reason = "PINBAR_REV_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (TimeCurrent() - opened) >= strategy_time_stop_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period))
         return true;

      const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
      const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
      if(atr <= 0.0)
         continue;

      const double nose_open = iOpen(_Symbol, tf, 1);    // perf-allowed: fixed two-bar opposite-pinbar exit check; O(1), no loops.
      const double nose_high = iHigh(_Symbol, tf, 1);    // perf-allowed: fixed two-bar opposite-pinbar exit check; O(1), no loops.
      const double nose_low = iLow(_Symbol, tf, 1);      // perf-allowed: fixed two-bar opposite-pinbar exit check; O(1), no loops.
      const double nose_close = iClose(_Symbol, tf, 1);  // perf-allowed: fixed two-bar opposite-pinbar exit check; O(1), no loops.
      const double eye_open = iOpen(_Symbol, tf, 2);     // perf-allowed: fixed two-bar opposite-pinbar exit check; O(1), no loops.
      const double eye_high = iHigh(_Symbol, tf, 2);     // perf-allowed: fixed two-bar opposite-pinbar exit check; O(1), no loops.
      const double eye_low = iLow(_Symbol, tf, 2);       // perf-allowed: fixed two-bar opposite-pinbar exit check; O(1), no loops.
      const double eye_close = iClose(_Symbol, tf, 2);   // perf-allowed: fixed two-bar opposite-pinbar exit check; O(1), no loops.
      if(nose_open <= 0.0 || nose_high <= 0.0 || nose_low <= 0.0 || nose_close <= 0.0 ||
         eye_open <= 0.0 || eye_high <= 0.0 || eye_low <= 0.0 || eye_close <= 0.0)
         continue;

      const double nose_range = nose_high - nose_low;
      const double eye_range = eye_high - eye_low;
      if(nose_range <= 0.0 || eye_range <= 0.0)
         continue;
      if(nose_range < strategy_min_range_atr * atr || nose_range > strategy_max_range_atr * atr)
         continue;

      const double nose_body = MathAbs(nose_close - nose_open);
      const double eye_body = MathAbs(eye_close - eye_open);
      if(nose_body > strategy_max_nose_body_size * nose_range ||
         eye_body < strategy_left_eye_min_body_size * eye_range ||
         nose_body > strategy_nose_body_to_left_eye * eye_body)
         continue;

      const double nose_body_low = MathMin(nose_open, nose_close);
      const double nose_body_high = MathMax(nose_open, nose_close);
      const bool eye_bearish = (eye_close < eye_open);
      const bool eye_bullish = (eye_close > eye_open);
      const bool bullish_pinbar =
         (!strategy_left_eye_opposite || eye_bearish) &&
         (nose_body_low >= nose_high - strategy_nose_body_position * nose_range) &&
         ((eye_low - nose_low) >= strategy_nose_protruding * nose_range);
      const bool bearish_pinbar =
         (!strategy_left_eye_opposite || eye_bullish) &&
         (nose_body_high <= nose_low + strategy_nose_body_position * nose_range) &&
         ((nose_high - eye_high) >= strategy_nose_protruding * nose_range);

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && bearish_pinbar)
         return true;
      if(ptype == POSITION_TYPE_SELL && bullish_pinbar)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time < 0)
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
