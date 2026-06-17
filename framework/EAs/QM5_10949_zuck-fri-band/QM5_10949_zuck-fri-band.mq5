#property strict
#property version   "5.0"
#property description "QM5_10949 zuck-fri-band — Friday morning-range continuation breakout (long-only, M15)"

#include <QM/QM_Common.mqh>
#include <QM/QM_DSTAware.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10949 zuck-fri-band
// -----------------------------------------------------------------------------
// Source: Gregory Zuckerman, "The Man Who Solved the Market" (2019), ISBN
//   9780735217980 — Friday morning trading bands had predictive ability for
//   later-Friday bands near the close.
// Card: artifacts/cards_approved/QM5_10949_zuck-fri-band.md (g0_status APPROVED).
//
// Mechanics (long-only, M15, closed-bar reads at shift >= 1):
//   Day gate     : trade only on Friday (broker time).
//   Morning frame: a per-Friday window [start, end) in BROKER time. The card
//                  states the window in NY time (09:30-12:00) for index CFDs and
//                  08:00-11:00 BROKER time for commodities. DXZ broker = NY+7h
//                  (UTC+2/+3 vs NY UTC-5/-4), so NY 09:30->broker 16:30 and
//                  NY 12:00->broker 19:00. Defaults below are the index broker
//                  window; commodity symbols override via the setfile to 8/11.
//   Morning range: high/low over the in-window M15 bars; morning return =
//                  (close of last in-window bar) - (open of first in-window bar).
//   Vol filter   : skip if morning range width < min_range_atr_mult * ATR(14,H1).
//   Trigger      : AFTER the window closes (still Friday, before the exit time),
//                  on a closed M15 bar, if morning_return > return_atr_mult *
//                  ATR(14,M15) AND that bar's close breaks above morning_high -> BUY.
//   Stop         : entry - atr_stop_mult * ATR(14,M15).
//   Exit         : Friday session-close proxy — flatten at/after exit_hour_broker
//                  (default 20:30 broker, i.e. exit_hour=20, exit_min=30). The
//                  framework Friday-close guard (qm_friday_close_hour_broker=21)
//                  is a hard backstop one hour later.
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_atr % of
//                  ATR(14,M15) (fail-open on .DWX zero modeled spread).
//
// One open position per symbol/magic. Long-only (card baseline). Intraday state
// (morning frame) is recomputed once per closed M15 bar and cached file-scope;
// per-tick path only reads cached values + Bid/Ask.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10949;
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
// Morning window in BROKER time. Index default = NY 09:30-12:00 -> broker
// 16:30-19:00. Commodity setfiles override to 8/0 .. 11/0 (broker time).
input int    strategy_window_start_hour   = 16;    // morning window start hour (broker)
input int    strategy_window_start_min    = 30;    // morning window start minute (broker)
input int    strategy_window_end_hour     = 19;    // morning window end hour (broker, exclusive)
input int    strategy_window_end_min      = 0;     // morning window end minute (broker, exclusive)
// Friday flatten time (broker). Card: no later than 20:30 broker.
input int    strategy_exit_hour_broker    = 20;    // flatten at/after this broker hour
input int    strategy_exit_min_broker     = 30;    // ... and this minute
input double strategy_return_atr_mult     = 0.35;  // morning return must exceed mult * ATR(14,M15)
input double strategy_min_range_atr_mult  = 0.50;  // skip if morning range width < mult * ATR(14,H1)
input int    strategy_atr_period          = 14;    // ATR period (M15 trigger/stop and H1 range floor)
input double strategy_atr_stop_mult       = 1.0;   // stop distance = mult * ATR(14,M15)
input double strategy_spread_pct_of_atr   = 15.0;  // skip if spread > this % of ATR(14,M15)

// -----------------------------------------------------------------------------
// File-scope cached morning-frame state (advanced once per closed M15 bar).
// Rebuilt for the CURRENT Friday only; reset on any non-Friday / new day.
// -----------------------------------------------------------------------------
bool     g_frame_valid     = false;   // morning frame computed for the current Friday
bool     g_window_closed   = false;   // the morning window has fully closed
int      g_frame_doy       = -1;      // day-of-year the frame belongs to (reset guard)
int      g_frame_year      = -1;
double   g_morning_high    = 0.0;
double   g_morning_low     = 0.0;
double   g_morning_open    = 0.0;     // open of first in-window bar
double   g_morning_close   = 0.0;     // close of last in-window bar
double   g_morning_return  = 0.0;     // morning_close - morning_open

// Returns minutes-of-day for a broker datetime.
int FrameMinutesOfDay(const datetime broker_t)
  {
   MqlDateTime dt;
   TimeToStruct(broker_t, dt);
   return dt.hour * 60 + dt.min;
  }

// True if the given broker bar-open time falls inside the morning window.
bool FrameBarInWindow(const datetime broker_bar_open)
  {
   const int mod    = FrameMinutesOfDay(broker_bar_open);
   const int wstart = strategy_window_start_hour * 60 + strategy_window_start_min;
   const int wend   = strategy_window_end_hour   * 60 + strategy_window_end_min;
   return (mod >= wstart && mod < wend);
  }

// Rebuild the morning frame for the current Friday by scanning the in-window
// M15 bars. Bounded scan (~one trading window of M15 bars). Called once per
// closed M15 bar via AdvanceFrame_OnNewBar — never on the per-tick path.
void RebuildMorningFrame()
  {
   g_frame_valid    = false;
   g_window_closed  = false;
   g_morning_high   = 0.0;
   g_morning_low    = 0.0;
   g_morning_open   = 0.0;
   g_morning_close  = 0.0;
   g_morning_return = 0.0;

   const int wend_min = strategy_window_end_hour * 60 + strategy_window_end_min;

   // Walk closed bars from shift 1 backwards. Collect those whose bar-open
   // broker time is in the window AND on the same calendar day as bar shift 1.
   // Bound the scan so a missing window cannot loop unboundedly.
   datetime ref_open = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar timestamp
   if(ref_open <= 0)
      return;
   MqlDateTime ref_dt;
   TimeToStruct(ref_open, ref_dt);

   bool   have_first = false; // first (earliest) in-window bar found
   bool   have_last  = false; // last (latest)  in-window bar found
   double hi = 0.0, lo = 0.0;
   const int max_scan = 200; // ~ one trading day of M15 bars, ample bound

   for(int s = 1; s <= max_scan; ++s)
     {
      const datetime bo = iTime(_Symbol, _Period, s); // perf-allowed: closed-bar timestamp
      if(bo <= 0)
         break;
      MqlDateTime bdt;
      TimeToStruct(bo, bdt);
      // Stop once we cross to a previous calendar day.
      if(bdt.day != ref_dt.day || bdt.mon != ref_dt.mon || bdt.year != ref_dt.year)
         break;
      if(!FrameBarInWindow(bo))
         continue;

      const double bh = iHigh(_Symbol, _Period, s);   // perf-allowed: closed-bar OHLC
      const double bl = iLow(_Symbol, _Period, s);    // perf-allowed: closed-bar OHLC
      const double bc = iClose(_Symbol, _Period, s);  // perf-allowed: closed-bar OHLC
      const double boo = iOpen(_Symbol, _Period, s);  // perf-allowed: closed-bar OHLC
      if(bh <= 0.0 || bl <= 0.0)
         continue;

      if(!have_first)
        {
         hi = bh;
         lo = bl;
        }
      else
        {
         hi = MathMax(hi, bh);
         lo = MathMin(lo, bl);
        }

      // We iterate s ascending (most recent -> oldest). The FIRST in-window
      // match is the latest bar (window close); the LAST match is the earliest
      // bar (window open). g_morning_open keeps overwriting so it ends on the
      // earliest in-window bar.
      if(!have_last)
        {
         g_morning_close = bc;
         have_last = true;
        }
      g_morning_open = boo;
      have_first = true;
     }

   if(!have_first)
      return; // no in-window bars yet (window not reached today)

   g_morning_high = hi;
   g_morning_low  = lo;

   // The window is "closed" once the reference closed bar's open time is at or
   // beyond the window end. While bar shift 1 is still inside the window we keep
   // accumulating but do not yet allow a breakout entry.
   const int ref_min = FrameMinutesOfDay(ref_open);
   g_window_closed = (ref_min >= wend_min);

   g_morning_return = g_morning_close - g_morning_open;
   g_frame_valid = true;
  }

// Advance cached intraday state. Called once per closed M15 bar (after the
// framework QM_IsNewBar gate). Resets the frame on non-Friday / day rollover.
void AdvanceFrame_OnNewBar()
  {
   const datetime bar_open = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar timestamp
   if(bar_open <= 0)
      return;
   MqlDateTime dt;
   TimeToStruct(bar_open, dt);

   // Friday only. day_of_week: 0=Sun..6=Sat -> Friday == 5.
   if(dt.day_of_week != 5)
     {
      g_frame_valid   = false;
      g_window_closed = false;
      g_frame_doy     = -1;
      g_frame_year    = -1;
      return;
     }

   // Same-day cache key (day-of-month + month is unique within a wake).
   const int doy = dt.mon * 100 + dt.day;
   if(doy != g_frame_doy || dt.year != g_frame_year)
     {
      g_frame_doy  = doy;
      g_frame_year = dt.year;
     }

   RebuildMorningFrame();
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread).
// Session/Friday/frame logic lives on the closed-bar path.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_m15 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_m15 <= 0.0)
      return false; // defer to entry gate; never block on missing ATR

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_atr / 100.0) * atr_m15)
      return true;

   return false;
  }

// Long-only Friday morning-range continuation breakout.
// Caller guarantees QM_IsNewBar() == true (closed M15 bar). Reads cached frame.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Must have a valid, CLOSED morning frame for the current Friday.
   if(!g_frame_valid || !g_window_closed)
      return false;
   if(g_morning_high <= 0.0)
      return false;

   const datetime bar_open = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar timestamp
   if(bar_open <= 0)
      return false;
   MqlDateTime bdt;
   TimeToStruct(bar_open, bdt);

   // Still Friday, and strictly before the flatten time (no fresh entry once we
   // are at/after the exit window — the position would be closed immediately).
   if(bdt.day_of_week != 5)
      return false;
   const int now_min  = bdt.hour * 60 + bdt.min;
   const int exit_min = strategy_exit_hour_broker * 60 + strategy_exit_min_broker;
   if(now_min >= exit_min)
      return false;

   // Volatility floor — morning range width vs ATR(14,H1).
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr_h1 <= 0.0)
      return false;
   const double range_width = g_morning_high - g_morning_low;
   if(range_width < strategy_min_range_atr_mult * atr_h1)
      return false;

   // Morning-return strength vs ATR(14,M15).
   const double atr_m15 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_m15 <= 0.0)
      return false;
   if(!(g_morning_return > strategy_return_atr_mult * atr_m15))
      return false;

   // Breakout: the just-closed bar broke above the morning high.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   if(close1 <= 0.0)
      return false;
   if(!(close1 > g_morning_high))
      return false;

   // Build the long entry. Framework sizes lots (no lots field).
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_m15, strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP — time exit + ATR stop only (per card)
   req.reason = "zuck_fri_band_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop. Time exit is in
// Strategy_ExitSignal; the framework Friday-close guard is a hard backstop.
void Strategy_ManageOpenPosition()
  {
  }

// Time exit: flatten at/after the Friday session-close proxy (exit_hour_broker).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);

   // Outside Friday: close (defensive — should already be flat). On Friday,
   // close once we reach/exceed the flatten time.
   if(dt.day_of_week != 5)
      return true;

   const int now_min  = dt.hour * 60 + dt.min;
   const int exit_min = strategy_exit_hour_broker * 60 + strategy_exit_min_broker;
   return (now_min >= exit_min);
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

   // FIRST on the closed-bar path: advance cached intraday (morning-frame) state.
   AdvanceFrame_OnNewBar();

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
