#property strict
#property version   "5.0"
#property description "QM5_11106 ma-exc-fade — EarnForex MA Max Excursion Fade (mean-reversion, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11106 ma-exc-fade
// -----------------------------------------------------------------------------
// Source: EarnForex "MA-MaxExcursion" indicator (GitHub MQL4/MQL5 source).
// Card: artifacts/cards_approved/QM5_11106_ma-exc-fade.md (g0_status APPROVED).
//
// Concept (mean-reversion fade of an over-extended move back to its MA):
//   The indicator tracks the maximum excursion (max deviation of price from a
//   simple MA) over each segment BETWEEN two consecutive price/MA crosses.
//   We fade the cross-BACK when the just-completed excursion was large relative
//   to recent same-direction excursions.
//
// Mechanics (all reads on completed H1 bars at shift >= 1):
//   MA           : SMA(ma_period) on close (source default 20).
//   Segment      : run of bars on one side of the MA between two crosses. The
//                  excursion of a DOWN segment = max(MA - low_proxy) over the
//                  segment (how far price stretched below the MA); UP segment =
//                  max(high_proxy - MA). We use close as the price proxy
//                  (gapless .DWX CFDs: open[0]==close[1], so close-based
//                  excursion is well defined and non-repainting on closed bars).
//   Trigger EVENT: the LAST completed bar (shift 1) closed on the opposite side
//                  of the MA from the segment that preceded it — i.e. a fresh
//                  cross-back through the MA on bar shift 1. ONE event per bar.
//   Qualify STATE: that just-completed excursion segment was a stretch whose
//                  magnitude is (a) >= the median of the last stats_count
//                  same-direction excursions, and (b) >= exc_atr_mult * ATR
//                  (whipsaw filter). Both are STATES observed about the segment,
//                  not second cross EVENTS.
//   Long fade    : prior segment was a DOWN excursion that qualifies AND the
//                  cross-back is upward (close1 > MA1, close2 <= MA2).
//   Short fade   : prior segment was an UP excursion that qualifies AND the
//                  cross-back is downward (close1 < MA1, close2 >= MA2).
//   Stop         : 1.8 * ATR(atr_period) hard stop from entry (card P2 baseline).
//   Exit         : opposite MA cross (long closes on cross below MA; short on
//                  cross above MA), OR a time stop after time_stop_bars H1 bars.
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// All segment reconstruction runs ONCE per new closed bar inside
// Strategy_EntrySignal (the OnTick entry path is QM_IsNewBar-gated). The
// lookback is bounded by scan_max_bars so per-bar work stays O(scan_max_bars).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11106;
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
input int    strategy_ma_period         = 20;    // SMA period (source default)
input int    strategy_stats_count       = 20;    // # recent same-side excursions for the median
input int    strategy_atr_period        = 14;    // ATR period (excursion filter + stop)
input double strategy_exc_atr_mult      = 0.8;   // min excursion size = mult * ATR (whipsaw filter)
input double strategy_sl_atr_mult       = 1.8;   // stop distance = mult * ATR
input int    strategy_time_stop_bars    = 24;    // safety time stop in H1 bars
input int    strategy_scan_max_bars     = 400;   // bounded history scan for segment reconstruction
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope: entry-bar timestamp for the time stop (advanced only on entry).
// Not a new-bar gate — purely records when the current position was opened so
// Strategy_ExitSignal can enforce the H1-bar time stop. iTime read is single-shift.
// -----------------------------------------------------------------------------
datetime g_entry_bar_time = 0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — segment work is on the
// closed-bar entry path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Reconstruct excursion segments walking back from the trigger bar (shift 1).
// Fills the magnitudes of up to `want` most-recent COMPLETED same-direction
// excursions whose side matches `want_down` (true=down segments, false=up).
// Returns the count filled. `seg_just_completed` receives the magnitude of the
// segment that ended exactly at the cross-back on bar shift 1 (the one we fade),
// or 0.0 if the bar at shift 1 is not a fresh cross-back of the wanted side.
//
// All reads at shift >= 1 (completed bars). Bounded by strategy_scan_max_bars.
int CollectExcursions(const bool want_down,
                      double &recent[],
                      const int want,
                      double &seg_just_completed)
  {
   seg_just_completed = 0.0;
   int filled = 0;

   // Determine the side of each bar relative to its own MA, then group runs.
   // shift 1 is the trigger bar (most recent completed). Walk back to oldest.
   // A "segment" is a maximal run of bars strictly on one side of the MA.
   // Excursion magnitude of a DOWN run = max(MA[s] - close[s]); UP run =
   // max(close[s] - MA[s]). We only count segments that have actually CLOSED
   // (i.e. the next-more-recent bar flipped to the other side).

   const int max_shift = strategy_scan_max_bars;

   // State while scanning from recent (shift 1) to old (shift max_shift):
   //   cur_side: +1 above MA, -1 below MA, 0 = uninitialised
   //   cur_max : running excursion magnitude of the current (incomplete-as-seen) run
   int    cur_side = 0;
   double cur_max  = 0.0;
   bool   first_run = true; // the run containing shift 1 is the "just-completed" candidate

   for(int s = 1; s <= max_shift; ++s)
     {
      const double ma_s    = QM_SMA(_Symbol, _Period, strategy_ma_period, s);
      const double close_s = iClose(_Symbol, _Period, s); // perf-allowed: bespoke segment reconstruction
      if(ma_s <= 0.0 || close_s <= 0.0)
         break; // ran out of history

      const int side_s = (close_s > ma_s) ? +1 : ((close_s < ma_s) ? -1 : 0);
      if(side_s == 0)
         continue; // exactly on MA: ignore, treat as boundary-neutral

      const double exc_s = (side_s > 0) ? (close_s - ma_s) : (ma_s - close_s);

      if(cur_side == 0)
        {
         cur_side = side_s;
         cur_max  = exc_s;
         continue;
        }

      if(side_s == cur_side)
        {
         if(exc_s > cur_max)
            cur_max = exc_s;
         continue;
        }

      // side flipped → the run we were accumulating (more-recent side cur_side)
      // is now a COMPLETED segment. Older bar s belongs to the next segment.
      if(first_run)
        {
         // The most-recent completed run is the segment we just faded. It is on
         // side cur_side; we fade it only if it matches the wanted excursion
         // direction (down segment → long fade).
         const bool run_is_down = (cur_side < 0);
         if(run_is_down == want_down)
            seg_just_completed = cur_max;
         first_run = false;
        }

      // Record this completed run's magnitude if it matches the wanted side.
      const bool completed_is_down = (cur_side < 0);
      if(completed_is_down == want_down && filled < want)
         recent[filled++] = cur_max;

      // Start the new run with bar s.
      cur_side = side_s;
      cur_max  = exc_s;

      if(filled >= want && !first_run)
         break;
     }

   return filled;
  }

// Median of the first `n` entries of arr (n>0). Sorts a local copy.
double MedianOf(const double &arr[], const int n)
  {
   if(n <= 0)
      return 0.0;
   double tmp[];
   ArrayResize(tmp, n);
   for(int i = 0; i < n; ++i)
      tmp[i] = arr[i];
   // simple insertion sort (n is small, <= stats_count)
   for(int i = 1; i < n; ++i)
     {
      const double key = tmp[i];
      int j = i - 1;
      while(j >= 0 && tmp[j] > key)
        {
         tmp[j + 1] = tmp[j];
         --j;
        }
      tmp[j + 1] = key;
     }
   if((n % 2) == 1)
      return tmp[n / 2];
   return 0.5 * (tmp[n / 2 - 1] + tmp[n / 2]);
  }

// Mean-reversion fade entry on the closed-bar path (QM_IsNewBar guaranteed).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Trigger EVENT: a fresh cross-back through the MA on bar shift 1.
   const double ma1 = QM_SMA(_Symbol, _Period, strategy_ma_period, 1);
   const double ma2 = QM_SMA(_Symbol, _Period, strategy_ma_period, 2);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: cross detection
   const double close2 = iClose(_Symbol, _Period, 2);
   if(ma1 <= 0.0 || ma2 <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   const bool crossed_up   = (close2 <= ma2 && close1 > ma1);  // was below, now above → fade DOWN excursion → LONG
   const bool crossed_down = (close2 >= ma2 && close1 < ma1);  // was above, now below → fade UP excursion → SHORT
   if(!crossed_up && !crossed_down)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const bool want_down = crossed_up; // long fades a down excursion segment

   double recent[];
   ArrayResize(recent, strategy_stats_count);
   double seg_just_completed = 0.0;
   const int n = CollectExcursions(want_down, recent, strategy_stats_count, seg_just_completed);

   // Need the just-completed segment to be the wanted side and to exist.
   if(seg_just_completed <= 0.0)
      return false;

   // Whipsaw filter: excursion must be at least exc_atr_mult * ATR.
   if(seg_just_completed < strategy_exc_atr_mult * atr_value)
      return false;

   // Qualify STATE: segment >= median of recent same-direction excursions.
   // Require a minimal sample so the median is meaningful; if too few priors,
   // fall back to the ATR whipsaw filter alone (already passed above).
   if(n >= 3)
     {
      const double med = MedianOf(recent, n);
      if(med > 0.0 && seg_just_completed < med)
         return false;
     }

   // Build the fade entry. Framework sizes lots (no lots field).
   const double entry = SymbolInfoDouble(_Symbol, crossed_up ? SYMBOL_ASK : SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const QM_OrderType side = crossed_up ? QM_BUY : QM_SELL;
   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP — exit on opposite cross or time stop
   req.reason = crossed_up ? "ma_exc_fade_long" : "ma_exc_fade_short";

   // Record the entry bar for the time stop (bar shift 0 = current forming bar).
   g_entry_bar_time = iTime(_Symbol, _Period, 0); // single-shift read
   return true;
  }

// No active trade management beyond the fixed ATR stop. Opposite-cross and
// time-stop exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: opposite MA cross OR time stop after time_stop_bars H1 bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine current open position direction for this magic.
   bool   is_long  = false;
   bool   have_pos = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      is_long  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      have_pos = true;
      break;
     }
   if(!have_pos)
      return false;

   // Time stop: count H1 bars elapsed since the entry bar.
   if(g_entry_bar_time > 0)
     {
      const datetime bar0 = iTime(_Symbol, _Period, 0); // single-shift read
      const int period_secs = PeriodSeconds(_Period);
      if(period_secs > 0)
        {
         const int bars_held = (int)((bar0 - g_entry_bar_time) / period_secs);
         if(bars_held >= strategy_time_stop_bars)
            return true;
        }
     }

   // Opposite MA cross on the last completed bar (shift 1).
   const double ma1 = QM_SMA(_Symbol, _Period, strategy_ma_period, 1);
   const double ma2 = QM_SMA(_Symbol, _Period, strategy_ma_period, 2);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(ma1 <= 0.0 || ma2 <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   if(is_long)
     {
      // long closes on a cross BELOW the MA
      if(close2 >= ma2 && close1 < ma1)
         return true;
     }
   else
     {
      // short closes on a cross ABOVE the MA
      if(close2 <= ma2 && close1 > ma1)
         return true;
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
