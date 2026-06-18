#property strict
#property version   "5.0"
#property description "QM5_11314 tc-m5-7-london-open-box-breakout — TC-M5 System #7 prev-hour box breakout (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11314 tc-m5-7-london-open-box-breakout
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         5 Min Trading System #7. Card: artifacts/cards_approved/
//         QM5_11314_tc-m5-7-london-open-box-breakout.md (g0_status APPROVED).
//
// Mechanic (card-literal, M5):
//   At the session start (card: 08:00 New York time = 13:00 GMT), build a box
//   from the prior hour's M5 bars (07:00-07:59 NY): box_high = highest high,
//   box_low = lowest low, box_height = box_high - box_low.
//   LONG  trigger: a closed M5 bar CLOSES above box_high + thr * box_height.
//   SHORT trigger: a closed M5 bar CLOSES below box_low  - thr * box_height.
//   Signal valid for the session window only (default 08:00-08:59 NY = 1 hour).
//   Max 1 trade per session.
//   SL  LONG = box_low ; SL SHORT = box_high (bottom/top of the box).
//   TP  LONG = box_high + tp_mult * box_height ; SHORT = box_low - tp_mult * h.
//   Skip the session if box_height > max_box_pips or < min_box_pips.
//   Trailing: once price is 1x box_height in profit, trail the SL by box_height.
//
// .DWX INVARIANTS honoured:
//   * Session window derived from the BAR TIMESTAMP in BROKER time via
//     QM_BrokerToUTC + a configurable NY-vs-UTC offset, US-DST aware
//     (QM_IsUSDSTUTC). No raw-ET/UTC window on a broker-time chart.
//   * Breakout uses the bar CLOSE (the single EVENT), not an intrabar range
//     touch — robust on gapless .DWX CFDs.
//   * Spread guard fails OPEN on .DWX zero-modeled spread (only a genuinely
//     wide spread blocks).
//   * No swap gate, no external-macro CSV.
//   * Box scan is a bounded 12-bar closed-bar read, cached once per session
//     on the new-bar path — no per-tick history scans.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11314;
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
// Session anchored in NY time per the card (08:00 NY = 13:00 GMT). The box is
// the hour immediately PRECEDING session start (07:00-07:59 NY). The NY-vs-UTC
// offset is US-DST driven: EST = UTC-5, EDT = UTC-4. We convert the bar's
// broker time -> UTC -> NY using this offset so the window stays correct across
// the year and across the DXZ broker GMT+2/+3 switch.
input int    strategy_session_start_ny_hour = 8;     // NY hour the box "fires" (card: 08:00 NY)
input int    strategy_box_hours             = 1;     // box = this many hours before session start
input int    strategy_session_window_hours  = 1;     // signal valid for this many hours after start
input double strategy_breakout_threshold    = 0.20;  // breakout = thr * box_height beyond the box
input double strategy_tp_mult               = 4.00;  // TP = tp_mult * box_height beyond the box
input double strategy_max_box_pips          = 80.0;  // skip session if box height > this many pips
input double strategy_min_box_pips          = 5.0;   // skip session if box height < this many pips
input double strategy_trail_activate_mult   = 1.00;  // start trailing once +this * box_height in profit
input double strategy_trail_distance_mult   = 1.00;  // trail SL by this * box_height behind price
input double strategy_spread_pct_of_box     = 25.0;  // skip if spread > this % of box height

// -----------------------------------------------------------------------------
// File-scope cached session/box state (advanced once per closed bar).
// -----------------------------------------------------------------------------
datetime g_box_session_day   = 0;     // NY calendar day (midnight NY) of the active box
bool     g_box_valid         = false; // a tradeable box exists for the current session
double   g_box_high          = 0.0;
double   g_box_low           = 0.0;
double   g_box_height        = 0.0;   // price distance
bool     g_session_traded    = false; // one trade per session latch

// -----------------------------------------------------------------------------
// Helpers (file-scope, non-framework, bespoke session math).
// -----------------------------------------------------------------------------

// NY offset from UTC in hours (negative). EDT = -4 during US DST, EST = -5 else.
int NY_UTCOffsetHours(const datetime utc)
  {
   return QM_IsUSDSTUTC(utc) ? -4 : -5;
  }

// Convert a broker-time stamp to New York wall-clock time.
datetime BrokerToNY(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc + (NY_UTCOffsetHours(utc) * 3600);
  }

// Midnight (00:00) of the NY calendar day containing ny_time.
datetime NYMidnight(const datetime ny_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(ny_time, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

// Rebuild the box for the session whose start hour is on the NY day of ny_now.
// Scans the prior strategy_box_hours of M5 bars (closed bars only). Sets the
// file-scope cache. Called ONCE per session-start bar from AdvanceState.
void BuildBoxForSession(const datetime ny_now)
  {
   g_box_valid      = false;
   g_session_traded = false;
   g_box_high       = 0.0;
   g_box_low        = 0.0;
   g_box_height     = 0.0;

   // The box covers the strategy_box_hours immediately before the session
   // start hour. On M5 that is (12 * box_hours) bars, ending with the bar that
   // closed at session start. The most recently CLOSED bar (shift 1) is the
   // 07:55 NY bar (its close stamps 08:00 NY = session start). Scan shifts
   // 1 .. 12*box_hours for the prior-hour high/low.
   const int box_bars = 12 * strategy_box_hours;
   if(box_bars <= 0)
      return;

   double hi = 0.0;
   double lo = 0.0;
   bool   have = false;
   for(int s = 1; s <= box_bars; ++s)
     {
      // perf-allowed: bounded session-frame structural read (<=12*box_hours
      // bars), executed once per session-start bar on the new-bar path.
      const double bh = iHigh(_Symbol, _Period, s);
      const double bl = iLow(_Symbol, _Period, s);
      if(bh <= 0.0 || bl <= 0.0)
         continue;
      if(!have)
        {
         hi = bh;
         lo = bl;
         have = true;
        }
      else
        {
         if(bh > hi) hi = bh;
         if(bl < lo) lo = bl;
        }
     }
   if(!have)
      return;

   const double height = hi - lo;
   if(height <= 0.0)
      return;

   // Box-height filter in pips (scale-correct via pip distance helper).
   const double max_box_dist = (strategy_max_box_pips > 0.0)
      ? QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_max_box_pips)) : 0.0;
   const double min_box_dist = (strategy_min_box_pips > 0.0)
      ? QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_min_box_pips)) : 0.0;
   if(max_box_dist > 0.0 && height > max_box_dist)
      return; // too wide — skip session
   if(min_box_dist > 0.0 && height < min_box_dist)
      return; // too tight — skip session

   g_box_high   = hi;
   g_box_low    = lo;
   g_box_height = height;
   g_box_valid  = true;
  }

// Advance cached session state. Called ONCE per new closed bar (caller already
// passed QM_IsNewBar()). Detects the session-start bar by the BAR'S broker-time
// timestamp converted to NY, and (re)builds the box on that bar.
void AdvanceState_OnNewBar()
  {
   // Broker time of the bar that just CLOSED (its close == open of bar 0).
   const datetime bar_open_broker = iTime(_Symbol, _Period, 0); // current forming bar's open = last close
   const datetime ny_now          = BrokerToNY(bar_open_broker);

   MqlDateTime nydt;
   ZeroMemory(nydt);
   TimeToStruct(ny_now, nydt);
   const datetime ny_day = NYMidnight(ny_now);

   // Session-start bar: the first M5 bar whose NY open hour == session start
   // hour and minute == 0. That bar's open coincides with the close of the
   // 07:55 NY bar, i.e. the box (07:00-07:59) is complete. Build once per day.
   if(nydt.hour == strategy_session_start_ny_hour && nydt.min == 0 && ny_day != g_box_session_day)
     {
      g_box_session_day = ny_day;
      BuildBoxForSession(ny_now);
     }
  }

// True while the current bar's NY time is inside the signal window.
bool InSessionWindow(const datetime ny_now)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(ny_now, dt);
   const int start_h = strategy_session_start_ny_hour;
   const int end_h   = start_h + strategy_session_window_hours; // exclusive
   return (dt.hour >= start_h && dt.hour < end_h);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard only. Fail-OPEN on .DWX zero spread;
// only a genuinely wide spread (relative to the active box height) blocks.
bool Strategy_NoTradeFilter()
  {
   if(!g_box_valid || g_box_height <= 0.0)
      return false; // no active box reference — defer to the entry gate

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — never block on a missing quote

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_box / 100.0) * g_box_height)
      return true; // genuinely wide spread

   return false;
  }

// Box breakout entry on the CLOSE of a bar. Caller guarantees QM_IsNewBar().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_box_valid || g_box_height <= 0.0)
      return false;
   if(g_session_traded)
      return false; // max one trade per session
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false; // one position per magic

   // Must be inside the NY signal window (derived from the bar timestamp).
   const datetime bar_open_broker = iTime(_Symbol, _Period, 0);
   const datetime ny_now          = BrokerToNY(bar_open_broker);
   if(!InSessionWindow(ny_now))
      return false;

   // The EVENT: the just-CLOSED bar (shift 1) closes beyond the extended box.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double up_level   = g_box_high + strategy_breakout_threshold * g_box_height;
   const double down_level = g_box_low  - strategy_breakout_threshold * g_box_height;

   if(close1 > up_level)
     {
      // LONG: SL at box bottom, TP at box_high + tp_mult * height.
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_box_low);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, g_box_high + strategy_tp_mult * g_box_height);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry)
         return false; // degenerate geometry — skip

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "box_break_long";
      g_session_traded = true;
      return true;
     }

   if(close1 < down_level)
     {
      // SHORT: SL at box top, TP at box_low - tp_mult * height.
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_box_high);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, g_box_low - strategy_tp_mult * g_box_height);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry)
         return false; // degenerate geometry — skip

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "box_break_short";
      g_session_traded = true;
      return true;
     }

   return false;
  }

// Trailing stop by box_height once price is trail_activate_mult * box_height in
// profit. Per-tick, but O(1): reads cached box + current price only.
void Strategy_ManageOpenPosition()
  {
   if(!g_box_valid || g_box_height <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long ptype     = PositionGetInteger(POSITION_TYPE);
      const double open_px  = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl   = PositionGetDouble(POSITION_SL);
      const double activate = strategy_trail_activate_mult * g_box_height;
      const double trail    = strategy_trail_distance_mult * g_box_height;
      if(activate <= 0.0 || trail <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;
         if(bid - open_px < activate)
            continue; // not yet far enough in profit
         const double want_sl = QM_StopRulesNormalizePrice(_Symbol, bid - trail);
         if(want_sl > 0.0 && (cur_sl <= 0.0 || want_sl > cur_sl) && want_sl < bid)
            QM_TM_MoveSL(ticket, want_sl, "box_trail_long");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            continue;
         if(open_px - ask < activate)
            continue;
         const double want_sl = QM_StopRulesNormalizePrice(_Symbol, ask + trail);
         if(want_sl > 0.0 && (cur_sl <= 0.0 || want_sl < cur_sl) && want_sl > ask)
            QM_TM_MoveSL(ticket, want_sl, "box_trail_short");
        }
     }
  }

// No discretionary exit beyond SL/TP and the trailing stop. The signal expires
// naturally because g_session_traded latches and the box is rebuilt next day.
bool Strategy_ExitSignal()
  {
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

   // FIRST on the new-bar path: advance cached session/box state.
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
