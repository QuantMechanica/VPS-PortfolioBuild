#property strict
#property version   "5.0"
#property description "QM5_10419 Elite Trader SPM Tuned MACD"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10419 — Elite Trader SPM Tuned MACD (5/13/6 on M5)
// -----------------------------------------------------------------------------
// Card: QM5_10419_et-spm-macd  (g0_status: APPROVED)
// Source: jack hershey / frostengine, SPM Boot Camp p9, Elite Trader 2008-10-21
//
// Mechanic (baseline M5, MACD 5/13/6):
//   Long  : MACD line > 0 AND signal line > 0 (zero-line STATES) AND MACD line
//           crosses ABOVE signal line on the last completed bar (trigger EVENT).
//   Short : MACD line < 0 AND signal line < 0 (zero-line STATES) AND MACD line
//           crosses BELOW signal line on the last completed bar (trigger EVENT).
//           Entry at next bar open (req.price = 0 -> framework market fill).
//   Exit  : opposite MACD/signal cross, OR histogram crosses through zero,
//           OR strategy_max_hold_bars (24) closed M5 bars elapsed (time stop).
//   Stop  : strategy_atr_stop_mult (1.5) * ATR(20) from entry. Reject if stop
//           distance < 4x spread, but only when a GENUINE positive spread is
//           modeled (.DWX quotes zero spread in the tester).
//   Filter: liquid index/metal session window; one position per symbol/magic
//           (framework enforces single-entry; entry simply re-arms on next bar).
//
// Only the five Strategy_* hooks are filled; all framework wiring below the
// hooks is kept verbatim from EA_Skeleton.mq5. Uses ONLY pooled QM_* readers
// (no raw iMACD/iATR, no per-EA IsNewBar). qm_ea_id = 10419.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10419;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M5;
input int             strategy_macd_fast          = 5;
input int             strategy_macd_slow          = 13;
input int             strategy_macd_signal        = 6;
input int             strategy_atr_period         = 20;
input double          strategy_atr_stop_mult      = 1.5;
input int             strategy_max_hold_bars      = 24;
input bool            strategy_session_filter_on  = true;
input int             strategy_session_start_hhmm = 800;
input int             strategy_session_end_hhmm   = 2200;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != strategy_signal_tf)
      return true;

   if(!strategy_session_filter_on)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int now_hhmm = dt.hour * 100 + dt.min;
   if(strategy_session_start_hhmm <= strategy_session_end_hhmm)
      return !(now_hhmm >= strategy_session_start_hhmm && now_hhmm < strategy_session_end_hhmm);

   return !(now_hhmm >= strategy_session_start_hhmm || now_hhmm < strategy_session_end_hhmm);
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

   if((ENUM_TIMEFRAMES)_Period != strategy_signal_tf)
      return false;
   if(strategy_macd_fast <= 0 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 || strategy_atr_period <= 0 ||
      strategy_atr_stop_mult <= 0.0)
      return false;

   const double macd1 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_macd_fast,
                                    strategy_macd_slow, strategy_macd_signal, 1);
   const double sig1 = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 1);
   const double macd2 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_macd_fast,
                                    strategy_macd_slow, strategy_macd_signal, 2);
   const double sig2 = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 2);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const double spread = ask - bid;
   const double stop_distance = strategy_atr_stop_mult * atr;
   if(stop_distance <= 0.0)
      return false;
   // Reject only when a GENUINE (positive) spread is modeled and the stop is
   // tighter than 4x it. .DWX quotes zero spread in the tester (ask==bid),
   // which must NOT block trading (DWX backtest invariant #1).
   if(spread > 0.0 && stop_distance < 4.0 * spread)
      return false;

   if(macd1 > 0.0 && sig1 > 0.0 && macd2 <= sig2 && macd1 > sig1)
     {
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, ask, atr, strategy_atr_stop_mult);
      req.reason = "QM5_10419_MACD_LONG";
      return (req.sl > 0.0);
     }

   if(macd1 < 0.0 && sig1 < 0.0 && macd2 >= sig2 && macd1 < sig1)
     {
      req.type = QM_SELL;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, bid, atr, strategy_atr_stop_mult);
      req.reason = "QM5_10419_MACD_SHORT";
      return (req.sl > 0.0);
     }

   return false;
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
   if((ENUM_TIMEFRAMES)_Period != strategy_signal_tf)
      return false;
   if(strategy_macd_fast <= 0 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 || strategy_max_hold_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   bool have_position = false;
   bool is_buy = false;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      have_position = true;
      is_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(!have_position)
      return false;

   const int hold_seconds = PeriodSeconds(strategy_signal_tf) * strategy_max_hold_bars;
   if(hold_seconds > 0 && TimeCurrent() - open_time >= hold_seconds)
      return true;

   const double macd1 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_macd_fast,
                                    strategy_macd_slow, strategy_macd_signal, 1);
   const double sig1 = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 1);
   const double macd2 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_macd_fast,
                                    strategy_macd_slow, strategy_macd_signal, 2);
   const double sig2 = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 2);
   const double hist1 = macd1 - sig1;
   const double hist2 = macd2 - sig2;

   if(is_buy)
      return ((macd2 >= sig2 && macd1 < sig1) || (hist2 >= 0.0 && hist1 < 0.0));

   return ((macd2 <= sig2 && macd1 > sig1) || (hist2 <= 0.0 && hist1 > 0.0));
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
