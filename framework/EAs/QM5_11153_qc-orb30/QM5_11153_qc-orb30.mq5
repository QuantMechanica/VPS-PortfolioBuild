#property strict
#property version   "5.0"
#property description "QM5_11153 qc-orb30 — 30-minute Opening Range Breakout (M1, US index CFDs)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11153 qc-orb30
// -----------------------------------------------------------------------------
// Source: QuantConnect Boot Camp "Opening Range Breakout" (Greg Kendall mirror).
// Card: artifacts/cards_approved/QM5_11153_qc-orb30.md (g0_status APPROVED).
//
// Mechanics (M1, intraday, broker-time sessions, closed-bar reads):
//   Opening range : the first `range_minutes` (30) of the US index cash session.
//                   09:30 ET cash open == 16:30 broker year-round (DXZ NY-Close
//                   GMT+2/+3 tracks US DST in lockstep with ET, so the broker
//                   open is a constant minute-of-day). High/low are accumulated
//                   from PRIOR CLOSED M1 bars whose broker-time minute-of-day
//                   falls inside the range window — never a fixed wall-clock.
//   Entry         : after the range window closes, on a closed M1 bar:
//                     close > rangeHigh  -> long  (QM_BUY)
//                     close < rangeLow   -> short (QM_SELL)
//                   one position per symbol/magic; one entry per session.
//   Stop          : opposite side of the opening range +/- a spread/buffer that
//                   is `stop_buffer_atr_mult` * ATR(atr_period, M30). Optional
//                   P3 sweep widens via stop_range_mult on the range height.
//   Exit          : timed liquidation at `exit_minute_broker` (13:30 ET ==
//                   20:30 broker == 1230 min). Fallback: `hold_minutes_max`
//                   (210) after the session open if the timed close did not
//                   fire. Emergency exit at `session_end_minute_broker`.
//   Range filter  : skip if range height < broker min stop distance, or
//                   range height > range_atr_cap_mult * ATR(14, M30).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
//
// .DWX invariants honoured: broker-time session via constant offset (no raw
// ET/UTC window), prior-CLOSED M1 bars for the range, fail-OPEN spread guard
// (never block on zero modeled spread / zero swap), bar-open-time keying (no
// exact tick-minute equality), QM_IsNewBar consumed once on the entry path.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11153;
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
// Session windows expressed as BROKER-time minute-of-day (hour*60+min).
// US index cash open 09:30 ET == 16:30 broker (NY-Close GMT+2/+3 tracks US DST
// in lockstep with ET, so the broker open minute is constant year-round).
input int    session_open_minute_broker   = 990;   // 16:30 broker = 09:30 ET cash open
input int    range_minutes                = 30;    // opening-range window length (minutes)
input int    exit_minute_broker           = 1230;  // 20:30 broker = 13:30 ET timed liquidation
input int    hold_minutes_max             = 210;   // fallback: minutes after open to force-close
input int    session_end_minute_broker    = 1320;  // 22:00 broker emergency exit if timed close missed
input int    atr_period                   = 14;    // ATR period on M30 for buffer / range cap
input double stop_buffer_atr_mult         = 0.10;  // stop buffer beyond range = mult * ATR(M30)
input double stop_range_mult              = 1.00;  // P3 sweep: stop distance = mult * range height (>=1 keeps opp-side floor)
input double range_atr_cap_mult           = 1.50;  // skip if range height > mult * ATR(14,M30)

// -----------------------------------------------------------------------------
// File-scope cached opening-range state (advanced once per closed M1 bar).
// -----------------------------------------------------------------------------
datetime g_session_date        = 0;      // broker-date (midnight) of the active session
double   g_range_high          = 0.0;    // opening-range high (prior closed bars)
double   g_range_low           = 0.0;    // opening-range low
bool     g_range_built         = false;  // range window has fully closed
bool     g_range_active        = false;  // currently inside the range-accumulation window
bool     g_entered_this_day    = false;  // one entry per session guard

// Broker-time minute-of-day for a broker timestamp.
int BrokerMinuteOfDay(const datetime broker_t)
  {
   MqlDateTime st;
   TimeToStruct(broker_t, st);
   return st.hour * 60 + st.min;
  }

// Broker-date (midnight) for a broker timestamp.
datetime BrokerDateOnly(const datetime broker_t)
  {
   MqlDateTime st;
   TimeToStruct(broker_t, st);
   st.hour = 0;
   st.min  = 0;
   st.sec  = 0;
   return StructToTime(st);
  }

// Advance the opening-range state from the LAST CLOSED M1 bar (shift 1).
// Called once per new closed bar on the entry path (after QM_IsNewBar()).
void AdvanceRange_OnNewBar()
  {
   const datetime bar_open = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar open time
   if(bar_open <= 0)
      return;

   const datetime bar_date = BrokerDateOnly(bar_open);
   const int      bar_min  = BrokerMinuteOfDay(bar_open);

   // New broker-session day -> reset the range state.
   if(bar_date != g_session_date)
     {
      g_session_date     = bar_date;
      g_range_high       = 0.0;
      g_range_low        = 0.0;
      g_range_built      = false;
      g_range_active     = false;
      g_entered_this_day = false;
     }

   const int range_open  = session_open_minute_broker;
   const int range_close = session_open_minute_broker + range_minutes; // exclusive

   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: closed-bar read

   // Inside the opening-range accumulation window.
   if(bar_min >= range_open && bar_min < range_close)
     {
      if(high1 > 0.0 && low1 > 0.0)
        {
         if(!g_range_active)
           {
            g_range_high   = high1;
            g_range_low    = low1;
            g_range_active = true;
           }
         else
           {
            if(high1 > g_range_high) g_range_high = high1;
            if(low1  < g_range_low)  g_range_low  = low1;
           }
        }
     }
   else if(bar_min >= range_close && g_range_active && !g_range_built)
     {
      // First closed bar at/after the window end seals the range.
      g_range_built = true;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Fail-OPEN spread guard only (zero modeled spread on
// .DWX must NOT block). All session/range work is on the closed-bar path.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing/zero quote

   // Block only a GENUINELY wide spread relative to the opening-range height.
   if(g_range_built && g_range_high > g_range_low)
     {
      const double range_height = g_range_high - g_range_low;
      const double spread       = ask - bid;
      if(spread > 0.0 && range_height > 0.0 && spread > 0.5 * range_height)
         return true;
     }
   return false;
  }

// Breakout entry on a closed M1 bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance the cached opening-range state for this newly closed bar.
   AdvanceRange_OnNewBar();

   // One position per symbol/magic, one entry per session.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_entered_this_day)
      return false;
   if(!g_range_built)
      return false;
   if(!(g_range_high > g_range_low))
      return false;

   const datetime bar_open = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar open time
   if(bar_open <= 0)
      return false;
   const int bar_min = BrokerMinuteOfDay(bar_open);

   // Only trade between range close and the timed-exit minute.
   if(bar_min < session_open_minute_broker + range_minutes)
      return false;
   if(bar_min >= exit_minute_broker)
      return false;

   const double range_height = g_range_high - g_range_low;

   // Range-quality filter: skip if range height exceeds ATR(M30) cap, or is
   // below the broker minimum stop distance.
   const double atr_m30 = QM_ATR(_Symbol, PERIOD_M30, atr_period, 1);
   if(atr_m30 > 0.0 && range_height > range_atr_cap_mult * atr_m30)
      return false;

   const double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long   stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop    = (point > 0.0) ? (double)stops_level * point : 0.0;
   if(min_stop > 0.0 && range_height < min_stop)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   if(close1 <= 0.0)
      return false;

   const double buffer = (atr_m30 > 0.0) ? stop_buffer_atr_mult * atr_m30 : 0.0;
   // Stop distance: at least the opposite range side + buffer; sweep can widen.
   const double base_stop_dist = range_height + buffer;
   const double stop_dist      = MathMax(base_stop_dist, stop_range_mult * range_height);

   // Long breakout: close above the range high.
   if(close1 > g_range_high)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, entry - stop_dist);
      if(sl <= 0.0 || sl >= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed target; timed exit governs
      req.reason = "orb30_long";
      g_entered_this_day = true;
      return true;
     }

   // Short breakout: close below the range low.
   if(close1 < g_range_low)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, entry + stop_dist);
      if(sl <= 0.0 || sl <= entry)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "orb30_short";
      g_entered_this_day = true;
      return true;
     }

   return false;
  }

// No active trade management — fixed opening-range stop + timed exit only.
void Strategy_ManageOpenPosition()
  {
  }

// Timed liquidation. Closes the position at/after the broker-time exit minute,
// the hold-time fallback, or the session-end emergency window. O(1) per tick.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   const int now_min = BrokerMinuteOfDay(broker_now);

   // Primary scheduled liquidation at the timed-exit minute.
   if(now_min >= exit_minute_broker)
      return true;

   // Fallback: force-close `hold_minutes_max` after the session open.
   if(now_min >= session_open_minute_broker + hold_minutes_max)
      return true;

   // Emergency exit if the scheduled close was missed and the session is ending.
   if(now_min >= session_end_minute_broker)
      return true;

   return false;
  }

// Defer to the central two-axis news filter.
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
