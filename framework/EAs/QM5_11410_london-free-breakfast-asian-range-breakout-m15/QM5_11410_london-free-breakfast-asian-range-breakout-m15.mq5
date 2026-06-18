#property strict
#property version   "5.0"
#property description "QM5_11410 london-free-breakfast — Asian-range breakout at London open (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11410 london-free-breakfast-asian-range-breakout-m15
// -----------------------------------------------------------------------------
// Source: "London Free Breakfast Forex Trading Strategy" (Anonymous).
// Card: artifacts/cards_approved/QM5_11410_london-free-breakfast-asian-range-breakout-m15.md
//       (g0_status APPROVED).
//
// Mechanics (M15, closed-bar reads at shift 1):
//   Asian range  : High/Low of the prior Asian session, built ONLY from CLOSED
//                  bars whose BAR-OPEN broker-time hour is in [asian_start_h,
//                  asian_end_h). Re-derived once per calendar day, cached.
//   Trigger EVENT: the single just-closed M15 bar's CLOSE breaks the Asian
//                  range while the bar opened inside the London window
//                  [london_start_h, london_end_h):
//                    close[1] > asian_high  -> BUY
//                    close[1] < asian_low   -> SELL
//   Stop         : breakout candle extreme (Low[1] for long / High[1] for
//                  short), distance capped at sl_cap_pips.
//   Take profit  : entry +/- tp_pips (fixed pip distance, scale-correct).
//   One trade per calendar day (first confirmed breakout direction only).
//
// .DWX invariants honoured:
//   * Session windows are evaluated in BROKER TIME (the tester clock IS broker
//     time; DXZ = NY-Close GMT+2/+3). The card already states the windows in
//     broker time, so no UTC conversion is needed — windows are read straight
//     off the bar TIMESTAMP (iTime), never wall-clock.
//   * Asian range is built from prior CLOSED bars (shift >= 1).
//   * Spread guard fails OPEN on the .DWX zero modeled spread.
//   * No swap gate, no external-macro CSV.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11410;
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
// Card: Asian 01:00-09:00 broker; London breakout window ~09:00-10:00 broker.
input int    strategy_asian_start_h     = 1;     // Asian session start hour (broker)
input int    strategy_asian_end_h       = 9;     // Asian session end hour (broker, exclusive)
input int    strategy_london_start_h    = 9;     // London breakout window start hour (broker)
input int    strategy_london_end_h      = 10;    // London breakout window end hour (broker, exclusive)
input int    strategy_tp_pips           = 40;    // fixed take-profit distance (pips)
input int    strategy_sl_cap_pips       = 40;    // max stop distance (pips); breakout-candle extreme capped to this
input int    strategy_min_range_pips    = 5;     // ignore degenerate Asian ranges smaller than this
input double strategy_spread_cap_pips   = 20.0;  // skip only a genuinely wide spread (fail-open on zero spread)

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
         // Once we have collected this day's session and then walk past it into
         // an earlier day, we can stop — bars are ordered newest->oldest.
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

   // Reject a degenerate range so we never trade noise.
   const double min_range = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_range_pips);
   if(min_range > 0.0 && (hi - lo) < min_range)
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
      return false; // no valid range for today yet (e.g. session not finished)

   // --- One trade per calendar day ---
   if(g_traded_day_key == today_key)
      return false;

   // --- London breakout window check (broker time, from the bar timestamp) ---
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(bar_open_bt, dt);
   if(dt.hour < strategy_london_start_h || dt.hour >= strategy_london_end_h)
      return false;

   // --- Breakout EVENT: the just-closed bar's CLOSE breaks the Asian range ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: breakout-candle extreme
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: breakout-candle extreme
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   QM_OrderType side;
   if(close1 > g_asian_high)
      side = QM_BUY;
   else if(close1 < g_asian_low)
      side = QM_SELL;
   else
      return false; // no breakout this bar

   // --- Entry price (market) and stop from the breakout candle, capped ---
   const double entry = (side == QM_BUY)
                          ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);

   double sl;
   if(side == QM_BUY)
     {
      double sl_struct = low1; // breakout-candle low
      // Cap the stop distance so a wide candle does not blow the risk budget.
      if(cap_dist > 0.0 && (entry - sl_struct) > cap_dist)
         sl_struct = entry - cap_dist;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl_struct);
     }
   else
     {
      double sl_struct = high1; // breakout-candle high
      if(cap_dist > 0.0 && (sl_struct - entry) > cap_dist)
         sl_struct = entry + cap_dist;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl_struct);
     }

   // Guard against a non-positive stop distance (e.g. close beyond the wick).
   if((side == QM_BUY && sl >= entry) || (side == QM_SELL && sl <= entry))
      return false;

   const double tp = QM_StopFixedPips(_Symbol,
                                      (side == QM_BUY) ? QM_SELL : QM_BUY,
                                      entry, strategy_tp_pips);
   // QM_StopFixedPips with the opposite side yields a price on the profit side:
   //   for a long, opposite=SELL -> entry + distance (above) = TP.
   //   for a short, opposite=BUY  -> entry - distance (below) = TP.
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "lfb_asian_break_long" : "lfb_asian_break_short";

   // Latch: one trade per calendar day, first confirmed direction only.
   g_traded_day_key = today_key;
   return true;
  }

// Fixed pip TP + breakout-candle SL only; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — SL/TP carry the trade.
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
