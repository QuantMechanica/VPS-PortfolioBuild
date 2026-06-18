#property strict
#property version   "5.0"
#property description "QM5_11488 samuels-j-123-pattern-pullback-d1 — Samuels 1-2-3 close-swing reversal/continuation (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11488 samuels-j-123-pattern-pullback-d1
// -----------------------------------------------------------------------------
// Source: Jody Samuels "A Simple 123 Forex Strategy" — TradingPub "6 Simple
//   Strategies for Trading Forex" (2014). Card: artifacts/cards_approved/
//   QM5_11488_samuels-j-123-pattern-pullback-d1.md (g0_status APPROVED).
//
// Mechanics (3-point CLOSE-based swing, D1):
//
//   The 1-2-3 structure is a STATE recomputed each closed D1 bar from bounded
//   closed-bar OHLC. The break beyond the Point2 extreme is the single trigger
//   EVENT (the structure is the state, the break is the lone event — this avoids
//   the two-cross-same-bar zero-trade trap).
//
//   LONG (123 Bottom — downtrend reversal / continuation up):
//     Point1 = lowest daily CLOSE in the last p1_lookback bars (the trend low).
//     Point2 = highest daily CLOSE AFTER Point1, within the scan window (rebound
//              peak). Its HIGH (p2_high) is the break reference per the card.
//     Point3 = most recent bar after Point2 whose CLOSE pulled back BELOW Point2
//              yet held AT/ABOVE Point1.low + retrace_pct*(p2_high - p1_low),
//              i.e. >= retrace_pct retracement, WITHOUT breaking Point1 low. The
//              bar distance Point1 -> Point3 must be within [count_min, count_max].
//     Trigger EVENT: latest closed bar CLOSE breaks above Point2.high while the
//              prior closed bar's CLOSE had NOT (one fresh break / bar) and
//              Point1.low is still intact. Enter market BUY.
//     SL = Point1.low - sl_buffer_pips.   TP = entry + tp_rr * (entry - SL).
//
//   SHORT (123 Top — uptrend reversal / continuation down): mirror image
//     (highest close = Point1, lowest close after = Point2 / its low is the
//     break reference, retrace up holding Point1.high, break BELOW Point2.low).
//
//   .DWX correctness notes:
//     - Break is detected on the latest CLOSED bar's CLOSE vs Point2's extreme
//       (not a pending stop, not a gap) so the gapless .DWX CFD model fires it.
//     - Single fresh-break test (prior bar close had NOT broken) gives exactly
//       one entry event per setup and dodges the two-cross-same-bar trap.
//     - Spread guard fails OPEN on zero modeled .DWX spread.
//     - Distance cap (Point1 -> entry) skips over-wide setups (card P2 150-pip cap).
//     - No Friday entry (card filter), in addition to the framework Friday close.
//
// Closed-bar reads start at shift 1 (the latest closed bar). All structural
// scans are bounded by p1_lookback and gated to run once per closed D1 bar via
// QM_IsNewBar() in the framework OnTick wiring. iClose/iHigh/iLow are the only
// raw reads and are perf-allowed bespoke structural OHLC math.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific; the rest is
// framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11488;
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
input int    strategy_p1_lookback        = 30;    // bars scanned for the Point1 close extreme
input int    strategy_p2_scan_min        = 2;     // min bars after Point1 before Point2 may form
input int    strategy_count_min          = 10;    // min bar distance Point1 -> Point3 (card 10-20)
input int    strategy_count_max          = 20;    // max bar distance Point1 -> Point3 (card 10-20)
input double strategy_retrace_pct        = 0.50;  // min retracement of P1->P2 range to qualify Point3
input double strategy_tp_rr              = 2.0;   // take-profit as a multiple of risk (2R, QM-added)
input double strategy_sl_buffer_pips     = 5.0;   // SL placed this many pips beyond Point1 extreme
input double strategy_break_buffer_pips  = 0.0;   // break must exceed Point2 extreme by this many pips
input double strategy_max_dist_pips      = 150.0; // skip if Point1->entry distance exceeds this (card cap)
input double strategy_spread_cap_pips    = 30.0;  // skip only if spread exceeds this many pips (card cap)
input bool   strategy_no_friday_entry    = true;  // card filter: no new entries on Friday

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Detect a valid LONG 1-2-3 close-swing structure. On success fills the Point1
// low (SL anchor), Point1 shift, Point2 high (break reference) and Point3 low.
// perf-allowed: bespoke bounded structural OHLC math, run once per closed bar.
bool Detect123Long(double &p1_low, int &p1_shift, double &p2_high, double &p3_low)
  {
   // Point1 = lowest daily CLOSE in shifts [1 .. p1_lookback] (newest..oldest).
   p1_shift = -1;
   double p1_close = DBL_MAX;
   for(int k = 1; k <= strategy_p1_lookback; ++k)
     {
      const double c = iClose(_Symbol, _Period, k);
      if(c <= 0.0)
         continue;
      if(c < p1_close)
        {
         p1_close = c;
         p1_shift = k;
        }
     }
   if(p1_shift < strategy_p2_scan_min + 1)
      return false; // need room for Point2/Point3 between Point1 and now

   p1_low = iLow(_Symbol, _Period, p1_shift);
   if(p1_low <= 0.0)
      return false;

   // Point2 = highest daily CLOSE strictly AFTER Point1 (smaller shift => more
   // recent). Window: shifts [p2_newest .. p1_shift - p2_scan_min].
   const int p2_oldest = p1_shift - strategy_p2_scan_min; // least-recent allowed
   const int p2_newest = 1;                               // most-recent allowed
   if(p2_oldest < p2_newest)
      return false;

   double p2_close = -1.0;
   int    p2_shift = -1;
   for(int k = p2_oldest; k >= p2_newest; --k)
     {
      const double c = iClose(_Symbol, _Period, k);
      if(c > p2_close)
        {
         p2_close = c;
         p2_shift = k;
        }
     }
   if(p2_shift < 0)
      return false;

   p2_high = iHigh(_Symbol, _Period, p2_shift); // break reference per the card
   if(p2_high <= p1_low)
      return false;

   const double range = p2_high - p1_low;
   if(range <= 0.0)
      return false;
   const double p3_ceiling = p1_low + strategy_retrace_pct * range; // P3 low must be >= this

   // Point3 = most recent bar AFTER Point2 (shift < p2_shift) whose CLOSE pulled
   // back below Point2 while its LOW held >= the retracement floor (>= retrace_pct
   // back toward Point1) and never broke Point1.low. Bar distance Point1->Point3
   // must lie within [count_min, count_max].
   const int p3_oldest = p2_shift - 1;
   const int p3_newest = 1;
   if(p3_oldest < p3_newest)
      return false;

   p3_low = -1.0;
   for(int k = p3_oldest; k >= p3_newest; --k)
     {
      const double l = iLow(_Symbol, _Period, k);
      const double c = iClose(_Symbol, _Period, k);
      if(l <= 0.0 || c <= 0.0)
         continue;
      if(l < p1_low)
         return false; // Point1 broken before a valid Point3 — structure dead
      const int count_p1_p3 = p1_shift - k; // bars between Point1 and this bar
      if(c < p2_high && l >= p3_ceiling &&
         count_p1_p3 >= strategy_count_min && count_p1_p3 <= strategy_count_max)
        {
         p3_low = l;
         return true; // first (most recent) qualifying retrace bar
        }
     }
   return false;
  }

// Detect a valid SHORT 1-2-3 close-swing structure. Mirror of the long.
bool Detect123Short(double &p1_high, int &p1_shift, double &p2_low, double &p3_high)
  {
   // Point1 = highest daily CLOSE in shifts [1 .. p1_lookback].
   p1_shift = -1;
   double p1_close = -1.0;
   for(int k = 1; k <= strategy_p1_lookback; ++k)
     {
      const double c = iClose(_Symbol, _Period, k);
      if(c <= 0.0)
         continue;
      if(c > p1_close)
        {
         p1_close = c;
         p1_shift = k;
        }
     }
   if(p1_shift < strategy_p2_scan_min + 1)
      return false;

   p1_high = iHigh(_Symbol, _Period, p1_shift);
   if(p1_high <= 0.0)
      return false;

   const int p2_oldest = p1_shift - strategy_p2_scan_min;
   const int p2_newest = 1;
   if(p2_oldest < p2_newest)
      return false;

   double p2_close = DBL_MAX;
   int    p2_shift = -1;
   for(int k = p2_oldest; k >= p2_newest; --k)
     {
      const double c = iClose(_Symbol, _Period, k);
      if(c <= 0.0)
         continue;
      if(c < p2_close)
        {
         p2_close = c;
         p2_shift = k;
        }
     }
   if(p2_shift < 0)
      return false;

   p2_low = iLow(_Symbol, _Period, p2_shift); // break reference per the card
   if(p2_low <= 0.0 || p2_low >= p1_high)
      return false;

   const double range = p1_high - p2_low;
   if(range <= 0.0)
      return false;
   const double p3_floor = p1_high - strategy_retrace_pct * range; // P3 high must be <= this

   const int p3_oldest = p2_shift - 1;
   const int p3_newest = 1;
   if(p3_oldest < p3_newest)
      return false;

   p3_high = -1.0;
   for(int k = p3_oldest; k >= p3_newest; --k)
     {
      const double h = iHigh(_Symbol, _Period, k);
      const double c = iClose(_Symbol, _Period, k);
      if(h <= 0.0 || c <= 0.0)
         continue;
      if(h > p1_high)
         return false; // Point1 broken — structure dead
      const int count_p1_p3 = p1_shift - k;
      if(c > p2_low && h <= p3_floor &&
         count_p1_p3 >= strategy_count_min && count_p1_p3 <= strategy_count_max)
        {
         p3_high = h;
         return true;
        }
     }
   return false;
  }

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread).
// All structural work is in Strategy_EntrySignal on the closed-bar path.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // zero modeled spread on .DWX — never block on it

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false;

   if(spread > spread_cap)
      return true; // genuinely wide spread — block

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate, D1).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Card filter: no new entries on Friday (broker time of the forming bar).
   if(strategy_no_friday_entry)
     {
      MqlDateTime now_dt;
      TimeToStruct(TimeCurrent(), now_dt);
      if(now_dt.day_of_week == 5)
         return false;
     }

   const double buf_break = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_break_buffer_pips);
   const double buf_sl    = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_buffer_pips);
   const double max_dist  = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_max_dist_pips);

   // Close of the latest closed bar (shift 1) and the one before it (shift 2)
   // for the single fresh-break EVENT test.
   // perf-allowed: two single closed-bar reads.
   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // ---------------- LONG: break above Point2.high (123 Bottom) ----------------
     {
      double p1_low = 0.0, p2_high = 0.0, p3_low = 0.0;
      int    p1_shift = 0;
      if(Detect123Long(p1_low, p1_shift, p2_high, p3_low))
        {
         const double trigger = p2_high + buf_break;
         // Single fresh break EVENT: latest closed bar CLOSE broke above the
         // trigger, the prior bar CLOSE had NOT. Point1 must still be intact.
         const bool fresh_break = (close1 > trigger && close2 <= trigger);
         if(fresh_break)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(entry > 0.0 && (entry - p1_low) <= max_dist)
              {
               const double sl = QM_StopRulesNormalizePrice(_Symbol, p1_low - buf_sl);
               if(sl > 0.0 && sl < entry)
                 {
                  const double risk = entry - sl;
                  const double tp = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_tp_rr * risk);
                  if(tp > entry)
                    {
                     req.type   = QM_BUY;
                     req.price  = 0.0; // framework fills market price at send
                     req.sl     = sl;
                     req.tp     = tp;
                     req.reason = "samuels_j_123_long";
                     return true;
                    }
                 }
              }
           }
        }
     }

   // ---------------- SHORT: break below Point2.low (123 Top) -------------------
     {
      double p1_high = 0.0, p2_low = 0.0, p3_high = 0.0;
      int    p1_shift = 0;
      if(Detect123Short(p1_high, p1_shift, p2_low, p3_high))
        {
         const double trigger = p2_low - buf_break;
         const bool fresh_break = (close1 < trigger && close2 >= trigger);
         if(fresh_break)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(entry > 0.0 && (p1_high - entry) <= max_dist)
              {
               const double sl = QM_StopRulesNormalizePrice(_Symbol, p1_high + buf_sl);
               if(sl > entry)
                 {
                  const double risk = sl - entry;
                  const double tp = QM_StopRulesNormalizePrice(_Symbol, entry - strategy_tp_rr * risk);
                  if(tp > 0.0 && tp < entry)
                    {
                     req.type   = QM_SELL;
                     req.price  = 0.0;
                     req.sl     = sl;
                     req.tp     = tp;
                     req.reason = "samuels_j_123_short";
                     return true;
                    }
                 }
              }
           }
        }
     }

   return false;
  }

// Fixed SL/TP only (Point1 stop, 2R target). No active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the SL/TP. SL = beyond Point1, TP = 2R.
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
