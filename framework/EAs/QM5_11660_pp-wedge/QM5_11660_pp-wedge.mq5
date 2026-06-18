#property strict
#property version   "5.0"
#property description "QM5_11660 pp-wedge — Rising/Falling Wedge breakout reversal (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11660 pp-wedge
// -----------------------------------------------------------------------------
// Source: Keith Orange / keithorange, PatternPy, tradingpatterns/tradingpatterns.py
//   detect_wedge (https://github.com/keithorange/PatternPy/...).
// Card: artifacts/cards_approved/QM5_11660_pp-wedge.md (g0_status APPROVED).
//
// Mechanics — wedge breakout REVERSAL, all reads on closed bars (shift>=1):
//   The PatternPy source labels "Wedge Up"/"Wedge Down" from converging rolling
//   high/low trendlines. The V5 realization trades the wedge as a price pattern
//   with a structural breakout trigger:
//
//   WEDGE STATE (computed in-EA from bounded swing pivots, perf-allowed):
//     * Find the two most recent confirmed swing HIGHs and the two most recent
//       confirmed swing LOWs within a bounded lookback. A swing pivot is a
//       fractal: a bar whose high (low) exceeds its `swing_wing` neighbours on
//       both sides — so it is confirmed only after `swing_wing` later bars.
//     * Upper trendline slope = (high_recent - high_older) / (bars apart).
//       Lower trendline slope = (low_recent  - low_older)  / (bars apart).
//     * RISING wedge  : both slopes > 0 AND converging (lower rises faster than
//                       upper, gap narrows) -> bearish reversal bias.
//     * FALLING wedge : both slopes < 0 AND converging (upper falls faster than
//                       lower, gap narrows) -> bullish reversal bias.
//     * Require a minimum gap-narrowing ratio so a parallel channel is rejected.
//
//   TRIGGER EVENT (single, one direction per state — avoids the two-cross trap):
//     * RISING wedge  -> SHORT when close[1] breaks BELOW the projected lower
//                        trendline (against the up-sloping wedge).
//     * FALLING wedge -> LONG  when close[1] breaks ABOVE the projected upper
//                        trendline (against the down-sloping wedge).
//     The breakout close is the ONLY event; the wedge geometry is a STATE. The
//     prior bar must have been on the non-broken side, so each bar fires at most
//     one direction.
//
//   STOP   : entry -/+ sl_atr_mult * ATR(atr_period).
//   TARGET : RR multiple of the stop (tp_rr).
//   EXIT   : opposite wedge breakout, OR close beyond the prior bar's extreme
//            against the position, OR max_hold_bars in trade.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11660;
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
input int    strategy_swing_wing        = 3;    // fractal half-width (window=3 per card)
input int    strategy_lookback_bars     = 60;   // bounded bars scanned for swing pivots
input double strategy_min_converge_ratio = 1.15; // recent gap must be < older gap / ratio
input int    strategy_atr_period        = 14;   // ATR period (stop sizing / breakout buffer)
input double strategy_break_atr_buffer  = 0.10; // breakout must clear line by buffer*ATR
input double strategy_sl_atr_mult       = 2.0;  // stop distance = mult * ATR
input double strategy_tp_rr             = 2.0;  // take-profit as RR multiple of stop
input int    strategy_max_hold_bars     = 12;   // time-stop in bars (12 H4 bars per card)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached wedge state — recomputed once per closed bar in
// AdvanceState_OnNewBar(). Strategy_EntrySignal/ExitSignal only READ these.
//   g_wedge_dir : +1 falling wedge (long bias), -1 rising wedge (short bias), 0 none.
//   g_break_dir : +1 bullish breakout fired this bar, -1 bearish, 0 none.
// -----------------------------------------------------------------------------
int      g_wedge_dir   = 0;
int      g_break_dir   = 0;
int      g_bars_in_pos = 0;   // closed-bar counter while a position is held

// Find the most recent `count` confirmed swing pivots (highs if find_high else
// lows) into out_shift[]/out_price[]. A pivot at shift s is confirmed by
// swing_wing bars on each side. Scans newest->oldest within the lookback.
// Returns the number of pivots found (may be < count). Bounded loop.
int FindSwings(const bool find_high, const int count,
               int &out_shift[], double &out_price[])
  {
   int found = 0;
   const int wing = (strategy_swing_wing < 1 ? 1 : strategy_swing_wing);
   // start at shift = wing+1 so a full right wing of CLOSED bars (>=1) exists.
   const int start = wing + 1;
   const int stop  = strategy_lookback_bars + wing;
   for(int s = start; s <= stop && found < count; ++s)
     {
      // perf-allowed: bespoke structural pivot scan, gated to one run/closed bar.
      const double pivot = (find_high ? iHigh(_Symbol, _Period, s)
                                      : iLow(_Symbol, _Period, s));
      if(pivot <= 0.0)
         continue;
      bool is_pivot = true;
      for(int k = 1; k <= wing && is_pivot; ++k)
        {
         const double left  = (find_high ? iHigh(_Symbol, _Period, s + k)
                                         : iLow(_Symbol, _Period, s + k));
         const double right = (find_high ? iHigh(_Symbol, _Period, s - k)
                                         : iLow(_Symbol, _Period, s - k));
         if(left <= 0.0 || right <= 0.0)
           { is_pivot = false; break; }
         if(find_high)
           {
            if(left >= pivot || right >= pivot) is_pivot = false;
           }
         else
           {
            if(left <= pivot || right <= pivot) is_pivot = false;
           }
        }
      if(is_pivot)
        {
         out_shift[found] = s;
         out_price[found] = pivot;
         ++found;
        }
     }
   return found;
  }

// Recompute the wedge state + breakout event for the just-closed bar.
void AdvanceState_OnNewBar()
  {
   g_wedge_dir = 0;
   g_break_dir = 0;

   int    hi_shift[2]; double hi_price[2];
   int    lo_shift[2]; double lo_price[2];
   const int n_hi = FindSwings(true,  2, hi_shift, hi_price);
   const int n_lo = FindSwings(false, 2, lo_shift, lo_price);
   if(n_hi < 2 || n_lo < 2)
      return;

   // hi_shift[0] is the NEWER high (smaller shift), hi_shift[1] the older.
   const int    hi_dx = hi_shift[1] - hi_shift[0];   // >0 bars apart
   const int    lo_dx = lo_shift[1] - lo_shift[0];
   if(hi_dx <= 0 || lo_dx <= 0)
      return;

   // Slope per bar in the forward (time-increasing) direction. Newer minus older
   // over the bar separation; positive slope = rising line.
   const double up_slope = (hi_price[0] - hi_price[1]) / (double)hi_dx;
   const double lo_slope = (lo_price[0] - lo_price[1]) / (double)lo_dx;

   // Gaps between the two trendlines at the older and newer pivot anchors.
   const double gap_old = hi_price[1] - lo_price[1];
   const double gap_new = hi_price[0] - lo_price[0];
   if(gap_old <= 0.0 || gap_new <= 0.0)
      return;
   // Converging: the newer gap must be materially narrower than the older one.
   const bool converging = (gap_old > gap_new * strategy_min_converge_ratio);
   if(!converging)
      return;

   if(up_slope > 0.0 && lo_slope > 0.0)
      g_wedge_dir = -1;   // RISING wedge -> bearish reversal bias
   else if(up_slope < 0.0 && lo_slope < 0.0)
      g_wedge_dir = +1;   // FALLING wedge -> bullish reversal bias
   else
      return;

   // --- Breakout EVENT: project the relevant trendline to shift 1 and 2 and
   //     require the close to cross it (with an ATR buffer). The prior bar must
   //     be on the non-broken side so the cross is a fresh single event. ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;
   const double buffer = strategy_break_atr_buffer * atr_value;

   // perf-allowed: two closed-bar close reads for the breakout trigger.
   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return;

   if(g_wedge_dir == -1)
     {
      // Project LOWER trendline (anchored at the newer low) to shifts 1 and 2.
      // Forward step from anchor shift lo_shift[0] to a target shift t is
      // (lo_shift[0] - t) bars in the time-increasing direction.
      const double line1 = lo_price[0] + lo_slope * (double)(lo_shift[0] - 1);
      const double line2 = lo_price[0] + lo_slope * (double)(lo_shift[0] - 2);
      // Fresh break DOWN: prior close at/above the line, current close below - buffer.
      if(close2 >= line2 && close1 < (line1 - buffer))
         g_break_dir = -1;
     }
   else // g_wedge_dir == +1
     {
      // Project UPPER trendline (anchored at the newer high) to shifts 1 and 2.
      const double line1 = hi_price[0] + up_slope * (double)(hi_shift[0] - 1);
      const double line2 = hi_price[0] + up_slope * (double)(hi_shift[0] - 2);
      // Fresh break UP: prior close at/below the line, current close above + buffer.
      if(close2 <= line2 && close1 > (line1 + buffer))
         g_break_dir = +1;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // defer to entry gate, do not block here
   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;
   return false;
  }

// Entry on the cached breakout event. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_break_dir == 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(g_break_dir == +1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "falling_wedge_break_long";
      g_bars_in_pos = 0;
      return true;
     }

   if(g_break_dir == -1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "rising_wedge_break_short";
      g_bars_in_pos = 0;
      return true;
     }

   return false;
  }

// Advance the in-trade bar counter once per closed bar while a position exists.
void Strategy_ManageOpenPosition()
  {
   // No active SL/TP modification; only the closed-bar time-stop counter.
   // (The actual increment is driven from the new-bar gate in OnTick.)
  }

// Discretionary exit: opposite wedge breakout, close beyond prior bar extreme
// against the position, or max hold time. Evaluated per tick; structural reads
// use the cached state / closed-bar prices.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine current position direction (one position per magic).
   bool   is_long = false;
   bool   have    = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      have    = true;
      break;
     }
   if(!have)
      return false;

   // Time stop.
   if(g_bars_in_pos >= strategy_max_hold_bars)
      return true;

   // Opposite wedge breakout closes the trade.
   if(is_long && g_break_dir == -1)
      return true;
   if(!is_long && g_break_dir == +1)
      return true;

   // Close beyond the prior bar's extreme against the position. perf-allowed:
   // single closed-bar reads of prior high/low.
   const double close1 = iClose(_Symbol, _Period, 1);
   const double low2   = iLow(_Symbol, _Period, 2);
   const double high2  = iHigh(_Symbol, _Period, 2);
   if(close1 > 0.0)
     {
      if(is_long && low2 > 0.0 && close1 < low2)
         return true;
      if(!is_long && high2 > 0.0 && close1 > high2)
         return true;
     }
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

   // Closed-bar state advance: recompute wedge geometry + breakout event once.
   AdvanceState_OnNewBar();

   // Closed-bar in-trade counter for the time stop.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      g_bars_in_pos++;
   else
      g_bars_in_pos = 0;

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
