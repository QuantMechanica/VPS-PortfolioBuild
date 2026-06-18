#property strict
#property version   "5.0"
#property description "QM5_11371 tom-demark-ema9-30-momentum-h1 — EMA(9/30) cross + Momentum(14) + DeMark trend-line break (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11371 tom-demark-ema9-30-momentum-h1
// -----------------------------------------------------------------------------
// Source: "9 Forex Systems" (DayTradeForex.com compilation) — Tom DeMark FX
//   System chapter. Card: artifacts/cards_approved/
//   QM5_11371_tom-demark-ema9-30-momentum-h1.md (g0_status APPROVED).
//
// Mechanics (all reads on CLOSED bars, shift >= 1):
//   TRIGGER EVENT (one event/bar): EMA(9) crosses EMA(30).
//       LONG  : EMA9 was <= EMA30 at shift 2 AND > EMA30 at shift 1.
//       SHORT : EMA9 was >= EMA30 at shift 2 AND < EMA30 at shift 1.
//   STATE 1 (momentum): Momentum(14) at shift 1.  > 100 confirms LONG,
//                       < 100 confirms SHORT (100 = zero-change baseline).
//   STATE 2 (DeMark trend-line break): a downtrend line is drawn through the
//       last >=3 TD High Points (local maxima with strictly lower flanking
//       highs) that have monotonically DECREASING highs; LONG requires the
//       last closed bar to CLOSE ABOVE that projected line. Mirror for SHORT
//       with TD Low Points (increasing lows) — close BELOW the projected
//       uptrend line. Computed once per closed bar over a bounded scan window.
//
//   Avoiding the two-cross-same-bar zero-trade trap: the EMA cross is the
//   SOLE event. Momentum and the trend-line break are STATES sampled on the
//   same closed bar (they need not cross on the trigger bar).
//
//   Stop          : fixed `strategy_sl_pips` pips from entry (card: 40 pips).
//   Take profit   : RR multiple of the stop (card: trail to capture move; we
//                   use a bounded TP at `strategy_tp_rr` x stop so the EA
//                   produces complete round-trips, plus a step-trail below).
//   Trade mgmt    : step-trail in `strategy_trail_step_pips` pips once price
//                   has moved `strategy_trail_trigger_pips` in profit.
//   Spread guard  : fail-OPEN on .DWX zero modeled spread; block only a
//                   genuinely wide spread > strategy_max_spread_pips.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11371;
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
input int    strategy_ema_fast_period   = 9;      // fast EMA (cross signal)
input int    strategy_ema_slow_period   = 30;     // slow EMA (cross signal)
input int    strategy_mom_period        = 14;     // Momentum period; baseline 100
input double strategy_mom_baseline      = 100.0;  // momentum neutral level
input int    strategy_td_min_points     = 3;      // min TD points to build a line
input int    strategy_td_scan_bars      = 60;     // bounded closed-bar scan window
input int    strategy_sl_pips           = 40;     // fixed initial stop (card: 40 pips)
input double strategy_tp_rr             = 2.5;    // take-profit = RR x stop distance
input int    strategy_trail_trigger_pips = 20;    // profit before trailing starts
input int    strategy_trail_step_pips    = 10;    // step-trail increment (card: 10 pips)
input int    strategy_max_spread_pips    = 20;    // skip only genuinely wide spread (card cap)

// -----------------------------------------------------------------------------
// Internal helpers — bounded, closed-bar-only DeMark trend-line construction.
// -----------------------------------------------------------------------------

// Returns the projected DOWNTREND-line value at bar `target_shift` built from
// the most recent `strategy_td_min_points`+ TD High Points (local maxima with
// strictly lower flanking highs) that have monotonically DECREASING highs.
// Returns 0.0 if no qualifying line exists. Scan is bounded by
// strategy_td_scan_bars; all reads are on closed bars (shift >= 1).
double DownTrendLineValue(const int target_shift)
  {
   // Collect TD High Points newest->oldest. A TD High Point at shift s needs
   // High[s] > High[s-1] AND High[s] > High[s+1] (strictly lower neighbours).
   int    pt_shift[64];
   double pt_high[64];
   int    n = 0;

   const int max_pts = (ArraySize(pt_shift) < 64) ? ArraySize(pt_shift) : 64;
   // start at shift 2 so both flanking bars (s-1 >= 1, s+1) are closed bars.
   for(int s = 2; s <= strategy_td_scan_bars && n < max_pts; ++s)
     {
      const double h   = iHigh(_Symbol, _Period, s);     // perf-allowed: bounded TD scan, new-bar gated
      const double hlo = iHigh(_Symbol, _Period, s - 1);
      const double hhi = iHigh(_Symbol, _Period, s + 1);
      if(h <= 0.0 || hlo <= 0.0 || hhi <= 0.0)
         continue;
      if(h > hlo && h > hhi)
        {
         pt_shift[n] = s;
         pt_high[n]  = h;
         n++;
        }
     }
   if(n < strategy_td_min_points)
      return 0.0;

   // Walk newest->oldest, keeping a run of points whose highs strictly DECREASE
   // as we go back in time (i.e. a valid descending resistance sequence). The
   // newest point is the anchor closest to the trigger bar.
   // pt arrays are ordered newest(index 0) -> oldest(index n-1).
   int run_first = 0;   // newest index in the run
   int run_last  = 0;   // oldest index in the run
   for(int i = 1; i < n; ++i)
     {
      // going further back, an earlier (older) TD high should be HIGHER for a
      // downtrend line (highs decrease over time as price falls). Older high
      // must exceed the next-newer high in the run.
      if(pt_high[i] > pt_high[run_last])
         run_last = i;
      else
         break;
     }
   if(run_last - run_first + 1 < strategy_td_min_points)
      return 0.0;

   // Build the line through the OLDEST (run_last) and NEWEST (run_first) points.
   const int    s_old = pt_shift[run_last];
   const double h_old = pt_high[run_last];
   const int    s_new = pt_shift[run_first];
   const double h_new = pt_high[run_first];
   const int    span  = s_old - s_new;     // > 0 since older shift is larger
   if(span <= 0)
      return 0.0;

   // slope per bar (price change per 1-bar step toward the present).
   const double slope = (h_new - h_old) / (double)span; // <= 0 for a downtrend
   // project to target_shift: value = h_new + slope * (s_new - target_shift).
   const double value = h_new + slope * (double)(s_new - target_shift);
   return value;
  }

// Mirror: projected UPTREND-line value from TD Low Points (local minima with
// strictly higher flanking lows) whose lows monotonically INCREASE over time.
double UpTrendLineValue(const int target_shift)
  {
   int    pt_shift[64];
   double pt_low[64];
   int    n = 0;

   const int max_pts = (ArraySize(pt_shift) < 64) ? ArraySize(pt_shift) : 64;
   for(int s = 2; s <= strategy_td_scan_bars && n < max_pts; ++s)
     {
      const double l   = iLow(_Symbol, _Period, s);      // perf-allowed: bounded TD scan, new-bar gated
      const double llo = iLow(_Symbol, _Period, s - 1);
      const double lhi = iLow(_Symbol, _Period, s + 1);
      if(l <= 0.0 || llo <= 0.0 || lhi <= 0.0)
         continue;
      if(l < llo && l < lhi)
        {
         pt_shift[n] = s;
         pt_low[n]   = l;
         n++;
        }
     }
   if(n < strategy_td_min_points)
      return 0.0;

   int run_first = 0;
   int run_last  = 0;
   for(int i = 1; i < n; ++i)
     {
      // older TD low must be LOWER for a rising support line (lows increase
      // toward the present).
      if(pt_low[i] < pt_low[run_last])
         run_last = i;
      else
         break;
     }
   if(run_last - run_first + 1 < strategy_td_min_points)
      return 0.0;

   const int    s_old = pt_shift[run_last];
   const double l_old = pt_low[run_last];
   const int    s_new = pt_shift[run_first];
   const double l_new = pt_low[run_first];
   const int    span  = s_old - s_new;
   if(span <= 0)
      return 0.0;

   const double slope = (l_new - l_old) / (double)span; // >= 0 for an uptrend
   const double value = l_new + slope * (double)(s_new - target_shift);
   return value;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double cap    = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). The EMA
// cross is the sole EVENT; momentum + DeMark trend-line break are STATES.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA(9/30) values on the two most recent closed bars ---
   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const bool cross_up   = (fast_prev <= slow_prev && fast_now > slow_now);
   const bool cross_down = (fast_prev >= slow_prev && fast_now < slow_now);
   if(!cross_up && !cross_down)
      return false;

   // --- Momentum STATE on the closed bar ---
   const double mom = QM_Momentum(_Symbol, _Period, strategy_mom_period, 1);
   if(mom <= 0.0)
      return false;

   // --- Close of the last closed bar (for the trend-line break test) ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   if(cross_up)
     {
      // momentum confirms bullish
      if(!(mom > strategy_mom_baseline))
         return false;
      // DeMark downtrend-line break: close above the projected line at shift 1
      const double line = DownTrendLineValue(1);
      if(line <= 0.0)
         return false;            // no qualifying descending line -> no break
      if(!(close1 > line))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "td_ema930_mom_long";
      return true;
     }

   // cross_down -> SHORT
   if(!(mom < strategy_mom_baseline))
      return false;
   const double uline = UpTrendLineValue(1);
   if(uline <= 0.0)
      return false;
   if(!(close1 < uline))
      return false;

   const double sentry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(sentry <= 0.0)
      return false;
   const double ssl = QM_StopFixedPips(_Symbol, QM_SELL, sentry, strategy_sl_pips);
   if(ssl <= 0.0)
      return false;
   const double stp = QM_TakeRR(_Symbol, QM_SELL, sentry, ssl, strategy_tp_rr);
   if(stp <= 0.0)
      return false;

   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = ssl;
   req.tp     = stp;
   req.reason = "td_ema930_mom_short";
   return true;
  }

// Step-trail the open position once it is in profit (card: 10-pip steps).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_TrailStep(ticket, strategy_trail_trigger_pips, strategy_trail_step_pips);
     }
  }

// No discretionary exit beyond SL/TP/trail.
bool Strategy_ExitSignal()
  {
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
