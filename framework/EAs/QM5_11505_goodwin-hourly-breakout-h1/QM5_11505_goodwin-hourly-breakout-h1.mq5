#property strict
#property version   "5.0"
#property description "QM5_11505 goodwin-hourly-breakout-h1 — NY-session breakout + prior-day bias (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11505 goodwin-hourly-breakout-h1
// -----------------------------------------------------------------------------
// Source: Jarrod Goodwin, "Beat the Markets — Strategy Guidebook" (~2014).
// Card: artifacts/cards_approved/QM5_11505_goodwin-hourly-breakout-h1.md (APPROVED).
//
// Concept (H1, FX):
//   Prior-day DIRECTIONAL BIAS gates the side. Then the NY-session pre-range
//   (high/low accumulated from the session-start hour up to the current bar) is
//   a STATE. The first H1 close that breaks beyond that extreme, in the bias
//   direction, is the single trigger EVENT -> market entry. Overnight risk is
//   removed by a hard session-end time exit.
//
// Sessions are reckoned in BROKER TIME. The source quotes "17:05 EST"
// (NY-session anchor). On DXZ NY-Close broker time that lands at ~broker-hour 0
// (GMT+2, US standard time) / ~broker-hour 1 (GMT+3, US DST). We derive the
// DST shift automatically from QM_IsUSDSTUTC(...) instead of a manual offset,
// so the window tracks the season and never builds the range in dead hours.
//
// .DWX invariants honoured:
//   * Spread guard fails OPEN on zero modeled spread (only a genuinely wide
//     spread blocks).
//   * The breakout is ONE event (first close beyond the pre-range extreme),
//     latched once-per-session -> no two-cross-same-bar zero-trade trap.
//   * Range / SL / TP thresholds expressed in pips via the framework
//     pip-aware helper (correct on 5-digit and JPY symbols).
//   * Bar hours read from broker-time bar-open timestamps, not raw clock minutes.
//
// State advances once per closed H1 bar (QM_IsNewBar gate). The per-tick path
// is O(1): cached session extremes + current-bar compare.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11505;
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
// Session-start broker hour at US STANDARD time (GMT+2). 17:05 EST -> 22:05 UTC
// -> 00:05 broker (GMT+2). During US DST the framework shifts this +1 hour
// automatically (-> broker hour 1), derived from QM_IsUSDSTUTC.
input int    strategy_session_start_hour_gmt2 = 0;   // broker hour the NY pre-range opens (US-standard)
input int    strategy_session_len_hours       = 3;   // hours of pre-range accumulation before breakouts arm
input int    strategy_session_end_hour_gmt2   = 3;   // broker hour to flatten (US-standard); ~21:30-22:00 EST
input int    strategy_sl_pips                 = 150; // fixed stop (source-specified)
input double strategy_tp_rr                   = 2.0; // take-profit = tp_rr * SL distance
input double strategy_breakout_buffer_pips    = 1.0; // breakout buffer beyond the pre-range extreme
input bool   strategy_skip_friday_entry       = true; // no fresh entries on Friday (overnight->weekend)
input double strategy_spread_cap_pips         = 15.0; // skip only a genuinely wide spread

// -----------------------------------------------------------------------------
// Cached per-closed-bar session state. Advanced once per new H1 bar.
// -----------------------------------------------------------------------------
double   g_pre_high      = 0.0;   // pre-range high accumulated this session
double   g_pre_low       = 0.0;   // pre-range low accumulated this session
bool     g_range_armed   = false; // pre-range window complete -> breakouts live
bool     g_fired_session = false; // single-event latch: one entry attempt per session
int      g_session_day   = -1;    // day-of-year tag identifying the current session
bool     g_bias_long     = false; // prior-day bias resolved for this session
bool     g_bias_short    = false;
double   g_pip_size      = 0.0;   // 1 pip in price units (scale-correct)

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// 1 pip in price units for this symbol (10 points on 3/5-digit, 1 point else).
double SessionPipSize()
  {
   if(g_pip_size > 0.0)
      return g_pip_size;
   const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long   digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double factor = (digits == 3 || digits == 5) ? 10.0 : 1.0;
   g_pip_size = point * factor;
   return g_pip_size;
  }

// DST-aware NY-session start hour in BROKER time for a given broker bar-open.
int SessionStartHourBroker(const datetime broker_bar_open)
  {
   const datetime utc = QM_BrokerToUTC(broker_bar_open);
   const int shift = QM_IsUSDSTUTC(utc) ? 1 : 0;   // +1 broker hour during US DST
   return strategy_session_start_hour_gmt2 + shift;
  }

int SessionEndHourBroker(const datetime broker_bar_open)
  {
   const datetime utc = QM_BrokerToUTC(broker_bar_open);
   const int shift = QM_IsUSDSTUTC(utc) ? 1 : 0;
   return strategy_session_end_hour_gmt2 + shift;
  }

// Advance the cached session state by one closed H1 bar. Bounded, perf-allowed:
// a constant number of closed-bar reads, no per-tick lookback.
void AdvanceState_OnNewBar()
  {
   // The just-closed bar (shift 1) is the newest completed H1 bar.
   const datetime bar_open = iTime(_Symbol, _Period, 1);   // perf-allowed: broker-time bar stamp
   if(bar_open <= 0)
      return;

   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(bar_open, dt);
   const int bar_hour = dt.hour;                  // broker-time hour of the closed bar
   const int day_tag  = dt.year * 366 + dt.day_of_year;

   const int start_hour = SessionStartHourBroker(bar_open);

   // New session begins on the session-start hour. Reset all session state and
   // resolve the prior-day directional bias once, at the session open.
   if(bar_hour == start_hour && day_tag != g_session_day)
     {
      g_session_day   = day_tag;
      g_pre_high      = 0.0;
      g_pre_low       = 0.0;
      g_range_armed   = false;
      g_fired_session = false;

      // Prior-day bias: most recently completed D1 bar (perf-allowed closed-bar reads).
      const double d1_open  = iOpen(_Symbol, PERIOD_D1, 1);
      const double d1_close = iClose(_Symbol, PERIOD_D1, 1);
      g_bias_long  = (d1_close > 0.0 && d1_open > 0.0 && d1_close > d1_open);
      g_bias_short = (d1_close > 0.0 && d1_open > 0.0 && d1_close < d1_open);
     }

   // Only accumulate / arm while we are inside the active session day.
   if(day_tag != g_session_day)
      return;

   // Pre-range accumulation window: [start_hour, start_hour + session_len).
   const int hours_into = bar_hour - start_hour;
   if(hours_into >= 0 && hours_into < strategy_session_len_hours)
     {
      const double bar_high = iHigh(_Symbol, _Period, 1);  // perf-allowed: closed-bar extreme
      const double bar_low  = iLow(_Symbol, _Period, 1);
      if(bar_high > 0.0 && (g_pre_high == 0.0 || bar_high > g_pre_high))
         g_pre_high = bar_high;
      if(bar_low > 0.0 && (g_pre_low == 0.0 || bar_low < g_pre_low))
         g_pre_low = bar_low;
     }

   // Once the accumulation window has fully elapsed, the pre-range is frozen
   // and breakouts are armed for the remainder of the session.
   if(hours_into >= strategy_session_len_hours && g_pre_high > 0.0 && g_pre_low > 0.0)
      g_range_armed = true;
  }

// True if the supplied broker bar-open is within the live breakout window:
// after the pre-range is armed and before the flatten hour, same session day.
bool InBreakoutWindow(const datetime broker_bar_open)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_bar_open, dt);
   const int day_tag = dt.year * 366 + dt.day_of_year;
   if(day_tag != g_session_day)
      return false;

   const int start_hour = SessionStartHourBroker(broker_bar_open);
   const int end_hour   = SessionEndHourBroker(broker_bar_open);
   const int hours_into = dt.hour - start_hour;
   if(hours_into < strategy_session_len_hours)
      return false;                      // still inside the pre-range window
   if(dt.hour >= end_hour)
      return false;                      // flatten window reached -> no new entries
   return true;
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
      return false;                      // no valid quote yet — do not block

   const double pip = SessionPipSize();
   if(pip <= 0.0)
      return false;

   const double spread = ask - bid;
   const double cap    = strategy_spread_cap_pips * pip;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Session breakout entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   // Single trigger event per session.
   if(g_fired_session)
      return false;
   // Pre-range must be complete and breakouts armed.
   if(!g_range_armed)
      return false;

   const datetime bar_open = iTime(_Symbol, _Period, 1); // perf-allowed: broker-time bar stamp
   if(bar_open <= 0)
      return false;
   if(!InBreakoutWindow(bar_open))
      return false;

   // Optional no-Friday-entry guard (overnight risk into the weekend).
   if(strategy_skip_friday_entry)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      TimeToStruct(bar_open, dt);
      if(dt.day_of_week == 5)            // Friday
         return false;
     }

   const double pip = SessionPipSize();
   if(pip <= 0.0)
      return false;
   const double buffer = strategy_breakout_buffer_pips * pip;

   // The breakout EVENT: the just-closed bar's close clears the frozen pre-range
   // extreme (plus buffer), in the prior-day bias direction. One side only.
   const double close1 = iClose(_Symbol, _Period, 1);   // perf-allowed: closed-bar trigger ref
   if(close1 <= 0.0)
      return false;

   QM_OrderType side;
   double entry;
   if(g_bias_long && close1 > (g_pre_high + buffer))
     {
      side  = QM_BUY;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   else if(g_bias_short && close1 < (g_pre_low - buffer))
     {
      side  = QM_SELL;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     }
   else
      return false;

   if(entry <= 0.0)
      return false;

   // Fixed-pips stop (source: 150 pips), RR-multiple take-profit.
   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   g_fired_session = true;               // latch: one attempt per session

   req.type   = side;
   req.price  = 0.0;                     // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "ny_breakout_long" : "ny_breakout_short";
   return true;
  }

// Fixed SL/TP only; no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// Hard session-end time exit: flatten when broker time reaches the flatten hour.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   const int end_hour = SessionEndHourBroker(broker_now);

   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_now, dt);
   // Flatten once the broker clock reaches the session-end hour (overnight-risk
   // removal). The window runs end_hour..end_hour+1 to catch the rollover.
   return (dt.hour >= end_hour && dt.hour < end_hour + 2);
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

   SessionPipSize();                     // cache pip size once
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

   AdvanceState_OnNewBar();              // advance cached session state, once/bar

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
