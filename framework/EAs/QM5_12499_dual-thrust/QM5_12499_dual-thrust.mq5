#property strict
#property version   "5.0"
#property description "QM5_12499 dual-thrust — Dual Thrust opening-range breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12499 dual-thrust
// -----------------------------------------------------------------------------
// Source: je-suis-tm/quant-trading, "Dual Thrust backtest.py" (public GitHub).
// Card: artifacts/cards_approved/QM5_12499_dual-thrust.md (g0_status APPROVED).
//
// Mechanics:
//   Session window = card's London reference, 03:00-12:00 EST, tracked in
//   broker time (see QM_DUALTHRUST_EST_TO_BROKER_HOURS below).
//   Once per closed bar, while inside the session, the EA accumulates the
//   session's running high/low. When the session ends, (high, low, close) is
//   pushed into a rolling ring buffer of the last `range_days` sessions.
//   At the first bar of a fresh session (once range_days sessions exist):
//     HH = max(session highs), LC = min(session closes)
//     HC = max(session closes), LL = min(session lows)
//     range = max(HH-LC, HC-LL)
//     upper = session_open + param * range
//     lower = session_open - (1-param) * range
//   Entry: live ask > upper -> BUY; live bid < lower -> SELL (one position at
//   a time; only fires while flat, evaluated once per closed bar).
//   Exit: opposite-threshold breach while in a position (checked per tick) or
//   session-end flatten (checked per tick, independent of NoTradeFilter so it
//   always fires).
//   Stop: source has none before session close; V5 adds an ATR(D1) hard stop
//   for platform risk, cached once per session (performance discipline).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12499;
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
input int    strategy_range_days             = 5;    // rg: prior sessions used to build the range
input double strategy_range_param             = 0.5;  // K: upper=open+K*range, lower=open-(1-K)*range
input int    strategy_session_start_hour_est  = 3;    // London session open reference (US Eastern hour)
input int    strategy_session_end_hour_est    = 12;   // London session close/flatten reference (US Eastern hour)
input int    strategy_atr_period              = 14;   // ATR(D1) period for the platform-risk hard stop
input double strategy_atr_stop_mult           = 2.5;  // stop distance = mult * ATR(D1)
input double strategy_spread_pct_of_stop      = 15.0; // block entries only if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached state — advanced ONCE per closed bar / once per session.
// -----------------------------------------------------------------------------
#define QM_DUALTHRUST_MAX_RANGE_DAYS      20
// Darwinex/DXZ NY-Close broker time tracks US DST 1:1 (GMT+2 outside / GMT+3
// inside US DST, per company broker-time convention) -> broker_time =
// US_Eastern_time + 7h, CONSTANT year-round. No separate DST branch needed.
#define QM_DUALTHRUST_EST_TO_BROKER_HOURS 7

double g_hist_high[QM_DUALTHRUST_MAX_RANGE_DAYS];
double g_hist_low[QM_DUALTHRUST_MAX_RANGE_DAYS];
double g_hist_close[QM_DUALTHRUST_MAX_RANGE_DAYS];
int    g_hist_count = 0;
int    g_hist_next  = 0;

bool   g_session_open       = false;  // currently inside today's session window
int    g_session_day_key    = -1;     // QM_CalendarPeriodKey(PERIOD_D1) of the tracked session
double g_session_high       = 0.0;
double g_session_low        = 0.0;

bool   g_thresholds_ready   = false;  // upper/lower armed for the current session
double g_range_upper        = 0.0;
double g_range_lower        = 0.0;
double g_atr_value          = 0.0;    // cached ATR(D1), refreshed once per session
double g_atr_stop_distance  = 0.0;    // cached atr_value * atr_stop_mult

int ClampRangeDays()
  {
   int rd = strategy_range_days;
   if(rd < 1) rd = 1;
   if(rd > QM_DUALTHRUST_MAX_RANGE_DAYS) rd = QM_DUALTHRUST_MAX_RANGE_DAYS;
   return rd;
  }

int SessionStartBrokerHour() { return (strategy_session_start_hour_est + QM_DUALTHRUST_EST_TO_BROKER_HOURS) % 24; }
int SessionEndBrokerHour()   { return (strategy_session_end_hour_est   + QM_DUALTHRUST_EST_TO_BROKER_HOURS) % 24; }

// Rolling range from the last `rd` completed sessions. O(rd), rd<=20.
void ComputeThresholds(const double session_open_price, const int rd)
  {
   double hh = -DBL_MAX, lc = DBL_MAX, hc = -DBL_MAX, ll = DBL_MAX;
   for(int i = 0; i < rd; ++i)
     {
      if(g_hist_high[i]  > hh) hh = g_hist_high[i];
      if(g_hist_close[i] < lc) lc = g_hist_close[i];
      if(g_hist_close[i] > hc) hc = g_hist_close[i];
      if(g_hist_low[i]   < ll) ll = g_hist_low[i];
     }
   const double range1 = hh - lc;
   const double range2 = hc - ll;
   const double range  = MathMax(range1, range2);
   g_range_upper = session_open_price + strategy_range_param * range;
   g_range_lower = session_open_price - (1.0 - strategy_range_param) * range;
  }

void PushSessionHistory(const double h, const double l, const double c)
  {
   const int rd = ClampRangeDays();
   g_hist_high[g_hist_next]  = h;
   g_hist_low[g_hist_next]   = l;
   g_hist_close[g_hist_next] = c;
   g_hist_next = (g_hist_next + 1) % rd;
   if(g_hist_count < rd) g_hist_count++;
  }

// Advance session bookkeeping. Called once per closed bar (caller guarantees
// QM_IsNewBar()==true). Reads only the just-closed bar's OHLC — no CopyRates
// loop, no per-tick recompute.
void UpdateSessionState()
  {
   const datetime broker_now = TimeCurrent();
   const int  day_key    = QM_CalendarPeriodKey(PERIOD_D1, _Symbol);
   const bool in_session  = (QM_Sig_Session(broker_now, SessionStartBrokerHour(), SessionEndBrokerHour()) == 1);

   const double bar_open  = iOpen(_Symbol, PERIOD_CURRENT, 1);  // perf-allowed: bespoke session bookkeeping, once per closed bar
   const double bar_high  = iHigh(_Symbol, PERIOD_CURRENT, 1);  // perf-allowed
   const double bar_low   = iLow(_Symbol, PERIOD_CURRENT, 1);   // perf-allowed
   const double bar_close = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed
   if(bar_open <= 0.0 || bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
      return;

   if(in_session)
     {
      if(!g_session_open || g_session_day_key != day_key)
        {
         // Fresh session start for a new broker-day.
         g_session_open    = true;
         g_session_day_key = day_key;
         g_session_high    = bar_high;
         g_session_low     = bar_low;

         const int rd = ClampRangeDays();
         if(g_hist_count >= rd)
           {
            ComputeThresholds(bar_open, rd);
            g_atr_value         = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
            g_atr_stop_distance = g_atr_value * strategy_atr_stop_mult;
            g_thresholds_ready  = (g_atr_value > 0.0);
           }
         else
           {
            g_thresholds_ready = false;
           }
        }
      else
        {
         if(bar_high > g_session_high) g_session_high = bar_high;
         if(bar_low  < g_session_low)  g_session_low  = bar_low;
        }
     }
   else
     {
      if(g_session_open)
        {
         PushSessionHistory(g_session_high, g_session_low, bar_close);
         g_session_open     = false;
         g_thresholds_ready = false;
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Spread guard only (session gating lives in the entry/management hooks so a
// blocked NoTradeFilter never suppresses the session-end flatten). Fails OPEN
// on .DWX zero modeled spread; only a genuinely wide spread blocks.
bool Strategy_NoTradeFilter()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true; // no valid quote

   const double spread_price = ask - bid;
   if(spread_price > 0.0 && g_atr_stop_distance > 0.0 &&
      spread_price > (strategy_spread_pct_of_stop / 100.0) * g_atr_stop_distance)
      return true; // genuinely wide spread relative to the stop distance

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   UpdateSessionState();

   if(!g_session_open || !g_thresholds_ready)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false; // one position at a time; reversal handled by ExitSignal + next bar

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   QM_OrderType side;
   double entry_price;
   if(ask > g_range_upper)
     {
      side = QM_BUY;
      entry_price = ask;
     }
   else if(bid < g_range_lower)
     {
      side = QM_SELL;
      entry_price = bid;
     }
   else
     {
      return false;
     }

   const double sl = QM_StopATRFromValue(_Symbol, side, entry_price, g_atr_value, strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "dual_thrust_breakout";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;
   return true;
  }

// Session-end flatten. Runs every tick (not gated by NoTradeFilter) so it
// always fires, independent of the spread guard.
void Strategy_ManageOpenPosition()
  {
   const datetime broker_now = TimeCurrent();
   if(QM_Sig_Session(broker_now, SessionStartBrokerHour(), SessionEndBrokerHour()) == 1)
      return; // still inside the session — no forced flatten yet

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

// Opposite-threshold reversal: close now if price breaches the threshold on
// the far side of the current position. Checked every tick for real-time
// (not bar-close-delayed) reversal fidelity.
bool Strategy_ExitSignal()
  {
   if(!g_thresholds_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   bool is_long = false, is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         is_long = true;
      else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         is_short = true;
     }

   if(is_long  && bid < g_range_lower) return true;
   if(is_short && ask > g_range_upper) return true;
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework").
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
