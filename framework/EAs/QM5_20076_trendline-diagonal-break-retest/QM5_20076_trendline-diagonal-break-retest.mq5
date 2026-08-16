#property strict
#property version   "5.0"
#property description "QM5_20076 Diagonal Trendline Break + Retest (H1)"
// Strategy Card: QM5_20076 (trendline-diagonal-break-retest), G0 APPROVED.
// Source lineage: 6e967762-b26d-59a3-b076-35c17f2e7c36 (FF Trendline-Trader cluster).

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — Diagonal Trendline Break + Retest
// -----------------------------------------------------------------------------
// Deterministic 3-bar-fractal swing-pivot detection builds a sloped trendline
// through the two most-recent same-side pivots. A closed-bar body that pierces
// the line by >= break_frac*ATR arms a break; a bounded retest of the broken
// line then triggers entry at the open of the next bar. Exits: opposite-pivot
// reversal that closes back through the broken line, RR=2.0 take-profit, or a
// 60-bar max-hold. SL = MAX(entry - 1.5*ATR, retest-extreme -/+ buffer).
//
// Framework corset: all per-tick work is O(1) (cached state reads + spread
// gate). All structural detection runs once per closed bar inside
// Strategy_EntrySignal (the framework consumes QM_IsNewBar once per bar). Raw
// iHigh/iLow/iClose reads are bespoke structural-logic exceptions, tagged
// // perf-allowed and evaluated only behind that closed-bar gate.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20076;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;
input int    qm_news_pause_before_minutes = 30;
input int    qm_news_pause_after_minutes  = 30;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_fractal_k         = 3;     // Card: 3-bar fractal half-width each side (P3 {2,3,4}).
input int    strategy_min_pivot_bars    = 8;     // Card: min bars between the two anchor pivots.
input int    strategy_max_pivot_bars    = 80;    // Card: max bars between the two anchor pivots.
input int    strategy_atr_period        = 14;    // Card: ATR(14,H1) for slope/break/stop scale.
input double strategy_slope_atr_frac    = 0.25;  // Card: min |slope| per bar as fraction of ATR.
input double strategy_break_atr_frac    = 0.25;  // Card: close must pierce line by >= frac*ATR.
input int    strategy_retest_bars       = 12;    // Card: retest window (bars after break).
input double strategy_sl_atr_mult       = 1.5;   // Card: ATR stop multiple (P3 {1.0,1.5,2.0,2.5}).
input int    strategy_struct_buffer_pts = 5;     // Card: structural stop buffer beyond retest extreme (points).
input double strategy_rr                = 2.0;   // Card: fixed reward:risk take-profit (P3 {1.5,2.0,3.0}).
input int    strategy_max_hold_bars     = 60;    // Card: max-hold flatten (~10 trading days).
input int    strategy_spread_cap_pts    = 25;    // Card: spread cap (points); only blocks genuine wide spread.

// -----------------------------------------------------------------------------
// File-scope structural state (advanced once per closed bar).
// -----------------------------------------------------------------------------
long   g_bar_counter    = -1;     // monotonic index of the last closed bar (weekend-safe: only advances on real bars).
double g_atr            = 0.0;    // ATR(period) at last closed bar; per-bar read only.

// Two most-recent confirmed swing pivots each side: (counter, price).
long   g_high1_ctr = -1; double g_high1_px = 0.0;   // newest swing high
long   g_high2_ctr = -1; double g_high2_px = 0.0;   // prior swing high
long   g_low1_ctr  = -1; double g_low1_px  = 0.0;   // newest swing low
long   g_low2_ctr  = -1; double g_low2_px  = 0.0;   // prior swing low

// LONG setup: bearish (descending-highs) line broken upward, awaiting retest.
bool   g_long_active     = false;
double g_long_slope      = 0.0;
long   g_long_anchor_ctr = -1;
double g_long_anchor_px  = 0.0;
long   g_long_break_ctr  = -1;
bool   g_long_touched    = false;
double g_long_retest_low = DBL_MAX;   // lowest low observed during the retest window.
long   g_long_line_hi1   = -1;        // pivot-counter identity of the armed line.
long   g_long_line_hi2   = -1;
long   g_long_consumed_hi1 = -1;      // identity of the last line already traded (blocks re-arm until redefined).
long   g_long_consumed_hi2 = -1;
bool   g_long_confirm    = false;     // set on the bar a retest confirms; consumed by Strategy_EntrySignal.

// SHORT setup: bullish (ascending-lows) line broken downward, awaiting retest.
bool   g_short_active     = false;
double g_short_slope      = 0.0;
long   g_short_anchor_ctr = -1;
double g_short_anchor_px  = 0.0;
long   g_short_break_ctr  = -1;
bool   g_short_touched    = false;
double g_short_retest_high = 0.0;     // highest high observed during the retest window.
long   g_short_line_lo1   = -1;
long   g_short_line_lo2   = -1;
long   g_short_consumed_lo1 = -1;
long   g_short_consumed_lo2 = -1;
bool   g_short_confirm    = false;

// Open-position tracking for structural exits (max-hold + opposite-pivot).
int    g_pos_dir        = 0;      // 0 flat, +1 long, -1 short.
long   g_pos_entry_ctr  = -1;
double g_pos_slope      = 0.0;    // broken-line params captured at entry (entry-side exit test).
long   g_pos_anchor_ctr = -1;
double g_pos_anchor_px  = 0.0;
bool   g_exit_requested = false;  // set once-per-bar; read O(1) per tick by Strategy_ExitSignal.

// -----------------------------------------------------------------------------
// Structural helpers (all behind the framework closed-bar gate).
// -----------------------------------------------------------------------------
bool IsSwingHigh(const int center_shift)
  {
   const double hc = iHigh(_Symbol, _Period, center_shift); // perf-allowed: bespoke fractal pivot, once per closed H1 bar.
   if(hc <= 0.0)
      return false;
   for(int j = 1; j <= strategy_fractal_k; j++)
     {
      const double hn = iHigh(_Symbol, _Period, center_shift - j); // perf-allowed: fractal newer-side neighbor.
      const double ho = iHigh(_Symbol, _Period, center_shift + j); // perf-allowed: fractal older-side neighbor.
      if(hn <= 0.0 || ho <= 0.0)
         return false;
      if(hc <= hn || hc <= ho)
         return false;
     }
   return true;
  }

bool IsSwingLow(const int center_shift)
  {
   const double lc = iLow(_Symbol, _Period, center_shift); // perf-allowed: bespoke fractal pivot, once per closed H1 bar.
   if(lc <= 0.0)
      return false;
   for(int j = 1; j <= strategy_fractal_k; j++)
     {
      const double ln = iLow(_Symbol, _Period, center_shift - j); // perf-allowed: fractal newer-side neighbor.
      const double lo = iLow(_Symbol, _Period, center_shift + j); // perf-allowed: fractal older-side neighbor.
      if(ln <= 0.0 || lo <= 0.0)
         return false;
      if(lc >= ln || lc >= lo)
         return false;
     }
   return true;
  }

double LongLineVal(const long ctr)  { return g_long_anchor_px  + g_long_slope  * (double)(ctr - g_long_anchor_ctr); }
double ShortLineVal(const long ctr) { return g_short_anchor_px + g_short_slope * (double)(ctr - g_short_anchor_ctr); }
double PosLineVal(const long ctr)   { return g_pos_anchor_px   + g_pos_slope   * (double)(ctr - g_pos_anchor_ctr); }

void ResetLong()
  {
   g_long_active = false;
   g_long_touched = false;
   g_long_retest_low = DBL_MAX;
  }

void ResetShort()
  {
   g_short_active = false;
   g_short_touched = false;
   g_short_retest_high = 0.0;
  }

void DetectPivots()
  {
   const int c = strategy_fractal_k + 1; // center shift: needs k closed bars on the newer side (c-k == 1).
   const long center_ctr = g_bar_counter - (long)(c - 1);
   if(IsSwingHigh(c))
     {
      g_high2_ctr = g_high1_ctr; g_high2_px = g_high1_px;
      g_high1_ctr = center_ctr;  g_high1_px = iHigh(_Symbol, _Period, c); // perf-allowed: record confirmed pivot price.
     }
   if(IsSwingLow(c))
     {
      g_low2_ctr = g_low1_ctr; g_low2_px = g_low1_px;
      g_low1_ctr = center_ctr; g_low1_px = iLow(_Symbol, _Period, c); // perf-allowed: record confirmed pivot price.
     }
  }

void UpdateLongMachine()
  {
   if(!g_long_active)
     {
      if(g_high1_ctr < 0 || g_high2_ctr < 0)
         return;
      if(g_high1_ctr == g_long_consumed_hi1 && g_high2_ctr == g_long_consumed_hi2)
         return; // same line already traded; wait until a new pivot redefines it.
      const long dctr = g_high1_ctr - g_high2_ctr;
      if(dctr < (long)strategy_min_pivot_bars || dctr > (long)strategy_max_pivot_bars)
         return;
      const double slope = (g_high1_px - g_high2_px) / (double)dctr;
      if(slope >= 0.0)
         return; // bearish line must have descending highs.
      if(MathAbs(slope) < strategy_slope_atr_frac * g_atr)
         return; // reject near-horizontal noise (covered by the horizontal-S/R sibling).
      const double line_val = g_high1_px + slope * (double)(g_bar_counter - g_high1_ctr);
      const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar break test.
      if(c1 <= 0.0)
         return;
      if(c1 > line_val + strategy_break_atr_frac * g_atr)
        {
         g_long_active = true;
         g_long_slope = slope;
         g_long_anchor_ctr = g_high1_ctr;
         g_long_anchor_px = g_high1_px;
         g_long_break_ctr = g_bar_counter;
         g_long_touched = false;
         g_long_retest_low = DBL_MAX;
         g_long_line_hi1 = g_high1_ctr;
         g_long_line_hi2 = g_high2_ctr;
        }
      return;
     }

   if(g_bar_counter - g_long_break_ctr > (long)strategy_retest_bars)
     {
      ResetLong();
      return;
     }

   const double line_val = LongLineVal(g_bar_counter);
   const double low1 = iLow(_Symbol, _Period, 1);   // perf-allowed: closed-bar retest touch.
   const double c1   = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar retest confirm.
   if(low1 <= 0.0 || c1 <= 0.0)
      return;
   if(low1 < g_long_retest_low)
      g_long_retest_low = low1;
   if(low1 <= line_val)
      g_long_touched = true;
   if(g_long_touched && c1 > line_val)
      g_long_confirm = true; // enter long at the open of the next (current forming) bar.
  }

void UpdateShortMachine()
  {
   if(!g_short_active)
     {
      if(g_low1_ctr < 0 || g_low2_ctr < 0)
         return;
      if(g_low1_ctr == g_short_consumed_lo1 && g_low2_ctr == g_short_consumed_lo2)
         return;
      const long dctr = g_low1_ctr - g_low2_ctr;
      if(dctr < (long)strategy_min_pivot_bars || dctr > (long)strategy_max_pivot_bars)
         return;
      const double slope = (g_low1_px - g_low2_px) / (double)dctr;
      if(slope <= 0.0)
         return; // bullish line must have ascending lows.
      if(MathAbs(slope) < strategy_slope_atr_frac * g_atr)
         return;
      const double line_val = g_low1_px + slope * (double)(g_bar_counter - g_low1_ctr);
      const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar break test.
      if(c1 <= 0.0)
         return;
      if(c1 < line_val - strategy_break_atr_frac * g_atr)
        {
         g_short_active = true;
         g_short_slope = slope;
         g_short_anchor_ctr = g_low1_ctr;
         g_short_anchor_px = g_low1_px;
         g_short_break_ctr = g_bar_counter;
         g_short_touched = false;
         g_short_retest_high = 0.0;
         g_short_line_lo1 = g_low1_ctr;
         g_short_line_lo2 = g_low2_ctr;
        }
      return;
     }

   if(g_bar_counter - g_short_break_ctr > (long)strategy_retest_bars)
     {
      ResetShort();
      return;
     }

   const double line_val = ShortLineVal(g_bar_counter);
   const double high1 = iHigh(_Symbol, _Period, 1);  // perf-allowed: closed-bar retest touch.
   const double c1    = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar retest confirm.
   if(high1 <= 0.0 || c1 <= 0.0)
      return;
   if(high1 > g_short_retest_high)
      g_short_retest_high = high1;
   if(high1 >= line_val)
      g_short_touched = true;
   if(g_short_touched && c1 < line_val)
      g_short_confirm = true; // enter short at the open of the next (current forming) bar.
  }

void UpdateExitState()
  {
   if(g_pos_dir == 0)
     {
      g_exit_requested = false;
      return;
     }

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0)
     {
      // Position closed by SL/TP (or a prior exit); clear tracking.
      g_pos_dir = 0;
      g_exit_requested = false;
      return;
     }

   if(g_bar_counter - g_pos_entry_ctr >= (long)strategy_max_hold_bars)
     {
      g_exit_requested = true;
      return;
     }

   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar exit test.
   if(c1 <= 0.0)
      return;
   const double line_val = PosLineVal(g_bar_counter);
   if(g_pos_dir > 0)
     {
      // Opposite swing-high formed after entry AND price closes back below the broken line.
      if(g_high1_ctr > g_pos_entry_ctr && c1 < line_val)
         g_exit_requested = true;
     }
   else
     {
      // Opposite swing-low formed after entry AND price closes back above the broken line.
      if(g_low1_ctr > g_pos_entry_ctr && c1 > line_val)
         g_exit_requested = true;
     }
  }

void AdvanceStructuralState()
  {
   g_bar_counter++;
   g_atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(g_atr <= 0.0)
      return; // ATR warmup — no detection yet.
   DetectPivots();
   UpdateLongMachine();
   UpdateShortMachine();
   UpdateExitState();
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// No Trade Filter — spread gate only (24h Mon-Fri window; Friday close handled
// by the framework). Never fail-closed on zero modeled spread (.DWX invariant).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double cap = strategy_spread_cap_pts * point;
   if(ask > 0.0 && bid > 0.0 && ask > bid && (ask - bid) > cap)
      return true; // block only a genuinely wide spread.
   return false;
  }

// Trade Entry — advances structural state once per closed bar, then fires a
// market entry when a bounded retest of a broken diagonal line confirms.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_long_confirm = false;
   g_short_confirm = false;
   AdvanceStructuralState();

   if(g_atr <= 0.0)
      return false;

   // One position per symbol per magic.
   if(g_pos_dir != 0)
      return false;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double buffer = strategy_struct_buffer_pts * point;

   if(g_long_confirm)
     {
      const double entry_est = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry_est <= 0.0)
        {
         ResetLong();
         return false;
        }
      const double sl_atr = entry_est - strategy_sl_atr_mult * g_atr;
      const double retest_low = (g_long_retest_low < DBL_MAX) ? g_long_retest_low : entry_est;
      const double sl_struct = retest_low - buffer;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, MathMax(sl_atr, sl_struct)); // card: MAX of the two.
      if(sl <= 0.0 || sl >= entry_est)
        {
         ResetLong();
         return false;
        }
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry_est, sl, strategy_rr);
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TLBR_LONG_RETEST";

      g_pos_dir = 1;
      g_pos_entry_ctr = g_bar_counter;
      g_pos_slope = g_long_slope;
      g_pos_anchor_ctr = g_long_anchor_ctr;
      g_pos_anchor_px = g_long_anchor_px;
      g_long_consumed_hi1 = g_long_line_hi1;
      g_long_consumed_hi2 = g_long_line_hi2;
      ResetLong();
      g_exit_requested = false;
      return true;
     }

   if(g_short_confirm)
     {
      const double entry_est = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry_est <= 0.0)
        {
         ResetShort();
         return false;
        }
      const double sl_atr = entry_est + strategy_sl_atr_mult * g_atr;
      const double retest_high = (g_short_retest_high > 0.0) ? g_short_retest_high : entry_est;
      const double sl_struct = retest_high + buffer;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, MathMin(sl_atr, sl_struct)); // card: mirror of MAX.
      if(sl <= entry_est)
        {
         ResetShort();
         return false;
        }
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry_est, sl, strategy_rr);
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TLBR_SHORT_RETEST";

      g_pos_dir = -1;
      g_pos_entry_ctr = g_bar_counter;
      g_pos_slope = g_short_slope;
      g_pos_anchor_ctr = g_short_anchor_ctr;
      g_pos_anchor_px = g_short_anchor_px;
      g_short_consumed_lo1 = g_short_line_lo1;
      g_short_consumed_lo2 = g_short_line_lo2;
      ResetShort();
      g_exit_requested = false;
      return true;
     }

   return false;
  }

// Trade Management — baseline carries no trailing/BE/partial logic (card §Stop Loss).
void Strategy_ManageOpenPosition()
  {
   // No per-tick management in the baseline; SL/TP ride to the framework.
  }

// Trade Close — discretionary exit: reads the once-per-bar cached decision
// (opposite-pivot reversal or max-hold). RR take-profit and SL are broker-side.
bool Strategy_ExitSignal()
  {
   return g_exit_requested;
  }

// News Filter Hook — defer to the central QM_NewsAllowsTrade gate (off for P2).
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        qm_news_pause_before_minutes,
                        qm_news_pause_after_minutes,
                        qm_news_stale_max_hours,
                        qm_news_min_impact))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_20076_trendline-diagonal-break-retest\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
