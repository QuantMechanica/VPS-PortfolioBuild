#property strict
#property version   "5.0"
#property description "QM5_11582 goodwin-asian-session-breakout-usdjpy-h1 — session-range breakout + prior-D1-color filter (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11582 goodwin-asian-session-breakout-usdjpy-h1
// -----------------------------------------------------------------------------
// Source: Jarrod Goodwin, "Beat the Markets Strategy Guidebook"
//         (thetransparenttrader.com, ~2020), Strategy 3.
// Card: artifacts/cards_approved/QM5_11582_goodwin-asian-session-breakout-usdjpy-h1.md
//       (g0_status APPROVED).
//
// Mechanics (USDJPY primary; H1) — implemented LITERALLY from the card body:
//   The session opens 17:00 EST and the market builds a range over the first
//   4.5 hours. At 21:30 EST a stop order is armed at the session high (if the
//   prior D1 bar was bullish) or at the session low (if the prior D1 bar was
//   bearish). The prior-D1-bar color filter aligns the trade with the day's
//   direction. Exit is EOD at 16:50 EST. Fixed 150-pip stop, no take-profit.
//   One trade per side per session; reset daily via the session anchor.
//
//   NOTE (card title vs body): the card slug/title says "Asian Session" but its
//   mechanical body specifies the 17:00-21:30 EST window (NY-session evening,
//   which overlaps the Tokyo/Asian session open). We implement the body's
//   literal time window per HR9 (most-literal reading); all windows are
//   parameterised so the operator can retune to a pure Tokyo window if desired.
//
// EST -> broker mapping: DXZ broker uses the NY-Close convention (GMT+2 outside
//   US DST, GMT+3 during US DST). Both EST/EDT and the broker clock shift with
//   US DST together, so the EST->broker hour offset is CONSTANT year-round
//   (+6h here). We therefore operate directly on the BROKER clock (TimeCurrent)
//   using broker-hour inputs, which is inherently DST-correct. Defaults
//   (broker, GMT+2 reference):
//     session open      17:00 EST -> 23:00 broker
//     accumulation end  21:30 EST -> 03:30 broker  (order armed)
//     EOD exit          16:50 EST -> 22:50 broker
//
// STATE   : the session high/low accumulated across the open->accum-end window.
// EVENT   : the single break of that session extreme, in the prior-bar-color
//           direction, after the window has closed. Latched once per session so
//           we never re-fire and never trigger two crosses on the same tick.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11582;
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
// Session window + order/exit timing, all in BROKER time (minutes since midnight).
// Defaults map EST -> broker at the GMT+2 reference (DST-constant offset, see header).
input int    strategy_session_open_min    = 23 * 60 + 0;   // 23:00 broker (17:00 EST)
input int    strategy_accum_end_min       = 3 * 60 + 30;   // 03:30 broker (21:30 EST) — order armed
input int    strategy_eod_exit_min        = 22 * 60 + 50;  // 22:50 broker (16:50 EST) — EOD exit
input bool   strategy_use_prior_bar_filter = true;         // require prior-D1-bar color alignment
input double strategy_sl_pips             = 150.0;         // fixed stop, in pips
input double strategy_spread_cap_pips     = 20.0;          // skip a genuinely wide spread only

// -----------------------------------------------------------------------------
// File-scope session state. Advanced once per closed H1 bar.
//   The window wraps midnight (open 23:00 -> accum-end 03:30 next day), so we
//   anchor each session by its OPEN datetime and reset cleanly when a new
//   session opens.
// -----------------------------------------------------------------------------
datetime g_session_anchor   = 0;     // broker datetime of the current session open
double   g_session_high     = 0.0;   // accumulated session high (STATE)
double   g_session_low      = 0.0;   // accumulated session low  (STATE)
bool     g_window_open      = false; // currently inside the accumulation window
bool     g_armed            = false; // accumulation closed, breakout level locked
bool     g_fired            = false; // breakout already taken this session (EVENT latch)
int      g_dir              = 0;     // +1 long (prior bull), -1 short (prior bear), 0 none
double   g_break_level      = 0.0;   // locked session extreme to break

// Minutes since broker midnight for a broker datetime.
int BrokerMinuteOfDay(const datetime t)
  {
   MqlDateTime st;
   TimeToStruct(t, st);
   return st.hour * 60 + st.min;
  }

// True if `m` lies inside the wrap-safe window [start, end) in minute-of-day.
bool InWrapWindow(const int m, const int start, const int end)
  {
   if(start == end)
      return false;
   if(start < end)
      return (m >= start && m < end);
   // wraps midnight
   return (m >= start || m < end);
  }

// -----------------------------------------------------------------------------
// Closed-bar session-state advance. Called ONCE per new H1 bar (post new-bar
// gate). Reads only the last closed bar; advances the range by one step.
// -----------------------------------------------------------------------------
void AdvanceSession_OnNewBar()
  {
   // Last closed bar (shift 1) — perf-allowed single-bar reads for session range.
   const datetime t1   = iTime(_Symbol, _Period, 1);   // perf-allowed
   const double   hi1  = iHigh(_Symbol, _Period, 1);   // perf-allowed
   const double   lo1  = iLow(_Symbol, _Period, 1);    // perf-allowed
   if(t1 == 0 || hi1 <= 0.0 || lo1 <= 0.0)
      return;

   const int mod = BrokerMinuteOfDay(t1);
   const bool in_accum = InWrapWindow(mod, strategy_session_open_min, strategy_accum_end_min);

   // --- New session start: the just-closed bar is the first accumulation bar. ---
   if(in_accum && !g_window_open)
     {
      g_session_anchor = t1;
      g_session_high   = hi1;
      g_session_low    = lo1;
      g_window_open    = true;
      g_armed          = false;
      g_fired          = false;
      g_dir            = 0;
      g_break_level    = 0.0;
      return;
     }

   // --- Inside the window: accumulate the range. ---
   if(in_accum && g_window_open)
     {
      if(hi1 > g_session_high) g_session_high = hi1;
      if(lo1 < g_session_low)  g_session_low  = lo1;
      return;
     }

   // --- Window just closed: lock the breakout level + prior-bar direction. ---
   if(!in_accum && g_window_open)
     {
      g_window_open = false;

      // Prior D1 bar color (closed daily bar, shift 1).
      const double d1_open  = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed
      const double d1_close = iClose(_Symbol, PERIOD_D1, 1);  // perf-allowed
      int dir = 0;
      if(d1_close > d1_open)      dir = +1;   // bullish -> break the high (long)
      else if(d1_close < d1_open) dir = -1;   // bearish -> break the low (short)

      if(!strategy_use_prior_bar_filter)
        {
         // Filter off: still need a side; fall back to prior-bar color but treat
         // a doji as long-bias so a tradable side always exists.
         if(dir == 0) dir = +1;
        }

      if(dir == +1)
        {
         g_dir         = +1;
         g_break_level = g_session_high;
         g_armed       = (g_session_high > 0.0);
        }
      else if(dir == -1)
        {
         g_dir         = -1;
         g_break_level = g_session_low;
         g_armed       = (g_session_low > 0.0);
        }
      else
        {
         g_dir   = 0;
         g_armed = false; // doji prior bar with filter on -> no trade this session
        }
      return;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(ask > bid && cap > 0.0 && (ask - bid) > cap)
      return true;

   return false;
  }

// Breakout entry. Caller invokes this every tick (the high/low can be pierced
// intrabar). The session range is STATE (already accumulated). The break of the
// locked extreme is the single EVENT — latched via g_fired so it never re-fires
// and never produces two crosses on one tick.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Must be armed (window closed, level + direction locked) and not yet fired.
   if(!g_armed || g_fired || g_dir == 0 || g_break_level <= 0.0)
      return false;

   // Only consider the breakout AFTER the accumulation window has closed and
   // BEFORE the EOD exit time — i.e. the active trading leg of the session.
   const int mod_now = BrokerMinuteOfDay(TimeCurrent());
   const bool in_trade_leg = InWrapWindow(mod_now, strategy_accum_end_min, strategy_eod_exit_min);
   if(!in_trade_leg)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_dir == +1)
     {
      // Long breakout: price trades through the session high (stop-order fill).
      if(ask < g_break_level)
         return false;
      const double entry = ask;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)strategy_sl_pips);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no TP — EOD/stop exit only
      req.reason = "goodwin_asian_session_break_long";
      g_fired    = true;  // latch the EVENT
      return true;
     }

   if(g_dir == -1)
     {
      // Short breakout: price trades through the session low (stop-order fill).
      if(bid > g_break_level)
         return false;
      const double entry = bid;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, (int)strategy_sl_pips);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "goodwin_asian_session_break_short";
      g_fired    = true;
      return true;
     }

   return false;
  }

// No active management — fixed stop + EOD time exit only.
void Strategy_ManageOpenPosition()
  {
  }

// EOD time exit: close any open position once we leave the active trade leg —
// i.e. at/after the EOD exit minute (broker).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int mod_now = BrokerMinuteOfDay(TimeCurrent());
   // The trade leg runs [accum_end, eod_exit). Once we leave that window, it is
   // EOD (or beyond) -> flatten.
   const bool in_trade_leg = InWrapWindow(mod_now, strategy_accum_end_min, strategy_eod_exit_min);
   return !in_trade_leg;
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

   // Time-based exit (EOD) — evaluated every tick, independent of new bars.
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

   // Advance session state once per closed bar (single new-bar consume).
   if(QM_IsNewBar())
     {
      QM_EquityStreamOnNewBar();
      AdvanceSession_OnNewBar();
     }

   // Breakout EVENT must be checked intrabar (the high/low can be pierced mid-
   // bar), so the entry gate runs every tick — but only fires once per session
   // via the g_fired latch and the one-position guard.
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
