#property strict
#property version   "5.0"
#property description "QM5_11409 big-ben-london-fade-asian-range-m15 — London fade of the Asian-range false breakout (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11409 big-ben-london-fade-asian-range-m15
// -----------------------------------------------------------------------------
// Source: "Big Ben Breakout Strategy" (TradingStrategyGuides.com, ~2017).
// Card: artifacts/cards_approved/QM5_11409_big-ben-london-fade-asian-range-m15.md
//       (g0_status APPROVED).
//
// Concept (London "fade" of the Asian-range false breakout):
//   Pre-London, price sweeps the Asian-session range to grab stops, then reverses
//   ("fades") back into the range at the London open. We fade that sweep.
//
// All session windows come from the bar TIMESTAMP in BROKER time. The DXZ broker
// clock is NY-close (GMT+2 winter / GMT+3 summer) and shifts with US DST itself,
// so the broker-hour constants from the card are constant year-round and are
// compared directly against the closed-bar open time. NO wall-clock, NO UTC math
// is needed for the gating — the chart already runs on broker time.
//
//   Asian session (body range)   : 01:00 <= broker_hour < 09:00 broker time.
//   Pre-London sweep window      : 09:00 <= broker_hour < 10:00 broker time.
//   London open / fade window    : 10:00 <= broker_hour < 11:00 broker time.
//   Time stop (force close)      : broker_hour >= 11:00 broker time.
//
//   Asian range : BODY-based — asian_high = max(open,close) over Asian bars,
//                 asian_low  = min(open,close) over Asian bars. Built from PRIOR
//                 CLOSED bars only (shift >= 1); never the live forming bar.
//   Sweep EVENT : during the pre-London window a bar's Low < asian_low (=> bias
//                 LONG, a false breakdown) OR High > asian_high (=> bias SHORT).
//   Fade EVENT  : the single trigger — the first M15 bar in the London window that
//                 CLOSES back through the swept boundary (close > asian_low for a
//                 LONG, close < asian_high for a SHORT). Enter at that bar.
//   Stop loss   : reversal-bar extreme (Low for long / High for short), capped at
//                 sl_cap_pips (M15 bars are small). Fail-open spread guard.
//   Target      : Asian-range height projected from entry (TP = entry +/- range).
//   Time stop   : any open position is flat-closed at/after 11:00 broker.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11409;
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
// Session windows in BROKER time (hour-of-day). Card: Asian 01:00-09:00,
// pre-London sweep 09:00-10:00, London open 10:00, time stop 11:00 broker.
input int    strategy_asian_start_hour    = 1;     // Asian session start (broker hour, inclusive)
input int    strategy_asian_end_hour      = 9;     // Asian session end   (broker hour, exclusive)
input int    strategy_london_open_hour    = 10;    // London open / fade window start (broker hour)
input int    strategy_time_stop_hour      = 11;    // force-close hour (broker hour, >= => exit)
input double strategy_tp_range_mult       = 1.0;   // TP = entry +/- range * this mult
input int    strategy_sl_cap_pips         = 40;    // SL distance cap (pips); M15 bars are small
input double strategy_spread_pct_of_stop  = 25.0;  // skip only if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope per-day session state (advanced once per closed M15 bar).
// -----------------------------------------------------------------------------
// Phase of the daily state machine.
#define BB_PHASE_IDLE        0   // before / outside the trading window for today
#define BB_PHASE_ASIAN       1   // accumulating the Asian body range
#define BB_PHASE_PRE_LONDON  2   // Asian frozen, watching for the pre-London sweep
#define BB_PHASE_FADE_WAIT   3   // sweep seen, waiting for the fade close at London open
#define BB_PHASE_DONE        4   // entry taken or window closed for today

int      g_phase            = BB_PHASE_IDLE;
int      g_session_day      = -1;     // day-of-year the current Asian session belongs to
double   g_asian_high       = 0.0;    // body high of the Asian range
double   g_asian_low        = 0.0;    // body low  of the Asian range
bool     g_asian_seen       = false;  // at least one Asian bar accumulated
int      g_sweep_dir        = 0;      // +1 = swept low (bias LONG), -1 = swept high (bias SHORT)
datetime g_last_state_bar   = 0;      // open-time of the last bar folded into the state machine

// Broker MqlDateTime helpers ------------------------------------------------
int BB_BrokerHour(const datetime broker_bar_open)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_bar_open, dt);
   return dt.hour;
  }

int BB_BrokerDayOfYear(const datetime broker_bar_open)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_bar_open, dt);
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
   g_sweep_dir   = 0;
  }

// -----------------------------------------------------------------------------
// State advance — called ONCE per new closed bar (shift 1 is the bar that just
// closed). Reads only that one closed bar; no history scans. This advances the
// Asian-range / sweep state machine by exactly one bar.
// -----------------------------------------------------------------------------
void BB_AdvanceState_OnNewBar()
  {
   const datetime bar_open = iTime(_Symbol, _Period, 1);   // perf-allowed: closed-bar open time
   if(bar_open <= 0 || bar_open == g_last_state_bar)
      return;
   g_last_state_bar = bar_open;

   const int hour = BB_BrokerHour(bar_open);
   const int doy  = BB_BrokerDayOfYear(bar_open);

   const double o = iOpen(_Symbol, _Period, 1);            // perf-allowed: closed-bar OHLC
   const double h = iHigh(_Symbol, _Period, 1);            // perf-allowed: closed-bar OHLC
   const double l = iLow(_Symbol, _Period, 1);             // perf-allowed: closed-bar OHLC
   const double c = iClose(_Symbol, _Period, 1);           // perf-allowed: closed-bar OHLC
   if(o <= 0.0 || h <= 0.0 || l <= 0.0 || c <= 0.0)
      return;

   // A bar inside the Asian window starts (or continues) the session for its day.
   const bool in_asian = (hour >= strategy_asian_start_hour && hour < strategy_asian_end_hour);

   if(in_asian && doy != g_session_day)
      BB_ResetForDay(doy);          // fresh Asian session begins

   // ---- Phase: accumulate the Asian BODY range ----
   if(g_phase == BB_PHASE_ASIAN && in_asian && doy == g_session_day)
     {
      const double body_hi = MathMax(o, c);
      const double body_lo = MathMin(o, c);
      if(!g_asian_seen)
        {
         g_asian_high = body_hi;
         g_asian_low  = body_lo;
         g_asian_seen = true;
        }
      else
        {
         if(body_hi > g_asian_high) g_asian_high = body_hi;
         if(body_lo < g_asian_low)  g_asian_low  = body_lo;
        }
      return;
     }

   // Only act on the rest of the machine for the day we have a range for.
   if(doy != g_session_day || !g_asian_seen)
      return;

   // Asian window has ended -> arm the pre-London sweep watch.
   if(g_phase == BB_PHASE_ASIAN && hour >= strategy_asian_end_hour)
      g_phase = BB_PHASE_PRE_LONDON;

   // ---- Phase: watch for the pre-London sweep (false breakout) ----
   if(g_phase == BB_PHASE_PRE_LONDON)
     {
      const bool in_pre_london = (hour >= strategy_asian_end_hour && hour < strategy_london_open_hour);
      if(in_pre_london)
        {
         if(l < g_asian_low)        g_sweep_dir = +1;   // swept the low  -> fade LONG
         else if(h > g_asian_high)  g_sweep_dir = -1;   // swept the high -> fade SHORT
        }
      // London open reached: if a sweep occurred, wait for the fade; else stand down.
      if(hour >= strategy_london_open_hour)
         g_phase = (g_sweep_dir != 0) ? BB_PHASE_FADE_WAIT : BB_PHASE_DONE;
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

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// London fade entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// The closed bar (shift 1) is the candidate reversal/fade bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_phase != BB_PHASE_FADE_WAIT || g_sweep_dir == 0 || !g_asian_seen)
      return false;

   const datetime bar_open = iTime(_Symbol, _Period, 1);   // perf-allowed: closed-bar open time
   const int hour = BB_BrokerHour(bar_open);

   // Fade only inside the London window [london_open, time_stop).
   if(hour < strategy_london_open_hour || hour >= strategy_time_stop_hour)
      return false;

   const double c = iClose(_Symbol, _Period, 1);           // perf-allowed: reversal-bar close
   const double h = iHigh(_Symbol, _Period, 1);            // perf-allowed: reversal-bar high
   const double l = iLow(_Symbol, _Period, 1);             // perf-allowed: reversal-bar low
   if(c <= 0.0 || h <= 0.0 || l <= 0.0)
      return false;

   const double range = g_asian_high - g_asian_low;
   if(range <= 0.0)
      return false;

   // SL cap as a price distance (pip-scaled, correct on 5-digit / JPY symbols).
   const double sl_cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);

   if(g_sweep_dir > 0)
     {
      // Fade LONG: the false breakdown closed back ABOVE the Asian low.
      if(!(c > g_asian_low))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // SL = reversal-bar low, but no farther than the pip cap.
      double sl = l;
      if(sl_cap_dist > 0.0 && (entry - sl) > sl_cap_dist)
         sl = entry - sl_cap_dist;
      if(!(sl < entry))
         return false;

      const double tp = entry + range * strategy_tp_range_mult;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "bigben_london_fade_long";
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

      // SL = reversal-bar high, but no farther than the pip cap.
      double sl = h;
      if(sl_cap_dist > 0.0 && (sl - entry) > sl_cap_dist)
         sl = entry + sl_cap_dist;
      if(!(sl > entry))
         return false;

      const double tp = entry - range * strategy_tp_range_mult;
      if(tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "bigben_london_fade_short";
      g_phase    = BB_PHASE_DONE;
      return true;
     }
  }

// No active trade management beyond the fixed SL/TP. Time stop is in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Time stop: flat-close any open position at/after the time-stop broker hour.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // Use the current (live) broker time for the time stop so the position is
   // closed promptly once the cutoff hour is reached, not only on a new bar.
   const datetime broker_now = TimeCurrent();
   const int hour = BB_BrokerHour(broker_now);

   // Close inside the daily cutoff band [time_stop, friday_close_hour). A bare
   // ">= time_stop" would also fire in the evening; bound it to the morning.
   if(hour >= strategy_time_stop_hour && hour < qm_friday_close_hour_broker)
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

   // FIRST on the closed-bar path: advance the Asian-range / sweep state machine.
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
