#property strict
#property version   "5.0"
#property description "QM5_12522 ftse-month-short — FTSE last-trading-day-of-month SHORT bias (D1-native)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12522 ftse-month-short
// -----------------------------------------------------------------------------
// Source: Backtest Rookies "Statistical Analysis: FTSE 100 Period Trends"
//   (2017-09-11). Card: artifacts/cards_approved/QM5_12522_ftse-month-short.md
//   (g0_status APPROVED). SHORT mirror of the FTSE turn-of-month family.
//
// Mechanics (SHORT-only, D1-native — MN1 is untestable on .DWX so the monthly
// rule is expressed on PERIOD_D1 closed bars):
//   Entry  : go SHORT at the OPEN of the FINAL TRADABLE SESSION of each calendar
//            month. The final session is derived from the broker calendar (last
//            weekday on/before the last calendar day of the month), NOT a
//            hard-coded day number. Detection happens on the new-D1-bar gate:
//            when a fresh D1 bar opens, we test whether THAT bar (shift 0) is the
//            last trading day of its month; if so we open the short at its open.
//   Exit   : close at the SAME session's end of day — never hold overnight or
//            over the month-end gap. D1-native realisation: the position opened
//            on the last-trading-day bar is closed on the very next new D1 bar
//            (the first bar of the following month), i.e. a one-bar hold that
//            equals "open of the last day -> its close".
//   Stop   : catastrophic intraday stop at sl_atr_mult * ATR(atr_period) from the
//            D1 bar, capped by fixed-risk sizing (card V5 default 1.0*ATR(14)).
//   Filter : calendar rule only; no indicator filter.
//
// Two-cross trap: there is no double-event here. Entry is a single calendar
// EVENT (this bar == last trading day); exit is a single state (a position is
// open and a new bar has started). They never need to coincide on one bar.
//
// Symbol port: card target "UK100/FTSE-style index CFD" -> UK100.DWX (the FTSE
// 100 CFD present + active in dwx_symbol_matrix.csv). Flagged in build output.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12522;
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
// Same-session exit means we never intentionally hold over a weekend; default
// Friday-close guard stays ON. If the last trading day of a month falls on a
// Friday the one-bar hold still closes on the next session — the guard would
// flatten earlier at worst, which is consistent with "no overnight hold".
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period        = 14;    // ATR period for the catastrophic stop
input double strategy_sl_atr_mult       = 1.0;   // stop distance = mult * ATR (card V5 default)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Calendar-only strategy: no spread /
// regime gate. Never block on .DWX zero spread. O(1).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Compute the day-of-month number of the LAST TRADING DAY (last Mon-Fri weekday)
// of the calendar month that `broker_day` falls in. Derived from the broker
// calendar, not hard-coded. Returns 1..31.
int LastTradingDayOfMonth(const datetime broker_day)
  {
   MqlDateTime t;
   TimeToStruct(broker_day, t);
   const int next_year = (t.mon < 12) ? t.year : t.year + 1;
   const int next_mon  = (t.mon < 12) ? t.mon + 1 : 1;
   const datetime first_of_next = StringToTime(StringFormat(
      "%04d.%02d.01 00:00", next_year, next_mon));
   // Last calendar day of this month.
   MqlDateTime last;
   TimeToStruct(first_of_next - 86400, last);
   // Walk back to the last weekday (Mon=1..Fri=5; Sat=6, Sun=0).
   datetime cur = first_of_next - 86400;
   for(int i = 0; i < 3; ++i)
     {
      MqlDateTime c;
      TimeToStruct(cur, c);
      if(c.day_of_week >= 1 && c.day_of_week <= 5)
        {
         TimeToStruct(cur, last);
         break;
        }
      cur -= 86400;
     }
   return last.day;
  }

// SHORT-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// The bar that just opened (shift 0) is the candidate entry day; we short at its
// open if it is the last trading day of its calendar month.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Broker open-time of the bar that just started (the current session).
   const datetime bar_open_broker = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-open time read
   if(bar_open_broker <= 0)
      return false; // calendar cannot be identified -> skip (card filter)

   MqlDateTime now;
   TimeToStruct(bar_open_broker, now);

   // Skip weekend bars defensively (D1 .DWX should not produce them).
   if(now.day_of_week == 0 || now.day_of_week == 6)
      return false;

   // Is THIS bar the last trading day of its month?
   const int last_td = LastTradingDayOfMonth(bar_open_broker);
   if(now.day != last_td)
      return false;

   // Catastrophic ATR stop (capped by fixed-risk sizing in the framework).
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_SELL;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target — exit is the same-session close
   req.reason = "ftse_month_short";
   return true;
  }

// No active trade management beyond the catastrophic ATR stop. Exit is handled
// by Strategy_ExitSignal on the next session boundary.
void Strategy_ManageOpenPosition()
  {
  }

// Same-session exit. The short was opened at the open of the last trading day of
// the month; close it at that session's end — realised here as "a position is
// open and a new D1 bar has started" (the next session / next month's first
// bar). One-bar hold, never overnight beyond that single session.
//
// NOTE: this hook runs on EVERY tick, but only closes once a fresh D1 bar has
// formed since the entry. We latch the entry bar-open time so we do not close on
// the same bar we entered (which would be a same-bar two-event collision).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // The position's open time vs the current bar's open time. If the current D1
   // bar opened strictly after the bar the position was opened on, the session
   // has rolled -> close now (same-session end, before the next month runs).
   const datetime cur_bar_open = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-open time read
   if(cur_bar_open <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime pos_open = (datetime)PositionGetInteger(POSITION_TIME);
      // Closed-bar boundary: a new D1 bar formed after the entry bar.
      if(cur_bar_open > pos_open)
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
