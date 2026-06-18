#property strict
#property version   "5.0"
#property description "QM5_12425 Gold ORB — Opening-Range Breakout (XAUUSD H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12425 — Gold Opening Range Breakout (XAUUSD H1)
// -----------------------------------------------------------------------------
// Card: artifacts/cards_approved/QM5_12425_gold-orb.md  (g0_status: APPROVED)
// Source: Ulysses O. Andulte / yulz008, GOLD_ORB MQL5 repository,
//         https://github.com/yulz008/GOLD_ORB
//
// Mechanic (mechanical, deterministic — evaluated only on a fresh closed H1 bar):
//   - A "trading day" is anchored at session_start_hour_broker (BROKER time).
//     The first H1 candle of the trading day seeds the opening range:
//       range_high = that bar's High, range_low = that bar's Low.
//   - For each succeeding H1 candle (while the range is NOT yet final):
//       * if the bar's High/Low expands the range, widen range_high/range_low
//         and RESET the consolidation counter (the range is still forming);
//       * if the bar stays fully within the current range, INCREMENT the
//         consolidation counter.
//     The range becomes FINAL once consolidation_count >= range_consolidation
//     (card PriceActionORB_CandleComposition = 3 subsequent in-range candles).
//   - After the range is final, the breakout fires on the CLOSE of an H1 bar:
//       LONG  (signal 11) when bar close > range_high   and enable_long  == true,
//       SHORT (signal 10) when bar close < range_low    and enable_short == true.
//     The close-cross is the single trigger EVENT; the accumulated range is the
//     STATE. (Gapless .DWX CFDs: we reference the bar CLOSE crossing the level,
//     never an intrabar gap.)
//   - At most ONE long and ONE short per trading day (card MaxTradePerDay=2 split
//     into one per side), AND at most one open position per symbol/magic at any
//     time (V5 one-position rule). A side already taken today is not re-armed.
//   - SL / TP are fixed point distances measured from the entry price:
//       source StopLoss = 400 points, TakeProfit = 1200 points (gold points).
//
// Broker time / session note (.DWX, DXZ NY-Close GMT+2/+3 DST-aware):
//   The source frames the session on "server time, market-open hour 1". Per the
//   card Lessons Learned, the session anchor is made configurable and aligned to
//   the Darwinex broker clock. The trading-day boundary is keyed off the bar OPEN
//   timestamp in BROKER time (no wall-clock TimeCurrent() gating). Because gold
//   trades ~24h, the anchor is a broker-hour trading-day start, not a cash-open;
//   the DXZ broker clock itself shifts with US DST, so keying off the bar OPEN
//   timestamp keeps the anchor stable across standard/DST regimes without any
//   hard-coded UTC/ET offset.
//
// .DWX invariants honoured:
//   - Spread guard fails OPEN on zero modeled spread (only blocks a genuinely
//     wide spread when ask>bid).
//   - QM_IsNewBar() consumed exactly ONCE per tick by the framework; the entry
//     hook runs only on a fresh closed H1 bar.
//   - SL/TP point distances converted via SYMBOL_POINT (scale-correct on gold,
//     2-digit). Source "points" are raw MT5 points, so SYMBOL_POINT is the exact
//     conversion (400 pts * 0.01 = $4.00 SL; 1200 pts * 0.01 = $12.00 TP on XAU).
//   - Range OHLC + bar-timestamp reads are bespoke structural data with no
//     framework reader; they advance once per fresh H1 bar (perf-allowed), O(1)
//     per bar with no per-tick loop.
//   - No external macro/CSV feed: the range is built purely from H1 OHLC.
//   - Adaptive equity-slope / losing-streak resume modules from the source are
//     EXCLUDED per the V5 card (HR14 — no PnL-state-mutating parameters).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12425;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Trading-day anchor in BROKER time. The first H1 bar whose OPEN hour equals
// this value seeds the opening range; a new occurrence rolls the session.
// Source default "server market-open hour 1"; configurable per Lessons Learned.
input int    session_start_hour_broker  = 1;
// Number of subsequent in-range H1 candles required before the range is FINAL
// (card PriceActionORB_CandleComposition = 3).
input int    range_consolidation        = 3;
// Fixed stop-loss distance in gold points (source StopLoss = 400).
input int    sl_points                  = 400;
// Fixed take-profit distance in gold points (source TakeProfit = 1200).
input int    tp_points                  = 1200;
// Enable long / short breakouts (card LongPosition / ShortPosition).
input bool   enable_long                = true;
input bool   enable_short               = true;
// Maximum H1 bars to spend forming the range before abandoning the session
// (defensive bound; the range is normally final within a few bars).
input int    max_forming_bars           = 24;
// Maximum spread allowed (gold points). Fails OPEN on zero modeled spread (.DWX).
input int    max_spread_points          = 500;

// -----------------------------------------------------------------------------
// File-scope session state (advanced once per fresh H1 bar).
// -----------------------------------------------------------------------------
datetime g_session_day      = 0;      // broker-midnight datetime of the active trading day
bool     g_range_seeded     = false;  // first bar of the day has seeded the range
bool     g_range_final      = false;  // range has finalized (>= range_consolidation in-range)
double   g_range_high       = 0.0;
double   g_range_low        = 0.0;
int      g_consol_count     = 0;      // consecutive in-range bars since last expansion
int      g_forming_bars     = 0;      // bars elapsed since the range was seeded
bool     g_long_taken       = false;  // a long has already fired this trading day
bool     g_short_taken      = false;  // a short has already fired this trading day

// -----------------------------------------------------------------------------
// Broker-bar timestamp helpers (all in BROKER time — no UTC/ET conversion needed;
// the trading-day anchor is a broker-hour boundary).
// -----------------------------------------------------------------------------

int BrokerHour(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);
   return dt.hour;
  }

// Broker-midnight (00:00 broker) of the day containing this broker timestamp.
datetime BrokerMidnight(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

// Reset all per-session range state for a freshly-rolled trading day.
void ResetSession(const datetime session_day)
  {
   g_session_day  = session_day;
   g_range_seeded = false;
   g_range_final  = false;
   g_range_high   = 0.0;
   g_range_low    = 0.0;
   g_consol_count = 0;
   g_forming_bars = 0;
   g_long_taken   = false;
   g_short_taken  = false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Block trading only on a genuinely wide spread. .DWX quotes ask==bid (spread 0)
// in the tester, so this MUST fail open on zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double cap   = max_spread_points * point;
      if(cap > 0.0 && (ask - bid) > cap)
         return true;   // genuinely wide spread → block
     }
   return false;
  }

// New entry on a freshly-closed H1 bar. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One active position per symbol/magic — no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Locate the just-closed H1 bar in BROKER time. ---
   const datetime bar_broker = iTime(_Symbol, PERIOD_H1, 1);   // perf-allowed
   if(bar_broker <= 0)
      return false;
   const datetime day_broker = BrokerMidnight(bar_broker);
   const int      hour_broker = BrokerHour(bar_broker);

   // --- Session roll: a new broker calendar day resets all range state. ---
   if(day_broker != g_session_day)
      ResetSession(day_broker);

   const double bar_high  = iHigh(_Symbol, PERIOD_H1, 1);    // perf-allowed
   const double bar_low   = iLow(_Symbol, PERIOD_H1, 1);     // perf-allowed
   const double bar_close = iClose(_Symbol, PERIOD_H1, 1);   // perf-allowed
   if(bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
      return false;

   // --- Seed the range on the trading-day anchor bar. ---
   if(!g_range_seeded)
     {
      if(hour_broker != session_start_hour_broker)
         return false;                    // wait for the anchor hour
      g_range_seeded = true;
      g_range_high   = bar_high;
      g_range_low    = bar_low;
      g_consol_count = 0;
      g_forming_bars = 0;
      return false;                       // first bar only seeds; no breakout yet
     }

   // --- While the range is still forming, accumulate / finalize it. ---
   if(!g_range_final)
     {
      g_forming_bars++;

      const bool expands = (bar_high > g_range_high) || (bar_low < g_range_low);
      if(expands)
        {
         if(bar_high > g_range_high) g_range_high = bar_high;
         if(bar_low  < g_range_low)  g_range_low  = bar_low;
         g_consol_count = 0;             // expansion → range not yet consolidated
        }
      else
        {
         g_consol_count++;               // bar fully inside range
        }

      if(g_consol_count >= range_consolidation)
         g_range_final = true;           // range is now FINAL — breakouts armed

      // Defensive bound: abandon a range that never consolidates.
      if(!g_range_final && max_forming_bars > 0 && g_forming_bars >= max_forming_bars)
         return false;

      return false;                       // no breakout while forming
     }

   // --- Range is final: evaluate the breakout off the just-closed bar CLOSE. ---
   QM_OrderType side;
   if(enable_long && !g_long_taken && bar_close > g_range_high)
      side = QM_BUY;
   else if(enable_short && !g_short_taken && bar_close < g_range_low)
      side = QM_SELL;
   else
      return false;

   // --- Fixed SL / TP point distances from the (market) entry. We use the most
   //     recent close as the reference price for the protective levels; the
   //     framework fills at market (req.price = 0.0). ---
   const double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double entry   = bar_close;
   const double sl_dist = sl_points * point;
   const double tp_dist = tp_points * point;
   if(point <= 0.0 || sl_dist <= 0.0)
      return false;

   const double sl_price = QM_StopRulesStopFromDistance(_Symbol, side, entry, sl_dist);
   const double tp_price = (tp_dist > 0.0)
                           ? QM_StopRulesTakeFromDistance(_Symbol, side, entry, tp_dist)
                           : 0.0;
   if(sl_price <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;        // market entry on the breakout-bar close
   req.sl     = sl_price;
   req.tp     = tp_price;   // 0.0 if disabled → no TP
   req.reason = (side == QM_BUY) ? "QM5_12425 gold_orb_long_11"
                                 : "QM5_12425 gold_orb_short_10";

   // Latch the side: at most one long and one short per trading day.
   if(side == QM_BUY)
      g_long_taken = true;
   else
      g_short_taken = true;

   return true;
  }

// No active SL/TP management beyond the fixed exits (card V5 baseline). The
// source trailing stop is a P3 sweep dimension only — OFF here.
void Strategy_ManageOpenPosition()
  {
  }

// Exits are handled entirely by the fixed SL/TP attached at entry (card V5
// baseline). No discretionary time/opposite-signal exit.
bool Strategy_ExitSignal()
  {
   return false;
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
