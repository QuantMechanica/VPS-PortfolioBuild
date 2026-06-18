#property strict
#property version   "5.0"
#property description "QM5_11452 big-ben-fade-asian-range-m5 — Big Ben fade of the Asian-range false breakout (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11452 big-ben-fade-asian-range-m5
// -----------------------------------------------------------------------------
// Source: "Big Ben Strategy" (online community, anonymous; local PDF
//   450251566-Big-Ben-Breakout-Strategy-pdf.pdf).
// Card: artifacts/cards_approved/QM5_11452_big-ben-fade-asian-range-m5.md
//       (g0_status APPROVED).
//
// Concept (London "fade" of the Asian-range false breakout, M5):
//   In the hour before the London open price sometimes "fakes out" the Asian
//   range — breaking above the Asian high or below the Asian low — then snaps
//   back inside. At the London open the first M5 bar that CLOSES back inside the
//   Asian range after that pre-London probe is the Big Ben fade entry. We fade
//   the failed breakout back toward the centre of the Asian range.
//
// BROKER-TIME / DST DISCIPLINE (binding, per card + .DWX invariants):
//   The card states all session windows in GMT (UTC). MT5 bar timestamps are in
//   BROKER time (DXZ = NY-close, GMT+2 winter / GMT+3 summer, DST-aware). So every
//   gating decision converts the CLOSED bar's broker open-time to UTC via
//   QM_BrokerToUTC and compares the UTC hour-of-day against the card's GMT
//   windows. No wall-clock, no raw broker-hour assumption — the conversion makes
//   the windows correct across US-DST transitions year round.
//
//   Asian range window (GMT) : 00:00 <= utc_hour < 07:00  (high/low of bars)
//   Pre-London probe (GMT)   : 07:00 <= utc_hour < 08:00  (the fakeout hour)
//   London fade window (GMT) : 08:00 <= utc_hour < 09:00  (entry must occur here)
//   Time stop (GMT)          : utc_hour >= 09:00           (force-close)
//
//   Asian range : HIGH/LOW based (card Implementation Notes: asian_high =
//                 max(High[i]), asian_low = min(Low[i]) over the Asian window).
//                 Built from PRIOR CLOSED bars only (shift >= 1); never the live
//                 forming bar.
//   Probe EVENT : during the pre-London window a closed bar's Low < asian_low -
//                 probe_pips (false breakdown => bias LONG) OR High > asian_high +
//                 probe_pips (false breakout => bias SHORT). Both sides probe in a
//                 session => ambiguous => skip the day.
//   Fade EVENT  : the single trigger — the first M5 bar in the London window that
//                 CLOSES back inside the swept boundary (close > asian_low for a
//                 LONG, close < asian_high for a SHORT). Enter at that bar.
//   Range gate  : Asian range width must be within [min,max] pips, else no trade.
//   Stop loss   : beyond the swept Asian boundary by sl_buffer_pips, capped at
//                 sl_cap_pips. Fail-open spread guard.
//   Target      : Asian-range midpoint, floored at entry +/- a small min distance
//                 so a near-midpoint entry still has a workable TP.
//   Time stop   : any open position is flat-closed at/after 09:00 GMT.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11452;
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
// Session windows in GMT (UTC) hour-of-day. The closed-bar broker timestamp is
// converted to UTC (QM_BrokerToUTC) before comparison, so these stay constant
// across US-DST transitions. Card: Asian 00:00-07:00, pre-London probe
// 07:00-08:00, London fade 08:00-09:00, time stop 09:00 GMT.
input int    strategy_asian_start_hour    = 0;     // Asian range start (GMT hour, inclusive)
input int    strategy_asian_end_hour      = 7;     // Asian range end / probe start (GMT hour, exclusive)
input int    strategy_london_open_hour    = 8;     // London open / fade window start (GMT hour)
input int    strategy_time_stop_hour      = 9;     // force-close hour (GMT hour, >= => exit)
input double strategy_probe_pips          = 3.0;   // probe must extend this far beyond the range
input double strategy_range_min_pips      = 15.0;  // Asian range minimum width (pips)
input double strategy_range_max_pips      = 70.0;  // Asian range maximum width (pips)
input double strategy_sl_buffer_pips      = 10.0;  // SL beyond the swept Asian boundary (pips)
input int    strategy_sl_cap_pips         = 25;    // SL distance hard cap (pips)
input double strategy_tp_min_pips         = 10.0;  // floor TP at least this far from entry (pips)
input double strategy_spread_pct_of_stop  = 25.0;  // skip only if spread > this % of stop distance
input double strategy_spread_cap_pips     = 15.0;  // absolute spread cap (pips); card spread cap

// -----------------------------------------------------------------------------
// File-scope per-day session state (advanced once per closed M5 bar).
// -----------------------------------------------------------------------------
#define BB_PHASE_IDLE        0   // before / outside the trading window for today
#define BB_PHASE_ASIAN       1   // accumulating the Asian high/low range
#define BB_PHASE_PRE_LONDON  2   // Asian frozen, watching for the pre-London probe
#define BB_PHASE_FADE_WAIT   3   // probe seen, waiting for the fade close at London open
#define BB_PHASE_DONE        4   // entry taken or window closed for today

int      g_phase            = BB_PHASE_IDLE;
int      g_session_day      = -1;     // UTC day-of-year the current Asian session belongs to
double   g_asian_high       = 0.0;    // high of the Asian range
double   g_asian_low        = 0.0;    // low  of the Asian range
bool     g_asian_seen       = false;  // at least one Asian bar accumulated
int      g_probe_dir        = 0;      // +1 = probed low (bias LONG), -1 = probed high (bias SHORT)
bool     g_probe_both       = false;  // both sides probed => ambiguous => skip
datetime g_last_state_bar   = 0;      // open-time of the last bar folded into the state machine

// UTC (GMT) hour/day of a broker-time bar timestamp. The bar timestamp is broker
// time; convert to UTC so the GMT card windows gate correctly across DST.
int BB_UtcHour(const datetime broker_bar_open)
  {
   const datetime utc = QM_BrokerToUTC(broker_bar_open);
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   return dt.hour;
  }

int BB_UtcDayOfYear(const datetime broker_bar_open)
  {
   const datetime utc = QM_BrokerToUTC(broker_bar_open);
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   return dt.day_of_year;
  }

// Reset the daily state machine for a fresh Asian session.
void BB_ResetForDay(const int doy)
  {
   g_phase       = BB_PHASE_ASIAN;
   g_session_day = doy;
   g_asian_high  = 0.0;
   g_asian_low   = 0.0;
   g_asian_seen  = false;
   g_probe_dir   = 0;
   g_probe_both  = false;
  }

// -----------------------------------------------------------------------------
// State advance — called ONCE per new closed bar (shift 1 is the bar that just
// closed). Reads only that one closed bar; no history scans. Advances the
// Asian-range / probe state machine by exactly one bar.
// -----------------------------------------------------------------------------
void BB_AdvanceState_OnNewBar()
  {
   const datetime bar_open = iTime(_Symbol, _Period, 1);   // perf-allowed: closed-bar open time (broker)
   if(bar_open <= 0 || bar_open == g_last_state_bar)
      return;
   g_last_state_bar = bar_open;

   const int hour = BB_UtcHour(bar_open);      // GMT hour-of-day of the closed bar
   const int doy  = BB_UtcDayOfYear(bar_open); // GMT day-of-year of the closed bar

   const double h = iHigh(_Symbol, _Period, 1);            // perf-allowed: closed-bar OHLC
   const double l = iLow(_Symbol, _Period, 1);             // perf-allowed: closed-bar OHLC
   const double c = iClose(_Symbol, _Period, 1);           // perf-allowed: closed-bar OHLC
   if(h <= 0.0 || l <= 0.0 || c <= 0.0)
      return;

   const bool in_asian = (hour >= strategy_asian_start_hour && hour < strategy_asian_end_hour);

   // A bar inside the Asian window starts (or continues) the session for its day.
   if(in_asian && doy != g_session_day)
      BB_ResetForDay(doy);          // fresh Asian session begins

   // ---- Phase: accumulate the Asian HIGH/LOW range ----
   if(g_phase == BB_PHASE_ASIAN && in_asian && doy == g_session_day)
     {
      if(!g_asian_seen)
        {
         g_asian_high = h;
         g_asian_low  = l;
         g_asian_seen = true;
        }
      else
        {
         if(h > g_asian_high) g_asian_high = h;
         if(l < g_asian_low)  g_asian_low  = l;
        }
      return;
     }

   // Only act on the rest of the machine for the day we have a range for.
   if(doy != g_session_day || !g_asian_seen)
      return;

   // Asian window has ended -> arm the pre-London probe watch.
   if(g_phase == BB_PHASE_ASIAN && hour >= strategy_asian_end_hour)
      g_phase = BB_PHASE_PRE_LONDON;

   const double probe_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_probe_pips));

   // ---- Phase: watch for the pre-London probe (false breakout) ----
   if(g_phase == BB_PHASE_PRE_LONDON)
     {
      const bool in_pre_london = (hour >= strategy_asian_end_hour && hour < strategy_london_open_hour);
      if(in_pre_london)
        {
         const bool broke_low  = (l < g_asian_low  - probe_dist);   // false breakdown -> fade LONG
         const bool broke_high = (h > g_asian_high + probe_dist);   // false breakout  -> fade SHORT
         if(broke_low && broke_high)
            g_probe_both = true;                 // same bar swept both extremes -> ambiguous
         else if(broke_low)
           {
            if(g_probe_dir == -1) g_probe_both = true; else g_probe_dir = +1;
           }
         else if(broke_high)
           {
            if(g_probe_dir == +1) g_probe_both = true; else g_probe_dir = -1;
           }
        }
      // London open reached: arm the fade only if exactly one side probed.
      if(hour >= strategy_london_open_hour)
         g_phase = (g_probe_dir != 0 && !g_probe_both) ? BB_PHASE_FADE_WAIT : BB_PHASE_DONE;
     }

   // Past the time-stop hour -> the day's opportunity is over.
   if(hour >= strategy_time_stop_hour && g_phase != BB_PHASE_DONE)
      g_phase = BB_PHASE_DONE;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // .DWX models zero spread in the tester — never block on it

   // Absolute spread cap (card: 15 pips).
   const double spread_cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_spread_cap_pips));
   if(spread_cap_dist > 0.0 && spread > spread_cap_dist)
      return true;

   // Relative cap vs. the SL distance.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(stop_distance > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Big Ben fade entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// The closed bar (shift 1) is the candidate fade bar at the London open.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_phase != BB_PHASE_FADE_WAIT || g_probe_dir == 0 || g_probe_both || !g_asian_seen)
      return false;

   const datetime bar_open = iTime(_Symbol, _Period, 1);   // perf-allowed: closed-bar open time (broker)
   const int hour = BB_UtcHour(bar_open);                  // GMT hour of the closed bar

   // Fade only inside the London window [london_open, time_stop) GMT.
   if(hour < strategy_london_open_hour || hour >= strategy_time_stop_hour)
      return false;

   const double c = iClose(_Symbol, _Period, 1);           // perf-allowed: fade-bar close
   if(c <= 0.0)
      return false;

   const double range = g_asian_high - g_asian_low;
   if(range <= 0.0)
      return false;

   // Asian-range width gate (card: min 15 / max 70 pips).
   const double range_min = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_range_min_pips));
   const double range_max = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_range_max_pips));
   if(range_min > 0.0 && range < range_min) { g_phase = BB_PHASE_DONE; return false; }
   if(range_max > 0.0 && range > range_max) { g_phase = BB_PHASE_DONE; return false; }

   const double midpoint    = (g_asian_high + g_asian_low) * 0.5;
   const double sl_buf_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sl_buffer_pips));
   const double sl_cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   const double tp_min_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_tp_min_pips));

   if(g_probe_dir > 0)
     {
      // Fade LONG: the false breakdown closed back ABOVE the Asian low.
      if(!(c > g_asian_low))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // SL beyond the swept Asian low by the buffer, capped at sl_cap_pips.
      double sl = g_asian_low - sl_buf_dist;
      if(sl_cap_dist > 0.0 && (entry - sl) > sl_cap_dist)
         sl = entry - sl_cap_dist;
      if(!(sl < entry))
         return false;

      // TP = Asian midpoint, floored at entry + a minimum distance.
      double tp = MathMax(midpoint, entry + tp_min_dist);
      if(tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "bigben_fade_long";
      g_phase    = BB_PHASE_DONE;     // one fade per day
      return true;
     }
   else
     {
      // Fade SHORT: the false breakout closed back BELOW the Asian high.
      if(!(c < g_asian_high))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      // SL beyond the swept Asian high by the buffer, capped at sl_cap_pips.
      double sl = g_asian_high + sl_buf_dist;
      if(sl_cap_dist > 0.0 && (sl - entry) > sl_cap_dist)
         sl = entry + sl_cap_dist;
      if(!(sl > entry))
         return false;

      // TP = Asian midpoint, floored at entry - a minimum distance.
      double tp = MathMin(midpoint, entry - tp_min_dist);
      if(tp <= 0.0 || tp >= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "bigben_fade_short";
      g_phase    = BB_PHASE_DONE;
      return true;
     }
  }

// No active trade management beyond the fixed SL/TP. Time stop is in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Time stop: flat-close any open position at/after the time-stop GMT hour.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // Current (live) broker time -> UTC so the GMT time-stop fires promptly,
   // not only on a new bar.
   const int hour = BB_UtcHour(TimeCurrent());

   // Close inside the daily cutoff band [time_stop, friday_close]. A bare
   // ">= time_stop" would also fire in the evening; bound it to the morning.
   if(hour >= strategy_time_stop_hour && hour < 20)
      return true;

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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   if(!QM_IsNewBar())
      return;

   // FIRST on the closed-bar path: advance the Asian-range / probe state machine.
   BB_AdvanceState_OnNewBar();

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
