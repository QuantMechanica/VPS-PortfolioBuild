#property strict
#property version   "5.0"
#property description "QM5_9268 MQL5 Fractal Failure Swing"

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
input int    qm_ea_id                   = 9268;
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
input int    strategy_atr_period         = 14;
input double strategy_stop_atr_mult      = 0.4;
input double strategy_take_rr            = 2.3;
input double strategy_sweep_min_atr_mult = 0.05;
input int    strategy_max_hold_bars      = 18;

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

   if(strategy_atr_period <= 0 || strategy_stop_atr_mult <= 0.0 ||
      strategy_take_rr <= 0.0 || strategy_sweep_min_atr_mult < 0.0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double min_sweep = atr * strategy_sweep_min_atr_mult;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double f_high = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 3); // perf-allowed: fixed closed-bar Bill Williams fractal check after framework new-bar gate.
   const double f_low = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 3); // perf-allowed: fixed closed-bar Bill Williams fractal check after framework new-bar gate.
   const double h5 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 5); // perf-allowed: fixed closed-bar Bill Williams fractal check after framework new-bar gate.
   const double h4 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 4); // perf-allowed: fixed closed-bar Bill Williams fractal check after framework new-bar gate.
   const double h2 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 2); // perf-allowed: fixed closed-bar Bill Williams fractal check after framework new-bar gate.
   const double h1 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: fixed closed-bar Bill Williams fractal check after framework new-bar gate.
   const double l5 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 5); // perf-allowed: fixed closed-bar Bill Williams fractal check after framework new-bar gate.
   const double l4 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 4); // perf-allowed: fixed closed-bar Bill Williams fractal check after framework new-bar gate.
   const double l2 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 2); // perf-allowed: fixed closed-bar Bill Williams fractal check after framework new-bar gate.
   const double l1 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: fixed closed-bar Bill Williams fractal check after framework new-bar gate.
   const double c1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: fixed closed-bar failure-swing confirmation after framework new-bar gate.

   if(f_high <= 0.0 || f_low <= 0.0 || h5 <= 0.0 || h4 <= 0.0 || h2 <= 0.0 ||
      h1 <= 0.0 || l5 <= 0.0 || l4 <= 0.0 || l2 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
      return false;

   const bool bullish_fractal = (f_low < l5 && f_low < l4 && f_low < l2 && f_low < l1);
   const bool bearish_fractal = (f_high > h5 && f_high > h4 && f_high > h2 && f_high > h1);

   if(bullish_fractal && l2 <= f_low - min_sweep && c1 >= f_high)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, l2 - atr * strategy_stop_atr_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_take_rr);
      req.reason = StringFormat("FFS_L_%s", DoubleToString(f_low, _Digits));
      if(req.sl <= 0.0 || req.tp <= 0.0 || req.sl >= ask)
         return false;
      return true;
     }

   if(bearish_fractal && h2 >= f_high + min_sweep && c1 <= f_low)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, h2 + atr * strategy_stop_atr_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_take_rr);
      req.reason = StringFormat("FFS_S_%s", DoubleToString(f_high, _Digits));
      if(req.sl <= 0.0 || req.tp <= 0.0 || req.sl <= bid)
         return false;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double f_high = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 3); // perf-allowed: O(1) closed-bar exit fractal check.
   const double f_low = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 3); // perf-allowed: O(1) closed-bar exit fractal check.
   const double h5 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 5); // perf-allowed: O(1) closed-bar exit fractal check.
   const double h4 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 4); // perf-allowed: O(1) closed-bar exit fractal check.
   const double h2 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 2); // perf-allowed: O(1) closed-bar exit fractal check.
   const double h1 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: O(1) closed-bar exit fractal check.
   const double l5 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 5); // perf-allowed: O(1) closed-bar exit fractal check.
   const double l4 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 4); // perf-allowed: O(1) closed-bar exit fractal check.
   const double l2 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 2); // perf-allowed: O(1) closed-bar exit fractal check.
   const double l1 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: O(1) closed-bar exit fractal check.
   const double c1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: O(1) closed-bar exit confirmation.

   const bool bullish_fractal = (f_low > 0.0 && f_low < l5 && f_low < l4 && f_low < l2 && f_low < l1);
   const bool bearish_fractal = (f_high > 0.0 && f_high > h5 && f_high > h4 && f_high > h2 && f_high > h1);
   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(PERIOD_H4);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(hold_seconds > 0 && opened > 0 && TimeCurrent() - opened >= hold_seconds)
         return true;

      const string comment = PositionGetString(POSITION_COMMENT);
      if(ptype == POSITION_TYPE_BUY)
        {
         double swept_low = 0.0;
         if(StringFind(comment, "FFS_L_") == 0)
            swept_low = StringToDouble(StringSubstr(comment, 6));
         if(swept_low > 0.0 && c1 > 0.0 && c1 < swept_low)
            return true;
         if(bearish_fractal && c1 > 0.0 && c1 < f_low)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         double swept_high = 0.0;
         if(StringFind(comment, "FFS_S_") == 0)
            swept_high = StringToDouble(StringSubstr(comment, 6));
         if(swept_high > 0.0 && c1 > 0.0 && c1 > swept_high)
            return true;
         if(bullish_fractal && c1 > 0.0 && c1 > f_high)
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
