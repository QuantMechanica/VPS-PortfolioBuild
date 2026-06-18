#property strict
#property version   "5.0"
#property description "QM5_11446 burke-3day-rectangle-breakout-m5 — 3-day D1 rectangle, M5 EMA breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11446 burke-3day-rectangle-breakout-m5
// -----------------------------------------------------------------------------
// Source: Stacey Burke Trading Playbook (3-Day Rectangle Consolidation Breakout).
// Card: artifacts/cards_approved/QM5_11446_burke-3day-rectangle-breakout-m5.md
//       (g0_status APPROVED, source 04305b6c-b4ce-522b-87b5-71708b6b8327).
//
// Mechanics:
//   D1 PATTERN (refreshed once per new closed D1 bar = start of "Day 4"):
//     Bar A = D1 shift 3 defines rect_high = High[D1,3], rect_low = Low[D1,3].
//     Bar B = D1 shift 2 and Bar C = D1 shift 1 are each fully contained:
//       High[D1,k] <= rect_high AND Low[D1,k] >= rect_low  for k in {1,2}.
//     Height filter: min_pips <= (rect_high - rect_low) <= max_pips.
//     These are bespoke multi-day OHLC reads from PRIOR CLOSED daily bars; on
//     gapless .DWX CFDs the rectangle is built from CLOSED-bar extremes, never
//     from an intraday gap. Cached on file scope, advanced one step per new D1.
//
//   M5 ENTRY (Day 4 breakout — single closed-M5-bar EVENT):
//     LONG : Close[M5,1] > rect_high  AND  Close[M5,1] > EMA20[M5,1]
//     SHORT: Close[M5,1] < rect_low   AND  Close[M5,1] < EMA20[M5,1]
//     Only inside the broker-time session window (London + NY). One trade per
//     rectangle: a per-day latch prevents re-entry on every breakout bar; the
//     one-position-per-magic guard is the second line of defence.
//
//   STOP (back inside the rectangle = invalidation):
//     LONG : rect_high - sl_buffer_pips     SHORT: rect_low + sl_buffer_pips
//     Capped at sl_cap_pips and floored at (rect_high-rect_low)*sl_floor_frac.
//   TAKE (measured move = projected rectangle height):
//     LONG : entry + (rect_high - rect_low)  SHORT: entry - (rect_high - rect_low)
//
// .DWX invariants honoured: fail-OPEN spread guard (zero modeled spread passes),
// no swap gate, broker-time session via the M5 bar timestamp (DST-aware), prior
// CLOSED daily bars (gapless-safe), no external feed. Only the 5 Strategy_* hooks
// + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11446;
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
input int    strategy_rect_bars         = 3;      // D1 bars forming the rectangle (Bar A + 2 contained)
input int    strategy_ema_period        = 20;     // M5 EMA confirmation period
input int    strategy_height_min_pips   = 20;     // rectangle height floor (pips)
input int    strategy_height_max_pips   = 100;    // rectangle height ceiling (pips)
input int    strategy_sl_buffer_pips    = 5;      // stop placed this far back inside the rectangle
input int    strategy_sl_cap_pips       = 50;     // absolute stop-distance cap (pips)
input double strategy_sl_floor_frac     = 0.5;    // stop distance >= this fraction of rectangle height
input int    strategy_session_start_hr  = 9;      // session window start (broker-time hour, London open)
input int    strategy_session_end_hr    = 22;     // session window end   (broker-time hour, NY close)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached D1 rectangle state (advanced ONCE per new closed D1 bar).
// -----------------------------------------------------------------------------
double g_rect_high      = 0.0;   // rectangle top    (price)
double g_rect_low       = 0.0;   // rectangle bottom (price)
bool   g_rect_valid     = false; // pattern + height filter satisfied for the current day
bool   g_traded_today   = false; // one-trade-per-rectangle latch, reset each new D1

// Refresh the rectangle from the three prior CLOSED daily bars. Called once per
// new D1 bar (start of "Day 4"). Bespoke multi-day structural OHLC — perf-allowed.
void AdvanceRectangle_OnNewDay()
  {
   g_rect_valid   = false;
   g_traded_today = false;
   g_rect_high    = 0.0;
   g_rect_low     = 0.0;

   const double rect_high = iHigh(_Symbol, PERIOD_D1, strategy_rect_bars); // perf-allowed: Bar A high
   const double rect_low  = iLow(_Symbol, PERIOD_D1, strategy_rect_bars);  // perf-allowed: Bar A low
   if(rect_high <= 0.0 || rect_low <= 0.0 || rect_high <= rect_low)
      return;

   // Bars 1..(strategy_rect_bars-1) must each be contained within Bar A's range.
   for(int s = 1; s < strategy_rect_bars; ++s)
     {
      const double hi = iHigh(_Symbol, PERIOD_D1, s); // perf-allowed: containment check
      const double lo = iLow(_Symbol, PERIOD_D1, s);  // perf-allowed: containment check
      if(hi <= 0.0 || lo <= 0.0)
         return;
      if(hi > rect_high || lo < rect_low)
         return; // not contained -> no rectangle this day
     }

   // Height filter (scale-correct pips -> price distance).
   const double height       = rect_high - rect_low;
   const double min_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_height_min_pips);
   const double max_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_height_max_pips);
   if(min_distance > 0.0 && height < min_distance)
      return;
   if(max_distance > 0.0 && height > max_distance)
      return;

   g_rect_high  = rect_high;
   g_rect_low   = rect_low;
   g_rect_valid = true;
  }

// Build the stop price back inside the rectangle, respecting cap + floor.
double BuildStop(const QM_OrderType side, const double level, const double height)
  {
   double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   const double cap   = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   const double floor = height * strategy_sl_floor_frac;

   // Distance from the breakout level back to the stop.
   double distance = buffer;
   if(floor > 0.0 && distance < floor)
      distance = floor;     // ensure stop is at least floor_frac of the height away
   if(cap > 0.0 && distance > cap)
      distance = cap;       // never risk more than the cap
   if(distance <= 0.0)
      return 0.0;

   double stop = (side == QM_BUY) ? (level - distance) : (level + distance);
   return QM_StopRulesNormalizePrice(_Symbol, stop);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: broker-time session window + fail-open spread guard.
bool Strategy_NoTradeFilter()
  {
   // --- Session window in BROKER time (London open through NY close). ---
   // The chart runs on broker time; gate on the broker-time hour of "now".
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_now, dt);
   const int hr = dt.hour;
   if(strategy_session_start_hr <= strategy_session_end_hr)
     {
      if(hr < strategy_session_start_hr || hr >= strategy_session_end_hr)
         return true; // outside the contiguous window
     }
   else
     {
      // Wrap-around window (e.g. start 22, end 6).
      if(hr < strategy_session_start_hr && hr >= strategy_session_end_hr)
         return true;
     }

   // --- Fail-OPEN spread guard: only a genuinely wide spread blocks. ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — do not block on it

   if(g_rect_valid)
     {
      const double height = g_rect_high - g_rect_low;
      const double stop_distance = MathMax(QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips),
                                           height * strategy_sl_floor_frac);
      const double spread = ask - bid;
      if(stop_distance > 0.0 && spread > 0.0 &&
         spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
         return true; // genuinely wide spread
     }

   return false;
  }

// Breakout entry. Caller guarantees QM_IsNewBar() == true on the M5 chart.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_rect_valid || g_traded_today)
      return false;

   // Closed M5 bar (shift 1) breakout close + EMA20 confirmation.
   const double close1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: single closed-bar breakout close
   if(close1 <= 0.0)
      return false;
   const double ema = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   const double height = g_rect_high - g_rect_low;
   if(height <= 0.0)
      return false;

   QM_OrderType side;
   double level;
   if(close1 > g_rect_high && close1 > ema)
     {
      side  = QM_BUY;
      level = g_rect_high;
     }
   else if(close1 < g_rect_low && close1 < ema)
     {
      side  = QM_SELL;
      level = g_rect_low;
     }
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = BuildStop(side, level, height);
   if(sl <= 0.0)
      return false;

   // Measured move: project the rectangle height from the entry.
   const double tp = (side == QM_BUY) ? QM_StopRulesNormalizePrice(_Symbol, entry + height)
                                      : QM_StopRulesNormalizePrice(_Symbol, entry - height);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "burke_rect_break_long" : "burke_rect_break_short";

   g_traded_today = true; // latch: one trade per rectangle / day
   return true;
  }

// Fixed stop/target only; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP.
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

   // Advance the D1 rectangle cache once per new closed daily bar (start of Day 4).
   if(QM_IsNewBar(_Symbol, PERIOD_D1))
      AdvanceRectangle_OnNewDay();

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
