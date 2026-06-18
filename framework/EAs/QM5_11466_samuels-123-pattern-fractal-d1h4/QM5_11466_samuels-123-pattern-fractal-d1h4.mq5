#property strict
#property version   "5.0"
#property description "QM5_11466 samuels-123-pattern-fractal-d1h4 — Samuels 1-2-3 reversal, Williams fractals (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11466 samuels-123-pattern-fractal-d1h4
// -----------------------------------------------------------------------------
// Source: Jody Samuels "The 123 Pattern" — TradingPub 6 Simple Strategies for
//   Trading Forex (~2015). Card: artifacts/cards_approved/
//   QM5_11466_samuels-123-pattern-fractal-d1h4.md (g0_status APPROVED).
//
// Mechanics (3-point swing reversal confirmed by Williams fractals, D1):
//
//   The 1-2-3 structure is a STATE recomputed each closed D1 bar from bounded
//   closed-bar OHLC. The break of the Point2 level is the single trigger EVENT.
//
//   LONG (downtrend reversal):
//     Point1 = most recent confirmed Williams fractal LOW.
//     Point2 = highest HIGH in the p2_scan_max bars AFTER Point1 (>= p2_scan_min).
//     Point3 = a bar after Point2 whose LOW retraces >= retrace_pct of the
//              (Point2.high - Point1.low) range toward Point1, WITHOUT breaking
//              Point1.low. Point3 must form within p3_window_max bars of Point1.
//     Trigger EVENT: the latest closed bar's HIGH breaks above Point2.high while
//              the prior closed bar's HIGH had NOT (one fresh break / bar), and
//              Point1.low is still intact. Enter market BUY.
//     SL = Point1.low - buffer.   TP = Point2.high + 1.0*(Point2.high-Point1.low).
//
//   SHORT (uptrend reversal): mirror image (fractal HIGH / lowest LOW / retrace
//     down that holds Point1.high / break BELOW Point2.low).
//
//   .DWX correctness notes:
//     - Break is detected on the prior CLOSED bar's HIGH/LOW (not a pending stop
//       order, not a gap) so the gapless .DWX CFD model still fires it.
//     - Single fresh-break test (prev bar did NOT break) avoids re-entry storms
//       and the two-cross-same-bar zero-trade trap: the structure is the STATE,
//       the break is the lone EVENT.
//     - Spread guard fails OPEN on zero modeled spread.
//     - Distance cap (Point1->entry) skips over-wide setups (card: P2 150-pip cap).
//
// Williams fractal (5-bar): bar k is a fractal HIGH iff high[k] > high[k-1],
//   high[k-2] and high[k] > high[k+1], high[k+2]; symmetric for fractal LOW. A
//   fractal at bar k is only CONFIRMED once bars k+1, k+2 have closed, so we scan
//   shifts >= 3 for confirmed fractals (shift 1 is the latest closed bar).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific; the rest is
// framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11466;
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
input int    strategy_fractal_lookback  = 40;    // bars scanned for confirmed fractals / structure
input int    strategy_p2_scan_min       = 3;     // min bars after Point1 before Point2 may form
input int    strategy_p2_scan_max       = 20;    // max bars after Point1 to search for Point2 extreme
input int    strategy_p3_window_max     = 20;    // Point3 must form within this many bars of Point1
input double strategy_retrace_pct       = 0.50;  // min retracement of P1->P2 range to qualify Point3
input double strategy_tp_mult           = 1.0;   // measured-move TP multiple of (P2-P1) range
input double strategy_sl_buffer_pips    = 1.0;   // SL placed this many pips beyond Point1 extreme
input double strategy_break_buffer_pips = 1.0;   // break must exceed Point2 by this many pips
input double strategy_max_dist_pips     = 150.0; // skip if Point1->entry distance exceeds this (card cap)
input double strategy_spread_pct_of_stop = 15.0; // skip only if spread > this % of the stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Confirmed Williams fractal tests on the bounded closed-bar OHLC series.
// shift k is a fractal HIGH if it is strictly higher than its two neighbours
// on each side. Caller must pass k >= 3 so neighbours k-1, k-2 (more recent,
// already closed) and k+1, k+2 (older) all exist within the lookback window.
// perf-allowed: bespoke structural fractal math, gated to once per closed bar.
bool IsFractalHigh(const int k)
  {
   const double h  = iHigh(_Symbol, _Period, k);
   const double hm1 = iHigh(_Symbol, _Period, k - 1);
   const double hm2 = iHigh(_Symbol, _Period, k - 2);
   const double hp1 = iHigh(_Symbol, _Period, k + 1);
   const double hp2 = iHigh(_Symbol, _Period, k + 2);
   if(h <= 0.0)
      return false;
   return (h > hm1 && h > hm2 && h > hp1 && h > hp2);
  }

bool IsFractalLow(const int k)
  {
   const double l  = iLow(_Symbol, _Period, k);
   const double lm1 = iLow(_Symbol, _Period, k - 1);
   const double lm2 = iLow(_Symbol, _Period, k - 2);
   const double lp1 = iLow(_Symbol, _Period, k + 1);
   const double lp2 = iLow(_Symbol, _Period, k + 2);
   if(l <= 0.0)
      return false;
   return (l < lm1 && l < lm2 && l < lp1 && l < lp2);
  }

// Detect a valid LONG 1-2-3 structure (Point1 fractal low). On success fills the
// three reference prices + Point1 shift. Returns false if no clean structure.
bool Detect123Long(double &p1_low, int &p1_shift, double &p2_high, double &p3_low)
  {
   // Most recent confirmed fractal low becomes Point1 (scan newest->oldest).
   p1_shift = -1;
   for(int k = 3; k <= strategy_fractal_lookback; ++k)
     {
      if(IsFractalLow(k))
        {
         p1_shift = k;
         break;
        }
     }
   if(p1_shift < 0)
      return false;

   p1_low = iLow(_Symbol, _Period, p1_shift);
   if(p1_low <= 0.0)
      return false;

   // Point2 = highest HIGH in the window AFTER Point1 (more recent => smaller
   // shift). Bars 1 .. p1_shift-1 are "after" Point1 in time.
   const int newest = p1_shift - strategy_p2_scan_max; // most-recent allowed shift
   const int oldest = p1_shift - strategy_p2_scan_min; // least-recent allowed shift
   const int lo_shift = (newest < 1 ? 1 : newest);
   if(oldest < lo_shift)
      return false; // not enough bars after Point1 yet

   p2_high = -1.0;
   int p2_shift = -1;
   for(int k = oldest; k >= lo_shift; --k)
     {
      const double h = iHigh(_Symbol, _Period, k);
      if(h > p2_high)
        {
         p2_high = h;
         p2_shift = k;
        }
     }
   if(p2_shift < 0 || p2_high <= p1_low)
      return false;

   const double range = p2_high - p1_low;
   if(range <= 0.0)
      return false;
   const double p3_ceiling = p2_high - strategy_retrace_pct * range; // P3 low must be <= this

   // Point3 = a bar AFTER Point2 (shift < p2_shift) whose LOW retraced >= pct of
   // the range toward Point1 but held Point1.low, within p3_window_max of Point1.
   const int p3_oldest = p2_shift - 1;
   int p3_newest = p1_shift - strategy_p3_window_max;
   if(p3_newest < 1)
      p3_newest = 1;
   if(p3_oldest < p3_newest)
      return false;

   p3_low = -1.0;
   bool p3_found = false;
   for(int k = p3_oldest; k >= p3_newest; --k)
     {
      const double l = iLow(_Symbol, _Period, k);
      if(l <= 0.0)
         continue;
      if(l < p1_low)
         return false; // Point1 broken before a valid Point3 — structure dead
      if(l <= p3_ceiling)
        {
         p3_low = l;
         p3_found = true;
         break; // first (most recent) qualifying retrace bar
        }
     }
   return p3_found;
  }

// Detect a valid SHORT 1-2-3 structure (Point1 fractal high). Mirror of the long.
bool Detect123Short(double &p1_high, int &p1_shift, double &p2_low, double &p3_high)
  {
   p1_shift = -1;
   for(int k = 3; k <= strategy_fractal_lookback; ++k)
     {
      if(IsFractalHigh(k))
        {
         p1_shift = k;
         break;
        }
     }
   if(p1_shift < 0)
      return false;

   p1_high = iHigh(_Symbol, _Period, p1_shift);
   if(p1_high <= 0.0)
      return false;

   const int newest = p1_shift - strategy_p2_scan_max;
   const int oldest = p1_shift - strategy_p2_scan_min;
   const int lo_shift = (newest < 1 ? 1 : newest);
   if(oldest < lo_shift)
      return false;

   p2_low = DBL_MAX;
   int p2_shift = -1;
   for(int k = oldest; k >= lo_shift; --k)
     {
      const double l = iLow(_Symbol, _Period, k);
      if(l <= 0.0)
         continue;
      if(l < p2_low)
        {
         p2_low = l;
         p2_shift = k;
        }
     }
   if(p2_shift < 0 || p2_low >= p1_high)
      return false;

   const double range = p1_high - p2_low;
   if(range <= 0.0)
      return false;
   const double p3_floor = p2_low + strategy_retrace_pct * range; // P3 high must be >= this

   const int p3_oldest = p2_shift - 1;
   int p3_newest = p1_shift - strategy_p3_window_max;
   if(p3_newest < 1)
      p3_newest = 1;
   if(p3_oldest < p3_newest)
      return false;

   p3_high = -1.0;
   bool p3_found = false;
   for(int k = p3_oldest; k >= p3_newest; --k)
     {
      const double h = iHigh(_Symbol, _Period, k);
      if(h <= 0.0)
         continue;
      if(h > p1_high)
         return false; // Point1 broken — structure dead
      if(h >= p3_floor)
        {
         p3_high = h;
         p3_found = true;
         break;
        }
     }
   return p3_found;
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

   // Reference the SL-buffer-scaled distance so the cap scales per symbol.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_max_dist_pips);
   if(stop_distance <= 0.0)
      return false;

   if(spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true; // genuinely wide spread — block

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate, D1).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double buf_break = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_break_buffer_pips);
   const double buf_sl    = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_buffer_pips);
   const double max_dist  = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_max_dist_pips);

   // High/low of the latest closed bar (shift 1) and the one before it (shift 2).
   // perf-allowed: two single closed-bar reads for the break EVENT test.
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1  = iLow(_Symbol, _Period, 1);
   const double high2 = iHigh(_Symbol, _Period, 2);
   const double low2  = iLow(_Symbol, _Period, 2);
   if(high1 <= 0.0 || low1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;

   // ---------------- LONG: break of Point2.high (downtrend reversal) ----------
   {
      double p1_low = 0.0, p2_high = 0.0, p3_low = 0.0;
      int    p1_shift = 0;
      if(Detect123Long(p1_low, p1_shift, p2_high, p3_low))
        {
         const double trigger = p2_high + buf_break;
         // Single fresh break EVENT: latest closed bar broke the trigger, the
         // prior bar had NOT. Point1 must still be intact.
         const bool fresh_break = (high1 >= trigger && high2 < trigger);
         if(fresh_break && low1 >= p1_low && low2 >= p1_low)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(entry > 0.0 && (entry - p1_low) <= max_dist)
              {
               const double range = p2_high - p1_low;
               const double sl = QM_StopRulesNormalizePrice(_Symbol, p1_low - buf_sl);
               const double tp = QM_StopRulesNormalizePrice(_Symbol, p2_high + strategy_tp_mult * range);
               if(sl > 0.0 && sl < entry && tp > entry)
                 {
                  req.type   = QM_BUY;
                  req.price  = 0.0; // framework fills market price at send
                  req.sl     = sl;
                  req.tp     = tp;
                  req.reason = "samuels_123_long";
                  return true;
                 }
              }
           }
        }
   }

   // ---------------- SHORT: break of Point2.low (uptrend reversal) ------------
   {
      double p1_high = 0.0, p2_low = 0.0, p3_high = 0.0;
      int    p1_shift = 0;
      if(Detect123Short(p1_high, p1_shift, p2_low, p3_high))
        {
         const double trigger = p2_low - buf_break;
         const bool fresh_break = (low1 <= trigger && low2 > trigger);
         if(fresh_break && high1 <= p1_high && high2 <= p1_high)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(entry > 0.0 && (p1_high - entry) <= max_dist)
              {
               const double range = p1_high - p2_low;
               const double sl = QM_StopRulesNormalizePrice(_Symbol, p1_high + buf_sl);
               const double tp = QM_StopRulesNormalizePrice(_Symbol, p2_low - strategy_tp_mult * range);
               if(sl > entry && tp > 0.0 && tp < entry)
                 {
                  req.type   = QM_SELL;
                  req.price  = 0.0;
                  req.sl     = sl;
                  req.tp     = tp;
                  req.reason = "samuels_123_short";
                  return true;
                 }
              }
           }
        }
   }

   return false;
  }

// Fixed SL/TP only (measured move). No active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the SL/TP measured move. SL = beyond Point1.
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
