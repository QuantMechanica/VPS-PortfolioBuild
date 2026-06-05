#property strict
#property version   "5.0"
#property description "QM5_10706 TradingView Monday Liquidity Sweep (tv-mon-ls)"
// Strategy Card: QM5_10706_tv-mon-ls, G0 APPROVED 2026-05-22.
// Source: andrei_keenvent, "Monday Liquidity Sweep - WolfWeb", TradingView.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 — Monday Liquidity Sweep
// -----------------------------------------------------------------------------
// Weekly range-reversal: a Monday box (high/low formed during the logical Monday
// session) defines the week's reference range. After Monday, a candle that wicks
// just beyond the Monday high/low (sweep) and is followed by a candle closing
// back inside the range is faded — short the failed break above the high, long
// the failed break below the low. One trade per week. Exits via SL/TP, a locked
// breakeven, and the framework Friday close.
//
// All strategy state is advanced once per CLOSED bar (Strategy_EntrySignal is
// called by the framework only when QM_IsNewBar()==true). The per-tick path
// (Strategy_ManageOpenPosition) is O(1): no history scans, no CopyRates.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10706;
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
input int    qm_friday_close_hour_broker = 21;       // Card: Friday force-close (NY open + 2h approximated by framework hour)

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Monday box / sweep parameters — defaults are the source ("WolfWeb") defaults
// per the strategy card mechanics section.
input int    MondayBoxShiftHours        = 7;        // Logical day-boundary shift for the Monday box (source default 7h).
input double LiqPct                     = 0.0002;   // Min penetration beyond the Monday level for a valid sweep.
input double MaxWickPct                 = 0.0025;   // Max penetration — deeper = real breakout, skip.
input double SlPct                      = 0.0002;   // Stop padding beyond the sweep wick extreme.
input double RrTarget                   = 3.5;      // R:R take-profit multiple.
input double MondayRangeTpPct           = 1.30;     // Monday-range take-profit multiple (130%).
input double BeTriggerR                 = 1.5;      // R multiple that arms the breakeven lock.
input int    BeBars                     = 24;       // Bars-open that also arms the breakeven lock.
input double BeLockFrac                 = 0.1;      // Fraction of initial risk locked at breakeven.
input bool   OneTradePerWeek            = true;     // P2 baseline: at most one trade per week.

// -----------------------------------------------------------------------------
// File-scope strategy state — advanced once per closed bar.
// -----------------------------------------------------------------------------
long     g_week_index      = LONG_MIN;   // Monday-anchored week id of the box currently held.
double   g_monday_high     = 0.0;        // Current week's Monday box high.
double   g_monday_low      = 0.0;        // Current week's Monday box low.
bool     g_monday_tracking = false;      // Have we seen at least one Monday bar this week?
bool     g_monday_valid    = false;      // Is the Monday box usable for sweeps?
long     g_entry_week       = LONG_MIN;  // Week id of the most recent entry (one-trade-per-week guard).

// Breakeven tracker (single position per symbol/magic).
ulong    g_be_ticket   = 0;
double   g_be_entry    = 0.0;
double   g_be_risk     = 0.0;
datetime g_be_opentime = 0;
bool     g_be_done     = false;

// Resolve the logical weekday (0=Sun..6=Sat) and a Monday-anchored week index
// for a bar's open time, applying the configurable day-boundary shift.
void LogicalCalendar(const datetime bar_time, int &weekday, long &week_index)
  {
   const long shift_secs = (long)MondayBoxShiftHours * 3600;
   const datetime logical = (datetime)((long)bar_time - shift_secs);
   MqlDateTime dt;
   TimeToStruct(logical, dt);
   weekday = dt.day_of_week;
   const long day_number = (long)logical / 86400;             // days since 1970-01-01 (a Thursday)
   week_index = (long)MathFloor((double)(day_number - 4) / 7.0); // 1970-01-05 was a Monday
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Entry timing is structural (Monday
// box + sweep), so no per-tick regime gate is needed here.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Advance the Monday-box state on the just-closed bar and fire a sweep-reversal
// entry when the pattern completes. Caller guarantees QM_IsNewBar()==true, so
// the bar reads below run once per closed bar, not per tick.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = 0.0;
   req.tp     = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // perf-allowed: bespoke weekly-range structural logic; closed-bar cadence
   // only (no per-tick history scans, no CopyRates).
   const datetime t1 = iTime(_Symbol, _Period, 1);   // perf-allowed
   if(t1 <= 0)
      return false;

   int  weekday;
   long week_index;
   LogicalCalendar(t1, weekday, week_index);

   // New logical week → reset the Monday box.
   if(week_index != g_week_index)
     {
      g_week_index      = week_index;
      g_monday_high     = 0.0;
      g_monday_low      = 0.0;
      g_monday_tracking = false;
      g_monday_valid    = false;
     }
   // perf-allowed: closed-bar OHLC reads for the Monday box (structural).
   const double h1 = iHigh(_Symbol, _Period, 1);      // perf-allowed
   const double l1 = iLow(_Symbol, _Period, 1);       // perf-allowed
   if(h1 <= 0.0 || l1 <= 0.0)
      return false;

   // Monday: build/extend the box, never trade.
   if(weekday == 1)
     {
      if(!g_monday_tracking)
        {
         g_monday_high     = h1;
         g_monday_low      = l1;
         g_monday_tracking = true;
        }
      else
        {
         if(h1 > g_monday_high) g_monday_high = h1;
         if(l1 < g_monday_low)  g_monday_low  = l1;
        }
      g_monday_valid = true;
      return false;
     }

   // After Monday (Tue..Fri only): hunt for a sweep + reversal.
   if(!g_monday_valid || g_monday_high <= 0.0 || g_monday_low <= 0.0)
      return false;
   if(weekday < 2 || weekday > 5)
      return false;
   if(OneTradePerWeek && g_entry_week == g_week_index)
      return false;

   // Sweep bar = shift 2, confirmation bar = shift 1 (just closed). The sweep
   // must itself be a post-Monday bar in this week.
   const datetime t2 = iTime(_Symbol, _Period, 2);    // perf-allowed
   if(t2 <= 0)
      return false;
   int  wd2;
   long wi2;
   LogicalCalendar(t2, wd2, wi2);
   if(wi2 != g_week_index || wd2 < 2 || wd2 > 5)
      return false;
   // perf-allowed: closed-bar OHLC reads for sweep detection (structural).
   const double h2 = iHigh(_Symbol, _Period, 2);      // perf-allowed
   const double l2 = iLow(_Symbol, _Period, 2);       // perf-allowed
   const double c1 = iClose(_Symbol, _Period, 1);     // perf-allowed
   if(h2 <= 0.0 || l2 <= 0.0 || c1 <= 0.0)
      return false;

   const double range = g_monday_high - g_monday_low;
   if(range <= 0.0)
      return false;

   // Confirmation candle must close back inside the Monday range.
   if(c1 > g_monday_high || c1 < g_monday_low)
      return false;

   // SHORT — failed break above the Monday high.
   const double pen_up = (h2 - g_monday_high) / g_monday_high;
   if(pen_up >= LiqPct && pen_up <= MaxWickPct)
     {
      const double sl   = h2 * (1.0 + SlPct);
      const double risk = sl - c1;
      if(risk > 0.0)
        {
         const double tp_dist = MathMax(RrTarget * risk, MondayRangeTpPct * range);
         req.type   = QM_SELL;
         req.price  = 0.0;            // market
         req.sl     = sl;
         req.tp     = c1 - tp_dist;
         req.reason = "MON_SWEEP_SHORT";
         g_entry_week = g_week_index;
         return true;
        }
     }

   // LONG — failed break below the Monday low.
   const double pen_dn = (g_monday_low - l2) / g_monday_low;
   if(pen_dn >= LiqPct && pen_dn <= MaxWickPct)
     {
      const double sl   = l2 * (1.0 - SlPct);
      const double risk = c1 - sl;
      if(risk > 0.0)
        {
         const double tp_dist = MathMax(RrTarget * risk, MondayRangeTpPct * range);
         req.type   = QM_BUY;
         req.price  = 0.0;            // market
         req.sl     = sl;
         req.tp     = c1 + tp_dist;
         req.reason = "MON_SWEEP_LONG";
         g_entry_week = g_week_index;
         return true;
        }
     }

   return false;
  }

// Per-tick management: arm a locked breakeven once the trade reaches BeTriggerR
// of profit OR has been open for BeBars bars. O(1) — no history scans.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   ulong              ticket     = 0;
   ENUM_POSITION_TYPE ptype      = POSITION_TYPE_BUY;
   double             open_price = 0.0;
   double             sl         = 0.0;
   datetime           opentime   = 0;
   bool               found      = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket     = t;
      ptype      = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl         = PositionGetDouble(POSITION_SL);
      opentime   = (datetime)PositionGetInteger(POSITION_TIME);
      found      = true;
      break;
     }

   if(!found)
     {
      g_be_ticket = 0;   // flat → reset tracker
      return;
     }

   // Capture the original risk once, before any BE move rewrites the stop.
   if(g_be_ticket != ticket)
     {
      g_be_ticket   = ticket;
      g_be_entry    = open_price;
      g_be_risk     = MathAbs(open_price - sl);
      g_be_opentime = opentime;
      g_be_done     = false;
     }

   if(g_be_done || g_be_risk <= 0.0)
      return;

   const bool   is_buy = (ptype == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double moved = is_buy ? (market - g_be_entry) : (g_be_entry - market);
   const double r_now = moved / g_be_risk;

   const int  secs      = PeriodSeconds(_Period);
   const long bars_open = (secs > 0) ? (long)((TimeCurrent() - g_be_opentime) / secs) : 0;

   if(r_now < BeTriggerR && bars_open < BeBars)
      return;

   const double lock   = BeLockFrac * g_be_risk;
   const double new_sl = is_buy ? (g_be_entry + lock) : (g_be_entry - lock);
   const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const bool   improves = is_buy ? (new_sl > sl + point * 0.5)
                                  : (sl <= 0.0 || new_sl < sl - point * 0.5);

   if(improves)
     {
      if(QM_TM_MoveSL(ticket, new_sl, "MON_SWEEP_BE_LOCK"))
         g_be_done = true;
     }
   else
      g_be_done = true; // stop already at/beyond the BE lock
  }

// Exits are handled by SL/TP, the breakeven lock, and the framework Friday
// close — no discretionary exit signal.
bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10706_tv_mon_ls\"}");
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

   // Per-closed-bar: entry-signal evaluation.
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
