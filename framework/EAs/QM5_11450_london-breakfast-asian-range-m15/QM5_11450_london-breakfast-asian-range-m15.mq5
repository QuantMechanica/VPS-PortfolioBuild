#property strict
#property version   "5.0"
#property description "QM5_11450 london-breakfast — Asian-range breakout at London open (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11450 london-breakfast-asian-range-m15
// -----------------------------------------------------------------------------
// Source: "London Free Breakfast Forex Trading Strategy" (Anonymous).
// Card: artifacts/cards_approved/QM5_11450_london-breakfast-asian-range-m15.md
//       (g0_status APPROVED).
//
// Mechanics (M15, closed-bar reads at shift 1):
//   Asian range  : High/Low of the prior Asian session (card: 00:00-08:00 GMT),
//                  built ONLY from CLOSED bars whose BAR-OPEN broker-time hour is
//                  in [asian_start_h, asian_end_h). Re-derived once per calendar
//                  day and cached.
//   Trigger EVENT: the single just-closed M15 bar's CLOSE breaks the Asian range
//                  while the bar opened inside the London entry window
//                  [london_start_h, london_end_h):
//                    close[1] > asian_high  -> BUY
//                    close[1] < asian_low   -> SELL
//                  First confirmed breakout direction per day only; no flip.
//   Stop         : back INSIDE the Asian range by sl_inside_pips
//                  (long: asian_high - sl_inside_pips ; short: asian_low + ...),
//                  total stop distance capped at sl_cap_pips.
//   Take profit  : entry +/- tp_pips (fixed pip distance, scale-correct).
//   Management   : once trail_trigger_pips in profit, ratchet SL to
//                  entry -/+ trail_offset_pips (card "breakeven+ trail":
//                  10 pips below entry for a long).
//   Time stop    : close the open position at/after time_stop_h broker
//                  (card: 10:00 GMT) if TP not reached.
//
// Session windows in BROKER time (DXZ NY-Close, GMT+2 winter / GMT+3 summer).
// The card states windows in GMT and gives the GMT+2 broker mapping
// (00:00-08:00 GMT == 02:00-10:00 broker). Windows are read straight off the bar
// TIMESTAMP (iTime broker time), never wall-clock. P3 sweeps the exact hours and
// DST handling; the +1h summer shift is absorbed by the setfile params.
//
//   Default broker-hour mapping (GMT+2 winter, from the card):
//     Asian   GMT 00:00-08:00  -> broker 02:00-10:00  (asian_start=2, end=10)
//     London  GMT 08:00-09:00  -> broker 10:00-11:00  (entry window; card abandons
//                                  entries after 09:00 GMT)  (london_start=10, end=11)
//     Time-stop GMT 10:00      -> broker 12:00  (time_stop_h=12)
//
// .DWX invariants honoured:
//   * Session windows evaluated in BROKER time off the bar timestamp.
//   * Asian range built from prior CLOSED bars (shift >= 1).
//   * Spread guard fails OPEN on the .DWX zero modeled spread.
//   * No swap gate, no external-macro CSV, no wall-clock.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11450;
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
// Session windows are in BROKER time (DXZ NY-Close, GMT+2 winter / GMT+3 summer).
input int    strategy_asian_start_h     = 2;     // Asian session start hour (broker)  [GMT 00:00]
input int    strategy_asian_end_h       = 10;    // Asian session end hour (broker, excl) [GMT 08:00]
input int    strategy_london_start_h    = 10;    // London entry window start (broker)  [GMT 08:00]
input int    strategy_london_end_h      = 11;    // London entry window end (broker, excl) [GMT 09:00]
input int    strategy_time_stop_h       = 12;    // close open trade at/after this broker hour [GMT 10:00]
input int    strategy_tp_pips           = 40;    // fixed take-profit distance (pips)
input int    strategy_sl_inside_pips    = 10;    // stop placed this many pips back inside the Asian range
input int    strategy_sl_cap_pips       = 30;    // max stop distance (pips); capped per card P2 cap
input int    strategy_min_range_pips    = 15;    // skip if Asian range narrower than this (likely data gap)
input int    strategy_max_range_pips    = 80;    // skip if Asian range wider than this (likely Asia news)
input int    strategy_trail_trigger_pips = 20;   // once this many pips in profit, ratchet SL
input int    strategy_trail_offset_pips  = 10;   // SL ratcheted to entry -/+ this many pips ("breakeven+")
input double strategy_spread_cap_pips   = 15.0;  // skip only a genuinely wide spread (fail-open on zero spread)

// -----------------------------------------------------------------------------
// File-scope cached Asian-range state (advanced once per calendar day).
// -----------------------------------------------------------------------------
double   g_asian_high      = 0.0;
double   g_asian_low       = 0.0;
bool     g_asian_valid     = false;
int      g_asian_day_key   = -1;   // yyyy*10000+mm*100+dd of the day the range belongs to
int      g_traded_day_key  = -1;   // last calendar day on which we already opened a trade

// Calendar-day key from a broker-time datetime (date only).
int DayKeyFromBrokerTime(const datetime broker_t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

// Rebuild the Asian range for the calendar day of `ref_day_key`, scanning only
// CLOSED bars (shift >= 1) whose bar-open broker hour is in [asian_start, asian_end).
// Called at most once per new calendar day, inside the QM_IsNewBar gate.
// Applies the min/max range filter; on reject leaves g_asian_valid = false.
void RebuildAsianRange_OnNewDay(const int ref_day_key)
  {
   g_asian_valid = false;
   g_asian_high  = 0.0;
   g_asian_low   = 0.0;

   double hi = 0.0;
   double lo = 0.0;
   bool   any = false;

   // Bound the scan: M15 over an 8h Asian window is ~32 bars; scan a generous
   // closed-bar window and pick the ones that match today's Asian session.
   const int max_scan = 200; // ~50h of M15 closed bars — bounded, runs once/day
   for(int s = 1; s <= max_scan; ++s)
     {
      const datetime bt = iTime(_Symbol, _Period, s); // perf-allowed: bar-open timestamp
      if(bt <= 0)
         break;

      const int dk = DayKeyFromBrokerTime(bt);
      if(dk != ref_day_key)
        {
         // Bars are ordered newest->oldest; once we have collected this day's
         // session and walk into an earlier day, stop.
         if(any && dk < ref_day_key)
            break;
         continue;
        }

      MqlDateTime dt;
      ZeroMemory(dt);
      TimeToStruct(bt, dt);
      if(dt.hour < strategy_asian_start_h || dt.hour >= strategy_asian_end_h)
         continue;

      const double bh = iHigh(_Symbol, _Period, s); // perf-allowed: closed-bar extreme
      const double bl = iLow(_Symbol, _Period, s);  // perf-allowed: closed-bar extreme
      if(bh <= 0.0 || bl <= 0.0)
         continue;

      if(!any)
        {
         hi = bh;
         lo = bl;
         any = true;
        }
      else
        {
         if(bh > hi) hi = bh;
         if(bl < lo) lo = bl;
        }
     }

   if(!any)
      return;

   // Range filter: skip degenerate (data-gap) and oversized (Asia-news) ranges.
   const double range    = hi - lo;
   const double min_range = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_range_pips);
   const double max_range = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_range_pips);
   if(min_range > 0.0 && range < min_range)
      return;
   if(max_range > 0.0 && range > max_range)
      return;

   g_asian_high = hi;
   g_asian_low  = lo;
   g_asian_valid = true;
   g_asian_day_key = ref_day_key;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(cap > 0.0 && ask > bid && spread > cap)
      return true;

   return false;
  }

// Asian-range breakout entry. Caller guarantees QM_IsNewBar() == true; the
// just-closed bar is shift 1. The breakout CLOSE is the single EVENT.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed bar under test (shift 1) and its broker-time stamp ---
   const datetime bar_open_bt = iTime(_Symbol, _Period, 1); // perf-allowed: bar-open timestamp
   if(bar_open_bt <= 0)
      return false;

   const int today_key = DayKeyFromBrokerTime(bar_open_bt);

   // --- Advance the Asian range once per calendar day ---
   if(!g_asian_valid || g_asian_day_key != today_key)
      RebuildAsianRange_OnNewDay(today_key);
   if(!g_asian_valid || g_asian_day_key != today_key)
      return false; // no valid range for today yet (session not finished / filtered out)

   // --- One trade per calendar day, first confirmed direction only ---
   if(g_traded_day_key == today_key)
      return false;

   // --- London entry window check (broker time, from the bar timestamp) ---
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(bar_open_bt, dt);
   if(dt.hour < strategy_london_start_h || dt.hour >= strategy_london_end_h)
      return false;

   // --- Breakout EVENT: the just-closed bar's CLOSE breaks the Asian range ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   QM_OrderType side;
   if(close1 > g_asian_high)
      side = QM_BUY;
   else if(close1 < g_asian_low)
      side = QM_SELL;
   else
      return false; // no breakout this bar

   // --- Entry price (market) ---
   const double entry = (side == QM_BUY)
                          ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop: back INSIDE the Asian range (breakout failed), capped ---
   const double inside_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_inside_pips);
   const double cap_dist    = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);

   double sl_raw;
   if(side == QM_BUY)
     {
      sl_raw = g_asian_high - inside_dist;            // back inside the range
      if(cap_dist > 0.0 && (entry - sl_raw) > cap_dist)
         sl_raw = entry - cap_dist;                   // cap stop distance
     }
   else
     {
      sl_raw = g_asian_low + inside_dist;
      if(cap_dist > 0.0 && (sl_raw - entry) > cap_dist)
         sl_raw = entry + cap_dist;
     }
   const double sl = QM_StopRulesNormalizePrice(_Symbol, sl_raw);

   // Guard against a non-positive stop distance (e.g. close ran far beyond range).
   if((side == QM_BUY && sl >= entry) || (side == QM_SELL && sl <= entry))
      return false;

   // --- Take profit: fixed pip distance on the profit side ---
   const double tp = QM_StopFixedPips(_Symbol,
                                      (side == QM_BUY) ? QM_SELL : QM_BUY,
                                      entry, strategy_tp_pips);
   // QM_StopFixedPips with the opposite side yields a price on the profit side:
   //   long  (opposite=SELL) -> entry + distance (above) = TP.
   //   short (opposite=BUY ) -> entry - distance (below) = TP.
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "lbf_asian_break_long" : "lbf_asian_break_short";

   // Latch: one trade per calendar day, first confirmed direction only.
   g_traded_day_key = today_key;
   return true;
  }

// "Breakeven+" trail: once trail_trigger_pips in profit, ratchet SL to
// entry -/+ trail_offset_pips. Only tightens (never loosens) the stop.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double trigger_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_trail_trigger_pips);
   const double offset_dist  = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_trail_offset_pips);
   const double point        = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(trigger_dist <= 0.0 || point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool   is_buy    = (ptype == POSITION_TYPE_BUY);
      const double open_px   = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl    = PositionGetDouble(POSITION_SL);
      const double market    = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_px <= 0.0 || market <= 0.0)
         continue;

      const double moved = is_buy ? (market - open_px) : (open_px - market);
      if(moved < trigger_dist)
         continue;

      const double target_raw = is_buy ? (open_px - offset_dist) : (open_px + offset_dist);
      const double target_sl  = QM_TM_NormalizePrice(_Symbol, target_raw);
      if(target_sl <= 0.0)
         continue;

      const bool improves = (cur_sl <= 0.0) ||
                            (is_buy ? (target_sl > cur_sl + point * 0.5)
                                    : (target_sl < cur_sl - point * 0.5));
      if(!improves)
         continue;

      QM_TM_MoveSL(ticket, target_sl, "lbf_breakeven_plus_trail");
     }
  }

// Time stop: close the open position once the bar-open broker hour reaches
// strategy_time_stop_h (card: 10:00 GMT), if TP not already hit.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime bar_open_bt = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open timestamp
   if(bar_open_bt <= 0)
      return false;

   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(bar_open_bt, dt);
   return (dt.hour >= strategy_time_stop_h);
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
