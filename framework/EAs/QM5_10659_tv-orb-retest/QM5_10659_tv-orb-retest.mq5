#property strict
#property version   "5.0"
#property description "QM5_10659 tv-orb-retest — Opening-Range Breakout with retest-limit entry"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10659 TradingView OR Breakout Retest
// -----------------------------------------------------------------------------
// Mechanics (from APPROVED card QM5_10659_tv-orb-retest):
//   * Build an opening range (OR) from the first N bars after a configurable
//     session start. OR high / OR low define the range.
//   * Only the FIRST breakout of the day is eligible.
//   * Long  : a bar BODY closes above OR high (wick-only does not qualify),
//             then place a BUY-LIMIT at the OR high (zone boundary) for the
//             retest. Enter only if the retest fills before expiry.
//   * Short : a bar BODY closes below OR low, then a SELL-LIMIT at OR low.
//   * Cancel the unfilled pending order after `RetestExpiryBars` closed bars.
//   * Stop  : long  = low  of last BULLISH bar inside the OR.
//             short = high of last BEARISH bar inside the OR.
//             If no qualifying in-zone bar exists, skip the trade.
//   * Max-SL filter (pips/points); skip if exceeded.
//   * OR-size filter: min / max OR width.
//   * TP = configured RRR * stop distance (symmetric default 2.0R).
//   * Force flat at session close; no new orders after the cutoff.
//
// Single-entry framework path: the framework sizes lots (QM_LotsForRisk) and
// owns OnTick wiring. This file only implements the 5 Strategy_* hooks plus
// closed-bar-cached OR state.
//
// Broker-time discipline (.DWX NY-Close, UTC+2 / UTC+3 in US DST):
//   The session window is expressed in EXCHANGE clock minutes-from-midnight.
//   For US indices the cash open 09:30 ET == broker 16:30 — and the ET->broker
//   offset is a CONSTANT +7h year-round (broker=UTC+2/ET=UTC-5 off-DST;
//   broker=UTC+3/ET=UTC-4 in DST -> +7h both). For non-US sessions set
//   SessionClockMode=SESSION_CLOCK_BROKER and give the window directly in
//   broker time. The OR is therefore always built in BROKER time, matched to
//   the symbol — never a raw ET/UTC window on a broker-time chart.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10659;
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

// -----------------------------------------------------------------------------
// Strategy inputs (all card parameters surfaced here)
// -----------------------------------------------------------------------------
input group "Strategy — Session / Opening Range"
// Clock interpretation for the session window below.
//   SESSION_CLOCK_US_ET : window is in US-exchange ET; converted to broker via
//                         the constant +7h ET->broker offset (US indices).
//   SESSION_CLOCK_BROKER: window is already in broker time (FX / DAX / metals).
enum SessionClockMode { SESSION_CLOCK_US_ET = 0, SESSION_CLOCK_BROKER = 1 };
input SessionClockMode SessionClockMode_  = SESSION_CLOCK_US_ET;
// Session start, in the clock selected above (hours + minutes since midnight).
input int    SessionStartHour            = 9;     // 09:30 ET default = US cash open
input int    SessionStartMin             = 30;
// No NEW orders after this cutoff (same clock). Existing orders/positions kept
// until SessionEnd.
input int    NoNewOrderHour              = 15;    // 15:30 ET
input int    NoNewOrderMin               = 30;
// Force flat (close position + cancel pending) at/after session end.
input int    SessionEndHour              = 15;    // 15:55 ET (a few min before US close)
input int    SessionEndMin               = 55;
// Number of bars after session start that form the opening range.
input int    ORBars                      = 6;     // 6 x M5 = first 30 min

input group "Strategy — Breakout / Retest"
// Cancel the unfilled retest limit after this many closed bars.
input int    RetestExpiryBars            = 6;
input bool   AllowLong                   = true;
input bool   AllowShort                  = true;

input group "Strategy — Stops / Targets / Filters"
input double RewardRRLong                 = 2.0;   // TP = RR * stop distance (long)
input double RewardRRShort                = 2.0;   // TP = RR * stop distance (short)
input int    MaxStopPips                  = 0;     // 0 = disabled; else skip if SL pips > this
input int    MinORWidthPips               = 0;     // 0 = disabled; min OR width filter
input int    MaxORWidthPips               = 0;     // 0 = disabled; max OR width filter

// -----------------------------------------------------------------------------
// File-scope cached strategy state (advanced once per closed bar).
// -----------------------------------------------------------------------------
// Day key (broker-time YYYYMMDD) the current state belongs to.
int      g_day_key            = -1;
// OR construction progress.
bool     g_or_built           = false;   // OR finalised for today
double   g_or_high            = 0.0;
double   g_or_low             = 0.0;
// Stop seeds harvested while building the OR.
double   g_last_bull_low      = 0.0;     // low of last bullish in-zone bar (long stop)
bool     g_have_bull          = false;
double   g_last_bear_high     = 0.0;     // high of last bearish in-zone bar (short stop)
bool     g_have_bear          = false;
// One-shot-per-day breakout / order bookkeeping.
bool     g_breakout_used      = false;   // first breakout of the day already taken
bool     g_pending_active     = false;   // a retest limit is live (not yet filled)
ulong    g_pending_ticket     = 0;
int      g_pending_age_bars   = 0;       // closed bars since the limit was placed
int      g_pending_dir        = 0;       // +1 long, -1 short
double   g_pending_sl         = 0.0;
double   g_pending_tp         = 0.0;
// Cached "current broker minute-of-day" + day, refreshed each new bar.
int      g_now_min_of_day     = 0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Broker-time minute-of-day for a configured (hour,min) in the selected clock.
// US-ET windows are shifted +7h into broker time (constant year-round on the
// DXZ NY-Close server). Broker-clock windows pass through unchanged. Result is
// wrapped into [0,1440) minutes.
int SessionMinuteOfDayBroker(const int hour, const int min)
  {
   int total = hour * 60 + min;
   if(SessionClockMode_ == SESSION_CLOCK_US_ET)
      total += 7 * 60;            // ET -> broker constant offset
   total = ((total % 1440) + 1440) % 1440;
   return total;
  }

int BrokerMinuteOfDay(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour * 60 + dt.min;
  }

int BrokerDayKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

// Reset all per-day cached state when the broker day rolls.
void ResetDayState(const int day_key)
  {
   g_day_key          = day_key;
   g_or_built         = false;
   g_or_high          = 0.0;
   g_or_low           = 0.0;
   g_last_bull_low    = 0.0;
   g_have_bull        = false;
   g_last_bear_high   = 0.0;
   g_have_bear        = false;
   g_breakout_used    = false;
   // NOTE: a live pending order from a prior day is force-cancelled at session
   // end; if one somehow survives the roll we drop our tracking so the new day
   // starts clean (the order, if any, will expire by its broker expiration).
   g_pending_active   = false;
   g_pending_ticket   = 0;
   g_pending_age_bars = 0;
   g_pending_dir      = 0;
   g_pending_sl       = 0.0;
   g_pending_tp       = 0.0;
  }

// Whether our magic currently holds an open position on this symbol.
bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

// Does the tracked pending order still exist as a live pending order?
bool PendingOrderStillLive()
  {
   if(g_pending_ticket == 0)
      return false;
   return OrderSelect(g_pending_ticket);   // true only while still pending
  }

// -----------------------------------------------------------------------------
// Closed-bar state machine — runs ONCE per new closed bar (called from the
// entry hook on the framework's single QM_IsNewBar consume). Reads ONLY closed
// bars (shift>=1). No per-tick history scans.
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar(const datetime bar_open_broker)
  {
   const int day_key = BrokerDayKey(bar_open_broker);
   if(day_key != g_day_key)
      ResetDayState(day_key);

   g_now_min_of_day = BrokerMinuteOfDay(bar_open_broker);

   const int sess_start = SessionMinuteOfDayBroker(SessionStartHour, SessionStartMin);

   // Closed bar we are reacting to is shift 1 (just closed). Its open time:
   const datetime closed_open = iTime(_Symbol, _Period, 1);
   if(closed_open <= 0)
      return;
   const int closed_min = BrokerMinuteOfDay(closed_open);
   const int closed_day = BrokerDayKey(closed_open);
   if(closed_day != g_day_key)
      return;   // closed bar belongs to a different day; wait

   // --- Build the opening range from the first ORBars bars at/after start. ---
   if(!g_or_built)
     {
      // Only consume bars inside the OR window: [start, start + ORBars*tf).
      if(closed_min < sess_start)
         return;   // pre-session bar — ignore
      // Bars elapsed since session start (each bar = _Period minutes).
      const int tf_min = PeriodSeconds(_Period) / 60;
      if(tf_min <= 0)
         return;
      const int idx = (closed_min - sess_start) / tf_min;   // 0-based bar index
      if(idx < 0)
         return;
      if(idx < ORBars)
        {
         const double bo = iOpen(_Symbol, _Period, 1);
         const double bh = iHigh(_Symbol, _Period, 1);
         const double bl = iLow(_Symbol, _Period, 1);
         const double bc = iClose(_Symbol, _Period, 1);
         if(bh <= 0.0 || bl <= 0.0)
            return;
         if(!g_have_bull && !g_have_bear && idx == 0)
           {
            g_or_high = bh;
            g_or_low  = bl;
           }
         else
           {
            if(bh > g_or_high) g_or_high = bh;
            if(bl < g_or_low || g_or_low <= 0.0) g_or_low = bl;
           }
         // Track stop seeds: last bullish / bearish in-zone bar.
         if(bc > bo) { g_last_bull_low = bl;  g_have_bull = true; }
         if(bc < bo) { g_last_bear_high = bh; g_have_bear = true; }
        }
      // Finalise once we've seen the last OR bar (idx == ORBars-1) or rolled past.
      if(idx >= ORBars - 1)
         g_or_built = (g_or_high > 0.0 && g_or_low > 0.0 && g_or_high > g_or_low);
      return;
     }

   // --- Age / expire a live retest pending order. ---
   if(g_pending_active)
     {
      if(!PendingOrderStillLive())
        {
         // Filled or already gone — stop tracking; position management/SL/TP
         // and the framework take over. Mark breakout consumed for the day.
         g_pending_active = false;
         g_pending_ticket = 0;
         g_breakout_used  = true;
         return;
        }
      g_pending_age_bars++;
      if(g_pending_age_bars >= RetestExpiryBars)
        {
         QM_TM_RemovePendingOrder(g_pending_ticket, "orb_retest_expiry");
         g_pending_active = false;
         g_pending_ticket = 0;
         g_breakout_used  = true;   // first breakout consumed even if it expired
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Block trading outside the active session, or once the day's breakout chance
// is spent. Cheap O(1) checks only (reads cached minute-of-day).
bool Strategy_NoTradeFilter()
  {
   const int sess_start = SessionMinuteOfDayBroker(SessionStartHour, SessionStartMin);
   const int sess_end   = SessionMinuteOfDayBroker(SessionEndHour,  SessionEndMin);
   // Outside [start, end): no entries (management/flat handled elsewhere).
   if(g_now_min_of_day < sess_start || g_now_min_of_day >= sess_end)
      return true;
   return false;
  }

// Populate `req` and return TRUE to place a NEW retest LIMIT order on this
// closed bar. The framework guarantees QM_IsNewBar()==true before calling.
// We FIRST advance closed-bar state here (single new-bar consume), then test
// the first-breakout condition.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime bar_open_broker = iTime(_Symbol, _Period, 0);
   AdvanceState_OnNewBar(bar_open_broker);

   if(!g_or_built)              return false;
   if(g_breakout_used)         return false;   // only first breakout of the day
   if(g_pending_active)        return false;   // a retest order is already live
   if(HasOpenPosition())       return false;   // single position per symbol/magic

   // No new orders after the cutoff.
   const int no_new = SessionMinuteOfDayBroker(NoNewOrderHour, NoNewOrderMin);
   if(g_now_min_of_day >= no_new)
      return false;

   // OR-width filter.
   const double or_width = g_or_high - g_or_low;
   if(or_width <= 0.0)
      return false;
   if(MinORWidthPips > 0)
     {
      const double min_w = QM_StopRulesPipsToPriceDistance(_Symbol, MinORWidthPips);
      if(min_w > 0.0 && or_width < min_w)
         return false;
     }
   if(MaxORWidthPips > 0)
     {
      const double max_w = QM_StopRulesPipsToPriceDistance(_Symbol, MaxORWidthPips);
      if(max_w > 0.0 && or_width > max_w)
         return false;
     }

   // Body of the just-closed bar (shift 1).
   const double bo = iOpen(_Symbol, _Period, 1);
   const double bc = iClose(_Symbol, _Period, 1);
   if(bo <= 0.0 || bc <= 0.0)
      return false;

   int dir = 0;
   if(AllowLong && bc > g_or_high && bc > bo)        // bullish BODY closes above OR high
      dir = +1;
   else if(AllowShort && bc < g_or_low && bc < bo)   // bearish BODY closes below OR low
      dir = -1;
   if(dir == 0)
      return false;

   // Stop from the last qualifying in-zone bar; skip if none exists.
   double sl_price = 0.0;
   double entry    = 0.0;     // retest limit sits at the zone boundary
   QM_OrderType otype;
   if(dir == +1)
     {
      if(!g_have_bull) return false;          // no bullish in-zone bar -> skip
      entry    = g_or_high;
      sl_price = g_last_bull_low;
      otype    = QM_BUY_LIMIT;
      if(sl_price <= 0.0 || sl_price >= entry) return false;
     }
   else
     {
      if(!g_have_bear) return false;          // no bearish in-zone bar -> skip
      entry    = g_or_low;
      sl_price = g_last_bear_high;
      otype    = QM_SELL_LIMIT;
      if(sl_price <= 0.0 || sl_price <= entry) return false;
     }

   // Max-SL filter (pips). Compare SL distance to the configured cap.
   if(MaxStopPips > 0)
     {
      const double max_sl = QM_StopRulesPipsToPriceDistance(_Symbol, MaxStopPips);
      if(max_sl > 0.0 && MathAbs(entry - sl_price) > max_sl)
         return false;
     }

   // TP = RR * stop distance.
   const double rr = (dir == +1) ? RewardRRLong : RewardRRShort;
   const double tp_price = QM_TakeRR(_Symbol, (dir == +1 ? QM_BUY : QM_SELL),
                                     entry, sl_price, rr);
   if(tp_price <= 0.0)
      return false;

   // Expire the limit after RetestExpiryBars bars (broker-side safety net in
   // addition to our bar-count cancel in AdvanceState).
   const int tf_sec = PeriodSeconds(_Period);
   int expiry_sec = tf_sec * RetestExpiryBars;
   if(expiry_sec <= 0) expiry_sec = 0;

   req.type               = otype;
   req.price              = QM_StopRulesNormalizePrice(_Symbol, entry);
   req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl_price);
   req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp_price);
   req.reason             = (dir == +1) ? "orb_retest_long" : "orb_retest_short";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = expiry_sec;

   // Latch our intent so the next-bar state machine can age/cancel the order.
   // out_ticket is captured in Strategy via a follow-up read of the live order;
   // because the framework opens the order right after this returns true, we
   // re-discover the ticket in AdvanceState via PendingOrderStillLive. To keep
   // the ticket, we mark the pending intent and resolve the ticket lazily.
   g_pending_active   = true;
   g_pending_age_bars = 0;
   g_pending_dir      = dir;
   g_pending_sl       = req.sl;
   g_pending_tp       = req.tp;
   // Ticket is resolved post-open in Strategy_ManageOpenPosition / next bar.
   g_pending_ticket   = 0;
   return true;
  }

// Per-tick. Resolves the just-placed pending-order ticket (so the next closed
// bar can age it) and is otherwise a no-op — SL/TP ride on the order itself.
void Strategy_ManageOpenPosition()
  {
   if(!g_pending_active || g_pending_ticket != 0)
      return;
   // Find our most recent live pending order for this symbol+magic and latch it.
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT)
        {
         g_pending_ticket = ticket;
         break;
        }
     }
  }

// Force flat at/after session end: close any open position. (Pending-order
// cancellation at session end is handled in Strategy_NoTradeFilter window +
// the broker expiration; we also cancel here for completeness.)
bool Strategy_ExitSignal()
  {
   const int sess_end = SessionMinuteOfDayBroker(SessionEndHour, SessionEndMin);
   if(g_now_min_of_day < sess_end)
      return false;

   // Cancel any live retest pending order at session end.
   if(g_pending_active && PendingOrderStillLive())
     {
      QM_TM_RemovePendingOrder(g_pending_ticket, "orb_session_end_flat");
      g_pending_active = false;
      g_pending_ticket = 0;
      g_breakout_used  = true;
     }
   // Signal the framework to close the open position (if any).
   return HasOpenPosition();
  }

// Defer to the central two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
     {
      // Still allow management / forced flat outside the entry window.
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
      return;
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
      if(out_ticket > 0)
         g_pending_ticket = out_ticket;
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
