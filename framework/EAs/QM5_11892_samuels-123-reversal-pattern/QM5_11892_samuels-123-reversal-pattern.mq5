#property strict
#property version   "5.0"
#property description "QM5_11892 samuels-123-reversal-pattern — Jody Samuels 1-2-3 swing reversal (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11892 samuels-123-reversal-pattern
// -----------------------------------------------------------------------------
// Source: Jody Samuels, "A Simple 123 Forex Strategy" in TradingPub "6 Simple
//   Strategies for Trading Forex" (~2015), pages 23-34. Card:
//   artifacts/cards_approved/QM5_11892_samuels-123-reversal-pattern.md
//   (g0_status APPROVED).
//
// Mechanics (3-point swing reversal from 5-bar fractal pivots, H1 closed bars):
//
//   The 1-2-3 structure is a STATE recomputed each closed H1 bar from bounded
//   closed-bar OHLC. The break of the pivot[2] level is the single trigger EVENT.
//
//   Pivots are the THREE most recent confirmed 5-bar fractals (a high with two
//   lower highs on each side; symmetric for lows). A fractal at shift k is only
//   confirmed once bars k-1, k-2 have closed, so we scan shifts >= 3.
//
//   123 TOP (short setup):
//     pivot[1] = fractal HIGH (the extreme), pivot[2] = fractal LOW (swing),
//     pivot[3] = fractal HIGH (failed retest), with
//       pivot[1].price > pivot[3].price > pivot[2].price   (P3 does NOT exceed P1).
//     Trigger EVENT: latest closed bar's LOW breaks below pivot[2] (2-pip buffer)
//       while the prior closed bar had NOT — one fresh break / bar. Enter market SELL.
//     SL = pivot[1].high + sl_buffer_pips (Samuels' conservative stop).
//     TP = entry - |pivot[3].price - pivot[2].price| * tp_mult  (leg 2->3 projection).
//
//   123 BOTTOM (long setup): mirror image.
//     pivot[1] = fractal LOW, pivot[2] = fractal HIGH, pivot[3] = fractal LOW,
//       pivot[1].price < pivot[3].price < pivot[2].price.
//     Trigger EVENT: latest closed bar's HIGH breaks above pivot[2] (fresh).
//     SL = pivot[1].low - sl_buffer_pips.  TP = entry + leg(2->3)*tp_mult.
//
//   Filters (card §Entry Rules 4-5):
//     - Bar-count: H1 bars between pivot[1] and pivot[3] in [bars_p1p3_min,
//       bars_p1p3_max] (Samuels' 10-20 sweet spot).
//     - Fib retrace: pivot[3]'s retracement of the pivot[1]->pivot[2] leg in
//       [fib_min, fib_max] (0.382-0.786).
//     - Entry window: order valid for entry_window_bars (24) H1 bars after
//       pivot[3] forms — modelled as "pivot[3] must be within entry_window_bars
//       of the trigger bar".
//
//   Hard timeout (card §Exit): close the position at H1 bar timeout_bars (100)
//     after entry if neither stop nor target hit.
//
//   .DWX correctness notes:
//     - Break is detected on the latest CLOSED bar's HIGH/LOW (not a pending stop
//       order, not a gap) so the gapless .DWX CFD model still fires it. The card's
//       "buy/sell-stop order" trigger is realised as a fresh closed-bar break of
//       the pivot[2] level + immediate market entry (single EVENT).
//     - Single fresh-break test (prior bar did NOT break) avoids re-entry storms
//       and the two-cross-same-bar zero-trade trap: structure = STATE, break = EVENT.
//     - Spread guard fails OPEN on zero modeled spread.
//     - Pip-scaled buffers via QM_StopRulesPipsToPriceDistance (5-digit / JPY safe).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific; the rest is
// framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11892;
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
input int    strategy_fractal_lookback   = 60;    // bars scanned for the 3 confirmed fractal pivots
input int    strategy_bars_p1p3_min      = 10;    // min H1 bars between pivot[1] and pivot[3]
input int    strategy_bars_p1p3_max      = 20;    // max H1 bars between pivot[1] and pivot[3]
input double strategy_fib_min            = 0.382; // min retrace of P1->P2 leg for pivot[3]
input double strategy_fib_max            = 0.786; // max retrace of P1->P2 leg for pivot[3]
input int    strategy_entry_window_bars  = 24;    // order valid this many H1 bars after pivot[3]
input double strategy_tp_mult            = 1.0;   // measured-move TP multiple of |P3-P2| leg
input double strategy_sl_buffer_pips     = 3.0;   // SL placed this many pips beyond pivot[1] extreme
input double strategy_break_buffer_pips  = 2.0;   // break must exceed pivot[2] by this many pips
input int    strategy_timeout_bars       = 100;   // hard-close after this many H1 bars in trade
input double strategy_spread_pct_of_stop = 15.0;  // skip only if spread > this % of the stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Confirmed 5-bar fractal tests on the bounded closed-bar OHLC series.
// shift k is a fractal HIGH if it is strictly higher than its two neighbours on
// each side. Caller must pass k >= 3 so neighbours k-1, k-2 (more recent, already
// closed) and k+1, k+2 (older) all exist within the lookback window.
// perf-allowed: bespoke structural fractal math, gated to once per closed bar.
bool IsFractalHigh(const int k)
  {
   const double h   = iHigh(_Symbol, _Period, k);
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
   const double l   = iLow(_Symbol, _Period, k);
   const double lm1 = iLow(_Symbol, _Period, k - 1);
   const double lm2 = iLow(_Symbol, _Period, k - 2);
   const double lp1 = iLow(_Symbol, _Period, k + 1);
   const double lp2 = iLow(_Symbol, _Period, k + 2);
   if(l <= 0.0)
      return false;
   return (l < lm1 && l < lm2 && l < lp1 && l < lp2);
  }

// Scan newest->oldest for the next confirmed fractal HIGH at shift > start_shift.
// Returns its shift or -1. perf-allowed: bounded closed-bar structural scan.
int NextFractalHigh(const int start_shift)
  {
   for(int k = start_shift + 1; k <= strategy_fractal_lookback; ++k)
      if(IsFractalHigh(k))
         return k;
   return -1;
  }

int NextFractalLow(const int start_shift)
  {
   for(int k = start_shift + 1; k <= strategy_fractal_lookback; ++k)
      if(IsFractalLow(k))
         return k;
   return -1;
  }

// Shared filter check on a candidate 1-2-3 (pivot shifts + prices already known).
// Validates bar-count (P1<->P3), Fib-retrace of the P1->P2 leg, and the entry
// window (P3 recent enough). Returns true if all card filters pass.
bool Passes123Filters(const int p1_shift, const int p3_shift,
                      const double p1_price, const double p2_price,
                      const double p3_price)
  {
   // Bar-count filter (card rule 4): |P1.shift - P3.shift| in [min, max].
   const int bars_p1p3 = p1_shift - p3_shift; // p1 older => larger shift
   if(bars_p1p3 < strategy_bars_p1p3_min || bars_p1p3 > strategy_bars_p1p3_max)
      return false;

   // Fib-retrace filter (card rule 5): P3 retraces the P1->P2 leg by [min, max].
   const double leg = MathAbs(p2_price - p1_price);
   if(leg <= 0.0)
      return false;
   const double retrace = MathAbs(p2_price - p3_price) / leg;
   if(retrace < strategy_fib_min || retrace > strategy_fib_max)
      return false;

   // Entry window (card rule 8): P3 must be within entry_window_bars of the
   // trigger bar (shift 1 is the latest closed/trigger bar).
   if((p3_shift - 1) > strategy_entry_window_bars)
      return false;

   return true;
  }

// Detect a valid SHORT 1-2-3 top from the three most recent confirmed fractals:
//   pivot[1]=high (extreme), pivot[2]=low (swing), pivot[3]=high (failed retest),
//   with p1.high > p3.high > p2.low. On success fills the reference prices/shifts.
bool Detect123Short(double &p1_high, double &p2_low, double &p3_high, int &p1_shift)
  {
   // pivot[3] = most recent confirmed fractal HIGH (newest of the three).
   const int p3_shift = NextFractalHigh(2); // first confirmed fractal at shift >=3
   if(p3_shift < 0)
      return false;
   p3_high = iHigh(_Symbol, _Period, p3_shift);
   if(p3_high <= 0.0)
      return false;

   // pivot[2] = the fractal LOW immediately older than pivot[3].
   const int p2_shift = NextFractalLow(p3_shift);
   if(p2_shift < 0)
      return false;
   p2_low = iLow(_Symbol, _Period, p2_shift);
   if(p2_low <= 0.0)
      return false;

   // pivot[1] = the fractal HIGH immediately older than pivot[2] (the extreme).
   p1_shift = NextFractalHigh(p2_shift);
   if(p1_shift < 0)
      return false;
   p1_high = iHigh(_Symbol, _Period, p1_shift);
   if(p1_high <= 0.0)
      return false;

   // Structural ordering (card rule 2): p1.high > p3.high > p2.low.
   if(!(p1_high > p3_high && p3_high > p2_low))
      return false;

   return Passes123Filters(p1_shift, p3_shift, p1_high, p2_low, p3_high);
  }

// Detect a valid LONG 1-2-3 bottom — mirror of the short.
//   pivot[1]=low (extreme), pivot[2]=high (swing), pivot[3]=low (failed retest),
//   with p1.low < p3.low < p2.high.
bool Detect123Long(double &p1_low, double &p2_high, double &p3_low, int &p1_shift)
  {
   const int p3_shift = NextFractalLow(2);
   if(p3_shift < 0)
      return false;
   p3_low = iLow(_Symbol, _Period, p3_shift);
   if(p3_low <= 0.0)
      return false;

   const int p2_shift = NextFractalHigh(p3_shift);
   if(p2_shift < 0)
      return false;
   p2_high = iHigh(_Symbol, _Period, p2_shift);
   if(p2_high <= 0.0)
      return false;

   p1_shift = NextFractalLow(p2_shift);
   if(p1_shift < 0)
      return false;
   p1_low = iLow(_Symbol, _Period, p1_shift);
   if(p1_low <= 0.0)
      return false;

   // Structural ordering (card rule 3): p1.low < p3.low < p2.high.
   if(!(p1_low < p3_low && p3_low < p2_high))
      return false;

   return Passes123Filters(p1_shift, p3_shift, p1_low, p2_high, p3_low);
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
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_buffer_pips);
   if(stop_distance <= 0.0)
      return false;

   if(spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true; // genuinely wide spread — block

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate, H1).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double buf_break = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_break_buffer_pips);
   const double buf_sl    = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_buffer_pips);

   // High/low of the latest closed bar (shift 1) and the one before it (shift 2).
   // perf-allowed: two single closed-bar reads for the break EVENT test.
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1  = iLow(_Symbol, _Period, 1);
   const double high2 = iHigh(_Symbol, _Period, 2);
   const double low2  = iLow(_Symbol, _Period, 2);
   if(high1 <= 0.0 || low1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;

   // ---------------- SHORT: 123 top, break BELOW pivot[2].low -----------------
   {
      double p1_high = 0.0, p2_low = 0.0, p3_high = 0.0;
      int    p1_shift = 0;
      if(Detect123Short(p1_high, p2_low, p3_high, p1_shift))
        {
         const double trigger = p2_low - buf_break;
         // Single fresh break EVENT: latest closed bar broke below the trigger,
         // the prior bar had NOT. pivot[1] must still cap the move (no new high).
         const bool fresh_break = (low1 <= trigger && low2 > trigger);
         if(fresh_break && high1 <= p1_high && high2 <= p1_high)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(entry > 0.0)
              {
               const double leg23 = MathAbs(p3_high - p2_low);
               const double sl = QM_StopRulesNormalizePrice(_Symbol, p1_high + buf_sl);
               const double tp = QM_StopRulesNormalizePrice(_Symbol, entry - strategy_tp_mult * leg23);
               if(sl > entry && tp > 0.0 && tp < entry)
                 {
                  req.type   = QM_SELL;
                  req.price  = 0.0; // framework fills market price at send
                  req.sl     = sl;
                  req.tp     = tp;
                  req.reason = "samuels_123_short";
                  return true;
                 }
              }
           }
        }
   }

   // ---------------- LONG: 123 bottom, break ABOVE pivot[2].high --------------
   {
      double p1_low = 0.0, p2_high = 0.0, p3_low = 0.0;
      int    p1_shift = 0;
      if(Detect123Long(p1_low, p2_high, p3_low, p1_shift))
        {
         const double trigger = p2_high + buf_break;
         const bool fresh_break = (high1 >= trigger && high2 < trigger);
         if(fresh_break && low1 >= p1_low && low2 >= p1_low)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(entry > 0.0)
              {
               const double leg23 = MathAbs(p3_low - p2_high);
               const double sl = QM_StopRulesNormalizePrice(_Symbol, p1_low - buf_sl);
               const double tp = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_tp_mult * leg23);
               if(sl > 0.0 && sl < entry && tp > entry)
                 {
                  req.type   = QM_BUY;
                  req.price  = 0.0;
                  req.sl     = sl;
                  req.tp     = tp;
                  req.reason = "samuels_123_long";
                  return true;
                 }
              }
           }
        }
   }

   return false;
  }

// Hard timeout: close the open position at H1 bar strategy_timeout_bars after
// entry if neither stop nor target hit (card §Exit). Runs on the closed-bar path
// via OnTick's QM_IsNewBar gate; iBarShift is a single bounded read of the bar
// index at the entry time — no per-EA new-bar timestamp gate.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      // perf-allowed: single bounded bar-index lookup, not a history scan.
      const int entry_shift = iBarShift(_Symbol, _Period, entry_time, false);
      if(entry_shift >= strategy_timeout_bars)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

// No discretionary exit beyond the fixed SL/TP measured move + the hard timeout
// handled in Strategy_ManageOpenPosition.
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
