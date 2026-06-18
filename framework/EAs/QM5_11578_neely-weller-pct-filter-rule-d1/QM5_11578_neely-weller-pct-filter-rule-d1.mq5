#property strict
#property version   "5.0"
#property description "QM5_11578 neely-weller-pct-filter-rule-d1 — Neely & Weller percent filter (stop-and-reverse, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11578 neely-weller-pct-filter-rule-d1
// -----------------------------------------------------------------------------
// Source: Neely & Weller (2013), "Lessons from the Evolution of Foreign Exchange
//         Trading Strategies" (source_id 577eb0aa-7880-5c0a-a8f9-56cd126c19f9).
// Card: artifacts/cards_approved/QM5_11578_neely-weller-pct-filter-rule-d1.md
//       (g0_status APPROVED).
//
// Mechanics (stop-and-reverse, always-in-market, closed-bar reads at shift 1):
//   The "percent filter" rule. Track a running reference extreme:
//     trough = lowest close since the last SHORT signal
//     peak   = highest close since the last LONG  signal
//   Trigger EVENT (the ONE trigger per direction):
//     LONG  when close0 >= trough * (1 + filter_pct)   (price rose X% off a low)
//     SHORT when close0 <= peak   * (1 - filter_pct)   (price fell X% off a high)
//   After a LONG  signal: reset peak tracker to close0, restart trough tracking.
//   After a SHORT signal: reset trough tracker to close0, restart peak tracking.
//   Each direction has a SINGLE distinct trigger comparing the closed-bar close
//   to its own tracked extreme — so the long and short triggers can never fire
//   on the same bar (the "two-cross-same-bar" zero-trade trap is avoided by
//   construction).
//
//   Stop-and-reverse: a fresh opposite signal closes the current position and
//   opens the new direction. A safety SL (2*ATR, capped at 150 pips) is a hard
//   backstop only.
//
// State is maintained per-EA and advanced exactly ONCE per closed bar, gated by
// the framework new-bar event in OnTick. Closed-bar close reads (iClose shift 1)
// are bounded single reads (perf-allowed) — no per-tick history scans.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11578;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_filter_pct        = 0.01;   // filter size (0.01 = 1% move off the extreme)
input int    strategy_atr_period        = 14;     // ATR period for the safety stop
input double strategy_sl_atr_mult       = 2.0;    // safety stop distance = mult * ATR
input double strategy_sl_cap_pips       = 150.0;  // hard cap on the safety stop, in pips

// -----------------------------------------------------------------------------
// File-scope strategy state — advanced once per closed bar in Strategy_AdvanceState.
//   g_peak   : highest close observed since the last LONG  signal (short trigger ref)
//   g_trough : lowest  close observed since the last SHORT signal (long  trigger ref)
//   g_signal : last fired signal direction (+1 long, -1 short, 0 none) — for state resets
//   g_pending: the direction the new-bar evaluation wants to act on this bar (+1/-1/0)
// -----------------------------------------------------------------------------
double g_peak    = 0.0;
double g_trough  = 0.0;
int    g_signal  = 0;
int    g_pending = 0;

// Advance the percent-filter state by ONE closed bar. Called once per new bar
// (after QM_IsNewBar() passes) and BEFORE the per-tick entry/exit hooks read
// g_pending. Reads only the last closed bar's close (single bounded read).
void Strategy_AdvanceState_OnNewBar()
  {
   g_pending = 0;

   const double close0 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close0 <= 0.0)
      return;

   // Seed the trackers on the very first valid closed bar.
   if(g_peak <= 0.0)
      g_peak = close0;
   if(g_trough <= 0.0)
      g_trough = close0;

   // Update the running extremes with this bar's close.
   if(close0 > g_peak)
      g_peak = close0;
   if(close0 < g_trough)
      g_trough = close0;

   const double up_trigger   = g_trough * (1.0 + strategy_filter_pct);
   const double down_trigger = g_peak   * (1.0 - strategy_filter_pct);

   // LONG: price has risen filter_pct above the tracked trough.
   if(g_trough > 0.0 && close0 >= up_trigger && g_signal != 1)
     {
      g_pending = 1;
      g_signal  = 1;
      // Restart peak tracking from here; keep trough as the new reference floor.
      g_peak    = close0;
      g_trough  = close0;
      return;
     }

   // SHORT: price has fallen filter_pct below the tracked peak.
   if(g_peak > 0.0 && close0 <= down_trigger && g_signal != -1)
     {
      g_pending = -1;
      g_signal  = -1;
      // Restart trough tracking from here; keep peak as the new reference ceiling.
      g_trough  = close0;
      g_peak    = close0;
      return;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread/session filter for a D1 stop-and-reverse
// system; quote validity only (never block on .DWX zero modeled spread).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true; // no valid quote yet — block this tick
   return false;
  }

// Stop-and-reverse entry. Caller guarantees QM_IsNewBar() == true and that
// Strategy_AdvanceState_OnNewBar() has already set g_pending for this bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_pending == 0)
      return false;

   // One position per magic: if a same-direction position is already open, do
   // nothing. An opposite-direction position is closed by Strategy_ExitSignal
   // (the stop-and-reverse close) before this entry fires.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(g_pending == 1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Safety SL = entry - sl_atr_mult*ATR, never wider than the pip cap.
      double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
      if(cap_dist > 0.0 && (entry - sl) > cap_dist)
         sl = entry - cap_dist;
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = 0.0;   // no fixed TP — exit is the opposite signal
      req.reason = "pct_filter_long";
      return true;
     }

   if(g_pending == -1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
      if(cap_dist > 0.0 && (sl - entry) > cap_dist)
         sl = entry + cap_dist;
      if(sl <= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = 0.0;
      req.reason = "pct_filter_short";
      return true;
     }

   return false;
  }

// No active management beyond the safety SL — exits are signal-driven.
void Strategy_ManageOpenPosition()
  {
  }

// Stop-and-reverse close: if a fresh opposite signal is pending this bar and an
// open position runs the WRONG way, close it so the entry hook can reverse.
bool Strategy_ExitSignal()
  {
   if(g_pending == 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Inspect the open position's direction; close only if it opposes g_pending.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(g_pending == 1 && ptype == POSITION_TYPE_SELL)
         return true;  // pending long, holding short -> reverse
      if(g_pending == -1 && ptype == POSITION_TYPE_BUY)
         return true;  // pending short, holding long -> reverse
     }
   return false;
  }

// Defer to the central news filter.
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

   g_peak    = 0.0;
   g_trough  = 0.0;
   g_signal  = 0;
   g_pending = 0;

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

   // FIRST: advance the percent-filter state once per closed bar. This sets
   // g_pending, which both the exit (reverse) and entry hooks below consume.
   if(QM_IsNewBar())
     {
      Strategy_AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
     }

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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }

   // g_pending is consumed within this tick; clear it so a later tick on the
   // same bar does not re-fire the entry after a reverse-close settles.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      g_pending = 0;
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
