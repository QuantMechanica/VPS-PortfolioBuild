#property strict
#property version   "5.0"
#property description "QM5_11369 london-asian-range-breakout-m15 — Asian-range / London-breakout (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11369 london-asian-range-breakout-m15
// -----------------------------------------------------------------------------
// Source: "London Free Breakfast Forex Trading Strategy" (Anonymous).
// Card: artifacts/cards_approved/QM5_11369_london-asian-range-breakout-m15.md
//       (g0_status APPROVED).
//
// Mechanics (M15, closed-bar reads at shift 1; sessions in BROKER time):
//   Box the Asian session: Asian_High / Asian_Low from the prior CLOSED M15
//   bars whose broker-time hour falls in [22:00 .. 07:00) (GMT+2 std / GMT+3
//   DST — DXZ NY-Close). At London open (07:00 broker) watch the M15 close.
//   The single EVENT is the FIRST M15 bar that CLOSES strictly beyond the box:
//     LONG  : close[1] > Asian_High  -> BUY  at next open.
//     SHORT : close[1] < Asian_Low   -> SELL at next open.
//   A wick/poke that does not close beyond the box is ignored. Only the first
//   clean breakout per day is taken (whipsaw re-entry suppressed).
//   SL : Low[1] (LONG) / High[1] (SHORT) of the breakout bar. If the resulting
//        stop distance exceeds strategy_sl_cap_pips, the trade is SKIPPED.
//   TP : strategy_tp_pips from entry (fixed).
//   Time exit: close any remaining position at/after 12:00 broker time.
//   Monday is skipped (weekend gap distorts the Asian range).
//   Spread guard fails OPEN on .DWX zero modeled spread.
//
// .DWX invariants honoured: broker-time sessions keyed off the closed bar's
// OPEN timestamp (iTime shift 1, invariant #12); prior CLOSE used for the
// breakout EVENT (gapless CFD, invariant #6); spread guard fails open
// (invariant #1); pip-scaled SL/TP via QM_StopRulesPipsToPriceDistance
// (invariant #14); QM_IsNewBar consumed once by the framework (invariant #3).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11369;
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
input int    strategy_asian_start_hour  = 22;     // Asian range start, broker hour (inclusive)
input int    strategy_asian_end_hour    = 7;      // Asian range end = London open, broker hour (exclusive)
input int    strategy_london_close_hour = 12;     // time-stop: flat at/after this broker hour
input double strategy_tp_pips           = 40.0;   // fixed take-profit, pips
input double strategy_sl_cap_pips       = 25.0;   // skip if breakout-bar SL distance exceeds this
input bool   strategy_skip_monday       = true;   // skip Monday (weekend gap distorts Asian range)
input double strategy_spread_cap_pips   = 20.0;   // skip only a genuinely wide spread (fail-open on 0)

// -----------------------------------------------------------------------------
// File-scope cached state — advanced once per closed bar (see AdvanceState).
// -----------------------------------------------------------------------------
double   g_asian_high       = 0.0;     // current session Asian-box high
double   g_asian_low        = 0.0;     // current session Asian-box low
bool     g_asian_valid      = false;   // box computed for the active London day
int      g_box_day          = -1;      // day-of-year the active box belongs to
bool     g_breakout_done    = false;   // first breakout already taken this day
int      g_breakout_day     = -1;      // day-of-year the breakout flag belongs to

// Broker-time helpers ---------------------------------------------------------
// In the tester, bar timestamps and TimeCurrent() are already in broker (server)
// time, which is DXZ NY-Close GMT+2/+3. The card's session windows are stated in
// that same broker time, so we compare broker hours directly. DST-awareness is
// intrinsic: the broker clock itself shifts, so a fixed broker-hour window tracks
// the real session across the US-DST boundary. QM_BrokerToUTC is available if a
// UTC anchor is ever needed; here the broker-hour comparison is the correct frame.
int BrokerHour(const datetime broker_t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_t, dt);
   return dt.hour;
  }

int BrokerDayOfYear(const datetime broker_t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_t, dt);
   return dt.day_of_year;
  }

int BrokerDayOfWeek(const datetime broker_t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_t, dt);
   return dt.day_of_week; // Sun=0 .. Sat=6
  }

// True if a broker hour lies inside the Asian window [start .. end) with wrap
// (22:00 -> 07:00 crosses midnight).
bool InAsianWindow(const int hour)
  {
   const int s = strategy_asian_start_hour;
   const int e = strategy_asian_end_hour;
   if(s == e)
      return false;
   if(s < e)
      return (hour >= s && hour < e);   // non-wrapping window
   return (hour >= s || hour < e);      // wraps midnight
  }

// -----------------------------------------------------------------------------
// AdvanceState_OnNewBar — runs ONCE per closed M15 bar (framework new-bar gate).
// Rebuilds the Asian box when the bar that just closed is the FIRST London-open
// bar of the day (broker hour == asian_end_hour), by scanning back over the
// prior CLOSED bars that fall in the Asian window. Caches max-high / min-low.
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   const datetime t1 = iTime(_Symbol, _Period, 1); // open time of the just-closed bar
   if(t1 <= 0)
      return;

   const int hour1 = BrokerHour(t1);
   const int doy1  = BrokerDayOfYear(t1);

   // Reset the per-day breakout latch on a new broker day.
   if(doy1 != g_breakout_day)
     {
      g_breakout_done = false;
      g_breakout_day  = doy1;
     }

   // Rebuild the box exactly once: when the just-closed bar is the first bar
   // of the London session (its broker hour equals the Asian window end).
   if(hour1 == strategy_asian_end_hour && doy1 != g_box_day)
     {
      double hi = 0.0;
      double lo = 0.0;
      bool   found = false;

      // Walk back over closed bars (shift 2..N) collecting the contiguous
      // Asian-window block that immediately precedes this London open. Stop
      // once we leave the Asian window after having entered it (one session).
      const int max_scan = 200; // ~ one Asian session of M15 bars + margin
      bool entered = false;
      for(int s = 2; s <= max_scan; ++s)
        {
         const datetime ts = iTime(_Symbol, _Period, s);
         if(ts <= 0)
            break;
         const int hs = BrokerHour(ts);
         if(InAsianWindow(hs))
           {
            entered = true;
            const double bh = iHigh(_Symbol, _Period, s); // perf-allowed: bounded once/day box build
            const double bl = iLow(_Symbol, _Period, s);
            if(bh <= 0.0 || bl <= 0.0)
               continue;
            if(!found)
              {
               hi = bh; lo = bl; found = true;
              }
            else
              {
               if(bh > hi) hi = bh;
               if(bl < lo) lo = bl;
              }
           }
         else if(entered)
           {
            break; // left the Asian block — session boundary reached
           }
        }

      if(found && hi > lo)
        {
         g_asian_high = hi;
         g_asian_low  = lo;
         g_asian_valid = true;
         g_box_day = doy1;
        }
      else
        {
         g_asian_valid = false;
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/session logic is on the
// closed-bar entry path. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// First clean London breakout of the day. Caller guarantees QM_IsNewBar()==true
// and AdvanceState_OnNewBar() has already run for this closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_asian_valid)
      return false;
   if(g_breakout_done)
      return false; // only the first breakout per day

   const datetime t1 = iTime(_Symbol, _Period, 1); // breakout-candidate = just-closed bar
   if(t1 <= 0)
      return false;

   // Must be the London session: at/after London open, before the time stop.
   const int hour1 = BrokerHour(t1);
   if(hour1 < strategy_asian_end_hour || hour1 >= strategy_london_close_hour)
      return false;

   // Skip Monday (weekend gap distorts the Asian range).
   if(strategy_skip_monday && BrokerDayOfWeek(t1) == 1) // Mon=1
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);
   const double low1   = iLow(_Symbol, _Period, 1);
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double sl_cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
   const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_pips);
   if(sl_cap <= 0.0 || tp_dist <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // LONG: first M15 CLOSE strictly above the box.
   if(close1 > g_asian_high)
     {
      const double entry = ask;
      const double sl    = low1;                 // SL = breakout-bar low
      const double sl_distance = entry - sl;
      if(sl_distance <= 0.0 || sl_distance > sl_cap)
        {
         g_breakout_done = true;                 // first breakout consumed (whipsaw guard) even if skipped
         return false;
        }
      req.type   = QM_BUY;
      req.price  = 0.0;                          // framework fills market price at send
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, entry + tp_dist);
      req.reason = "london_breakout_long";
      g_breakout_done = true;
      return true;
     }

   // SHORT: first M15 CLOSE strictly below the box.
   if(close1 < g_asian_low)
     {
      const double entry = bid;
      const double sl    = high1;                // SL = breakout-bar high
      const double sl_distance = sl - entry;
      if(sl_distance <= 0.0 || sl_distance > sl_cap)
        {
         g_breakout_done = true;
         return false;
        }
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, entry - tp_dist);
      req.reason = "london_breakout_short";
      g_breakout_done = true;
      return true;
     }

   return false;
  }

// Fixed SL/TP handle the position; no active trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Time stop: close any open position at/after the London-close broker hour
// (TP not yet hit). Keyed off the current broker time.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int hour_now = BrokerHour(TimeCurrent());
   return (hour_now >= strategy_london_close_hour);
  }

// Defer to the central news filter (card: avoid major UK/US news near London open).
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

   // Advance cached Asian-box state once per closed bar BEFORE the entry gate.
   AdvanceState_OnNewBar();

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
