#property strict
#property version   "5.0"
#property description "QM5_11346 triad-deadtime-range-scalp — Dead-Time Range Midpoint Mean-Reversion (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11346 triad-deadtime-range-scalp
// -----------------------------------------------------------------------------
// Source: Jason Fielder, "Triad Cheat Sheets", Cheat Sheet #1 Strategy #2 —
//         Dead-Time Range Scalping.
// Card: artifacts/cards_approved/QM5_11346_triad-deadtime-range-scalp.md
//       (g0_status APPROVED).
//
// Mechanics (H1, closed-bar reads only):
//   Dead-time RANGE: the two H1 bars whose bar-open hour (in US-Eastern time,
//     DST-aware) is 15:00 and 16:00 ET — i.e. the 3pm-5pm ET dead-time window,
//     the lowest-liquidity hours. range_high / range_low = max/min of those two
//     CLOSED bars; range_mid = (high + low) / 2.
//   ARM event: the first closed H1 bar whose ET open-hour == 17:00 (5pm ET).
//     At that bar both range bars (15:00, 16:00 ET) are already CLOSED, so the
//     range is read from shift 1 (16:00 bar) and shift 2 (15:00 bar).
//   ACTIVE window: ET 17:00 .. 20:00 bar-open (the 5pm-9pm ET fade window).
//   Entry EVENT (mean-reversion fade toward midpoint), max 1 trade / session:
//     Close[1] < range_mid -> BUY  (fade up toward mid)   TP = range_mid
//     Close[1] > range_mid -> SELL (fade down toward mid)  TP = range_mid
//     SL = fixed sl_pips from entry (card: 12 pips, scale-correct via pips->price).
//   Range filters: skip if width < min_range_pips (degenerate, ~no edge) or
//                  width > max_range_pips (not dead-time — too volatile).
//   Hard session exit: flatten at / past the 21:00-ET (9pm ET) bar regardless.
//
// .DWX INVARIANTS honoured:
//   - Session windows are derived from the bar TIMESTAMP converted to broker
//     time and then ET via QM_BrokerToUTC + QM_IsUSDSTUTC (DST-aware), NEVER a
//     fixed wall-clock or raw-UTC window.
//   - Range is built from prior CLOSED bars (gapless CFDs: open[0]==close[1]).
//   - Spread guard fails OPEN on .DWX zero modeled spread (only a genuinely
//     wide spread blocks).
//   - No swap gate, no external-macro CSV feed.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11346;
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
// Dead-time range window, expressed in US-Eastern (ET) bar-open hours.
// 3pm-5pm ET = the two H1 bars opening at 15:00 and 16:00 ET.
input int    strategy_range_start_et_hour = 15;    // 3pm ET — first range bar open hour
input int    strategy_range_bars          = 2;     // number of H1 bars in the dead-time range
// Active fade window, in ET bar-open hours: 5pm ET (arm) .. 9pm ET (force-exit).
input int    strategy_active_start_et_hour = 17;   // 5pm ET — arm + first fade bar
input int    strategy_active_end_et_hour   = 21;   // 9pm ET — hard session close
// Trade construction.
input int    strategy_sl_pips             = 12;    // fixed stop distance in pips
input int    strategy_min_range_pips      = 5;     // skip degenerate range below this width
input int    strategy_max_range_pips      = 40;    // skip too-volatile range above this width
input double strategy_spread_pct_of_stop  = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached session state (advanced once per new closed bar).
// -----------------------------------------------------------------------------
bool     g_range_ready      = false;   // range computed for the current session
double   g_range_high       = 0.0;
double   g_range_low        = 0.0;
double   g_range_mid        = 0.0;
int      g_session_day      = -1;      // ET calendar day the active range belongs to
bool     g_traded_session   = false;   // 1-trade-per-session latch

// -----------------------------------------------------------------------------
// ET-time helpers (DST-aware via the framework broker<->UTC converters).
// -----------------------------------------------------------------------------

// Convert a broker-time stamp to its US-Eastern wall-clock components.
void ETComponents(const datetime broker_time, int &et_hour, int &et_day)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   // US Eastern = UTC-5 (EST) outside US DST, UTC-4 (EDT) during US DST.
   const int et_offset = QM_IsUSDSTUTC(utc) ? -4 : -5;
   const datetime et   = utc + (et_offset * 3600);
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(et, dt);
   et_hour = dt.hour;
   et_day  = dt.day;
  }

// ET bar-open hour of a closed bar at the given shift.
int BarOpenETHour(const int shift)
  {
   const datetime bar_open = iTime(_Symbol, _Period, shift); // perf-allowed: closed-bar timestamp
   if(bar_open <= 0)
      return -1;
   int et_hour, et_day;
   ETComponents(bar_open, et_hour, et_day);
   return et_hour;
  }

// -----------------------------------------------------------------------------
// AdvanceState_OnNewBar — called ONCE per new closed bar (after QM_IsNewBar()).
// Builds / refreshes the dead-time range at the 5pm-ET arm bar and resets the
// per-session trade latch on a new ET session day. O(1): reads shift 1..N only.
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   // The just-closed bar is shift 1. Its ET open hour drives the state machine.
   const datetime closed_open = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar timestamp
   if(closed_open <= 0)
      return;
   int closed_et_hour, closed_et_day;
   ETComponents(closed_open, closed_et_hour, closed_et_day);

   // New ET session day -> clear the trade latch (range is rebuilt at the arm bar).
   if(closed_et_day != g_session_day)
     {
      g_traded_session = false;
      // Do not clear g_range_ready here; it is (re)set when the arm bar lands.
     }

   // ARM bar: the closed 5pm-ET bar means the 3pm & 4pm ET range bars are now
   // CLOSED. Walk back from shift 1 to find the two consecutive bars whose ET
   // open hours are 16:00 then 15:00 (i.e. the dead-time window). We locate the
   // most recent bar whose ET open hour == range_start (15:00) within a bounded
   // lookback and read the range across strategy_range_bars from there.
   if(closed_et_hour == strategy_active_start_et_hour)
     {
      // Find the shift of the FIRST range bar (ET open hour == range_start).
      // Bounded scan (<= 6 bars) covers the 3pm..5pm span with margin; O(1).
      int start_shift = -1;
      const int max_scan = 6;
      for(int s = 1; s <= max_scan; ++s)
        {
         if(BarOpenETHour(s) == strategy_range_start_et_hour)
           {
            start_shift = s;
            break;
           }
        }

      if(start_shift > 0)
        {
         double rng_high = -DBL_MAX;
         double rng_low  =  DBL_MAX;
         bool   ok       = true;
         for(int k = 0; k < strategy_range_bars; ++k)
           {
            const int sh = start_shift - k; // range bars run forward in time
            if(sh < 1)
              {
               ok = false;
               break;
              }
            const double h = iHigh(_Symbol, _Period, sh); // perf-allowed: closed-bar OHLC
            const double l = iLow(_Symbol, _Period, sh);   // perf-allowed: closed-bar OHLC
            if(h <= 0.0 || l <= 0.0)
              {
               ok = false;
               break;
              }
            if(h > rng_high)
               rng_high = h;
            if(l < rng_low)
               rng_low = l;
           }

         if(ok && rng_high > rng_low)
           {
            g_range_high   = rng_high;
            g_range_low    = rng_low;
            g_range_mid    = (rng_high + rng_low) / 2.0;
            g_range_ready  = true;
            g_session_day  = closed_et_day;
            g_traded_session = false; // fresh session range -> allow one trade
           }
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a zero price

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Dead-time range fade entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic, one trade per session.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_traded_session)
      return false;
   if(!g_range_ready)
      return false;

   // Active fade window: the just-closed bar (shift 1) must open in ET
   // [active_start .. active_end). Outside the window -> no entry.
   const int et_hour = BarOpenETHour(1);
   if(et_hour < 0)
      return false;
   if(et_hour < strategy_active_start_et_hour || et_hour >= strategy_active_end_et_hour)
      return false;

   // Range-width filters (degenerate / too-volatile dead-time range).
   const double width        = g_range_high - g_range_low;
   const double min_width     = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_range_pips);
   const double max_width     = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_range_pips);
   if(width < min_width || width > max_width)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // Fade toward the midpoint.
   QM_OrderType dir;
   if(close1 < g_range_mid)
      dir = QM_BUY;
   else if(close1 > g_range_mid)
      dir = QM_SELL;
   else
      return false; // exactly at mid — no edge

   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // SL = fixed pips from entry (scale-correct). TP = range midpoint.
   const double sl = QM_StopFixedPips(_Symbol, dir, entry, strategy_sl_pips);
   const double tp = QM_StopRulesNormalizePrice(_Symbol, g_range_mid);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "deadtime_fade_long" : "deadtime_fade_short";
   g_traded_session = true; // latch: one trade per session
   return true;
  }

// No active management — fixed SL + midpoint TP. Hard session exit lives in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Hard session close: flatten at / past the 9pm-ET (active_end) bar regardless.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int et_hour = BarOpenETHour(1);
   if(et_hour < 0)
      return false;

   // Outside the active fade window (>= 9pm ET, or before 5pm ET next session)
   // -> force-close. The fade window is 17:00..21:00 ET; anything at or after
   // the end hour, or wrapped past midnight before the next arm, is stale.
   const bool inside = (et_hour >= strategy_active_start_et_hour &&
                        et_hour <  strategy_active_end_et_hour);
   return !inside;
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

   // FIRST on a new closed bar: advance the cached dead-time-range state.
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
