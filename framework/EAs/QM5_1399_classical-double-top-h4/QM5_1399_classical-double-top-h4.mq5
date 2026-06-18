#property strict
#property version   "5.0"
#property description "QM5_1399 Classical (Edwards-Magee) Double Top / Double Bottom H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1399 Classical Double Top / Double Bottom (H4)
// -----------------------------------------------------------------------------
// Edwards-Magee canonical reversal pattern (Technical Analysis of Stock Trends,
// 10th ed, ch.7). The double-top is a multi-bar STATE: two confirmed Williams
// 5-bar fractal swing-highs P1 (older) and P2 (newer) at approximately the same
// level (relative peak-equality <= 0.5%), separated by [10,50] H4 bars, with a
// material corrective trough T between them (depth >= 2.5*ATR AND >= 1.5% abs)
// and no intervening pivot-high taller than min(P1,P2). The neckline (trough low
// for a top) break is the single trigger EVENT: a closed bar closes below the
// neckline — SELL on a double-top break-down, BUY on a double-bottom break-up.
//
// Detection runs ONLY on closed bars (5-bar fractal => newest usable pivot is at
// shift wing+1 = shift 3 with wing=2). On a FRESH neckline-break bar (shift 1
// closes beyond the neckline, shift 2 still on the pattern side) the EA opens at
// market. Layout mirrors sibling QM5_1364 (Brooks double-top/bottom) for cadence,
// per-pattern de-dup, news and Friday-close handling — only the pattern gates
// follow the Edwards-Magee structural definition (relative peak-equality, dual
// trough-depth, wider separation window) and the measured-move exit suite.
//
// Exits (Edwards-Magee): TP = measured move = neckline - (max_peak - neckline)
// projected down from the neckline; partial close (50%) at half the measured
// move + break-even SL; pattern-failure hard exit if price closes back beyond
// min(P1,P2); 48-bar time stop.
//
// NOTE vs card: the card arms a SELL-STOP at low_T - 0.5*ATR after P2. On .DWX
// the framework single-position-per-magic / single-entry path makes a
// close-confirmed neckline break the idiomatic, gap-safe realization of the same
// "neckline break confirms" trigger (prior-CLOSE, not range). Implemented as a
// close-below trigger with market entry; the 12-bar pending-order validity window
// is realized as a recency gate (break within recency_bars of P2 confirmation).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1399;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf            = PERIOD_H4;
input int    strategy_atr_period             = 14;
input int    strategy_fractal_wing           = 2;     // Williams 5-bar fractal: 2 bars each side
input double strategy_peak_equal_rel         = 0.005; // |P2-P1|/P1 <= 0.5% peak-equality
input int    strategy_min_bars_between       = 10;    // >= 10 H4 bars between P1 and P2
input int    strategy_max_bars_between       = 50;    // <= 50 H4 bars between P1 and P2
input double strategy_trough_atr             = 2.5;   // (peak - neckline)/ATR >= 2.5
input double strategy_trough_rel             = 0.015; // (peak - neckline)/peak >= 1.5%
input int    strategy_recency_bars           = 12;    // break within N bars of P2 (pending-order validity)
input double strategy_tp_mult                = 1.0;   // measured-move multiple
input double strategy_partial_frac           = 0.5;   // partial close at 0.5*measured-move; close 50% + BE
input double strategy_partial_close_pct      = 0.5;   // fraction of position to close at partial
input double strategy_sl_buffer_atr          = 0.3;   // SL beyond higher peak (Edwards-Magee "above pattern")
input double strategy_sl_cap_atr             = 3.0;   // ABORT if SL distance > 3.0*ATR (HR14 bounded worst-case)
input int    strategy_time_stop_bars         = 48;    // 48 H4 bars time stop
input int    strategy_reuse_guard_bars       = 20;    // no pattern sharing P1/P2 for 20 bars after entry/invalidation
input double strategy_spread_atr_frac        = 0.25;  // skip entry if spread > 0.25*ATR

double   g_active_atr_at_entry    = 0.0;
ulong    g_active_ticket          = 0;
int      g_active_direction       = 0;  // +1 buy / -1 sell
double   g_measured_move_price    = 0.0; // measured-move distance of the pattern that opened the trade
double   g_neckline_price         = 0.0; // neckline level (trough low for top / trough high for bottom)
double   g_failure_level_price    = 0.0; // min(P1,P2) sell / max(L1,L2) buy — hard-exit trigger
bool     g_partial_done           = false;
bool     g_strategy_cadence_ready = false;

// Per-pattern de-dup: identified by the two pivot bar-times + neckline price.
datetime g_last_p1_time           = 0;
datetime g_last_p2_time           = 0;
double   g_last_neckline          = 0.0;

// Pattern-reuse guard: after a pattern entry/invalidation, suppress patterns that
// SHARE a pivot bar-time with the just-consumed one for reuse_guard_bars bars.
datetime g_guard_p1_time          = 0;
datetime g_guard_p2_time          = 0;
datetime g_guard_until_bartime    = 0;

double PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

// Confirmed Williams swing-high at shift s: high[s] strictly highest over the
// wing window on both sides. Both sides are CLOSED bars (s >= wing+1).
bool IsSwingHigh(const int s)
  {
   const int wing = strategy_fractal_wing;
   const double pivot = iHigh(_Symbol, strategy_tf, s); // perf-allowed: fixed closed-bar fractal pivot
   for(int k = 1; k <= wing; ++k)
     {
      if(iHigh(_Symbol, strategy_tf, s + k) >= pivot) // perf-allowed: bounded fractal wing scan
         return false;
      if(iHigh(_Symbol, strategy_tf, s - k) >= pivot) // perf-allowed: bounded fractal wing scan
         return false;
     }
   return true;
  }

bool IsSwingLow(const int s)
  {
   const int wing = strategy_fractal_wing;
   const double pivot = iLow(_Symbol, strategy_tf, s); // perf-allowed: fixed closed-bar fractal pivot
   for(int k = 1; k <= wing; ++k)
     {
      if(iLow(_Symbol, strategy_tf, s + k) <= pivot) // perf-allowed: bounded fractal wing scan
         return false;
      if(iLow(_Symbol, strategy_tf, s - k) <= pivot) // perf-allowed: bounded fractal wing scan
         return false;
     }
   return true;
  }

// Two most-recent confirmed swing-high pivots (P2 newer, P1 older).
bool FindLastTwoHighs(int &p2_shift, int &p1_shift)
  {
   const int wing  = strategy_fractal_wing;
   const int first = wing + 1; // shift 3 with wing=2 (2-right confirmation)
   const int last  = strategy_max_bars_between + 2 * wing + 5;
   p2_shift = -1;
   p1_shift = -1;
   for(int s = first; s <= last; ++s)
     {
      if(!IsSwingHigh(s))
         continue;
      if(p2_shift < 0)
        {
         p2_shift = s;
         continue;
        }
      p1_shift = s;
      return true;
     }
   return false;
  }

bool FindLastTwoLows(int &l2_shift, int &l1_shift)
  {
   const int wing  = strategy_fractal_wing;
   const int first = wing + 1;
   const int last  = strategy_max_bars_between + 2 * wing + 5;
   l2_shift = -1;
   l1_shift = -1;
   for(int s = first; s <= last; ++s)
     {
      if(!IsSwingLow(s))
         continue;
      if(l2_shift < 0)
        {
         l2_shift = s;
         continue;
        }
      l1_shift = s;
      return true;
     }
   return false;
  }

double LowestLowBetween(const int newer_shift, const int older_shift)
  {
   double lo = DBL_MAX;
   for(int s = newer_shift; s <= older_shift; ++s)
      lo = MathMin(lo, iLow(_Symbol, strategy_tf, s)); // perf-allowed: bounded neckline trough scan
   return lo;
  }

double HighestHighBetween(const int newer_shift, const int older_shift)
  {
   double hi = -DBL_MAX;
   for(int s = newer_shift; s <= older_shift; ++s)
      hi = MathMax(hi, iHigh(_Symbol, strategy_tf, s)); // perf-allowed: bounded neckline trough scan
   return hi;
  }

// Highest confirmed pivot-HIGH strictly between P1 and P2 (exclusive of the two
// peaks). Returns -DBL_MAX if no confirmed intervening pivot-high exists.
double HighestIntermediatePivotHigh(const int p2_shift, const int p1_shift)
  {
   double hi = -DBL_MAX;
   for(int s = p2_shift + 1; s <= p1_shift - 1; ++s)
      if(IsSwingHigh(s))
         hi = MathMax(hi, iHigh(_Symbol, strategy_tf, s)); // perf-allowed: bounded intervening-pivot scan
   return hi;
  }

double LowestIntermediatePivotLow(const int l2_shift, const int l1_shift)
  {
   double lo = DBL_MAX;
   for(int s = l2_shift + 1; s <= l1_shift - 1; ++s)
      if(IsSwingLow(s))
         lo = MathMin(lo, iLow(_Symbol, strategy_tf, s)); // perf-allowed: bounded intervening-pivot scan
   return lo;
  }

// Detect a confirmed DOUBLE TOP whose neckline broke on the just-closed bar.
// Fills SL/TP prices + pattern bookkeeping (Edwards-Magee gates).
bool PatternSell(double &entry_sl, double &entry_tp, double &mm_out, double &neck_out,
                 double &fail_out, datetime &p1t, datetime &p2t)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   int p2_shift = -1, p1_shift = -1;
   if(!FindLastTwoHighs(p2_shift, p1_shift))
      return false;

   const double p2 = iHigh(_Symbol, strategy_tf, p2_shift); // perf-allowed: fixed closed-bar pivot price
   const double p1 = iHigh(_Symbol, strategy_tf, p1_shift); // perf-allowed: fixed closed-bar pivot price
   if(p1 <= 0.0)
      return false;

   // Gate 1: separation window [min,max] H4 bars.
   const int gap = p1_shift - p2_shift;
   if(gap < strategy_min_bars_between || gap > strategy_max_bars_between)
      return false;

   // Gate 2: relative peak-equality |P2-P1|/P1 <= 0.5%.
   if(MathAbs(p2 - p1) / p1 > strategy_peak_equal_rel)
      return false;

   // Neckline = lowest low in the corrective trough between P1 and P2.
   const double neckline = LowestLowBetween(p2_shift, p1_shift);

   // Gate 3 + 4: trough depth — ATR-relative AND price-relative. Use the lower
   // peak so both tops qualify (canonical "must have a clear pullback").
   const double lower_peak = MathMin(p1, p2);
   const double depth = lower_peak - neckline;
   if(depth < strategy_trough_atr * atr)
      return false;
   if((depth / lower_peak) < strategy_trough_rel)
      return false;

   // Gate 5: no intervening confirmed pivot-high taller than min(P1,P2).
   const double interm = HighestIntermediatePivotHigh(p2_shift, p1_shift);
   if(interm > lower_peak + _Point * 0.5)
      return false;

   // Trigger: first close below the neckline (shift 1 below, shift 2 still at/above).
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: neckline-break trigger close
   const double c2 = iClose(_Symbol, strategy_tf, 2); // perf-allowed: prior-close break confirmation
   if(c1 >= neckline)
      return false;
   if(c2 < neckline)
      return false; // break already happened on an earlier bar — stale

   // Recency: break bar (shift 1) within recency_bars of P2 confirmation.
   if((p2_shift - 1) > strategy_recency_bars)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   // SL above the higher of the two tops + buffer; ABORT if distance > cap.
   const double peak_max = MathMax(p1, p2);
   const double sl = peak_max + strategy_sl_buffer_atr * atr;
   const double risk = sl - bid;
   if(risk <= 0.0)
      return false;
   if(risk > strategy_sl_cap_atr * atr)
      return false; // worst-case SL too wide — abort entry (card: ABORT)

   // Measured move: height of the M = max_peak - neckline, projected DOWN from
   // the neckline. TP = neckline - mult*(max_peak - neckline).
   const double mm = peak_max - neckline;
   if(mm <= 0.0)
      return false;

   entry_sl  = NormalizeDouble(sl, _Digits);
   entry_tp  = NormalizeDouble(neckline - strategy_tp_mult * mm, _Digits);
   mm_out    = mm;
   neck_out  = neckline;
   fail_out  = lower_peak; // close back above min(P1,P2) => pattern failed
   p1t       = iTime(_Symbol, strategy_tf, p1_shift); // perf-allowed: pattern-identity timestamp
   p2t       = iTime(_Symbol, strategy_tf, p2_shift); // perf-allowed: pattern-identity timestamp
   return true;
  }

// Detect a confirmed DOUBLE BOTTOM (mirror of PatternSell).
bool PatternBuy(double &entry_sl, double &entry_tp, double &mm_out, double &neck_out,
                double &fail_out, datetime &l1t, datetime &l2t)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   int l2_shift = -1, l1_shift = -1;
   if(!FindLastTwoLows(l2_shift, l1_shift))
      return false;

   const double l2 = iLow(_Symbol, strategy_tf, l2_shift); // perf-allowed: fixed closed-bar pivot price
   const double l1 = iLow(_Symbol, strategy_tf, l1_shift); // perf-allowed: fixed closed-bar pivot price
   if(l1 <= 0.0)
      return false;

   const int gap = l1_shift - l2_shift;
   if(gap < strategy_min_bars_between || gap > strategy_max_bars_between)
      return false;

   if(MathAbs(l2 - l1) / l1 > strategy_peak_equal_rel)
      return false;

   const double neckline = HighestHighBetween(l2_shift, l1_shift);

   const double higher_trough = MathMax(l1, l2);
   const double depth = neckline - higher_trough;
   if(depth < strategy_trough_atr * atr)
      return false;
   if((depth / neckline) < strategy_trough_rel)
      return false;

   const double interm = LowestIntermediatePivotLow(l2_shift, l1_shift);
   if(interm < higher_trough - _Point * 0.5)
      return false;

   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: neckline-break trigger close
   const double c2 = iClose(_Symbol, strategy_tf, 2); // perf-allowed: prior-close break confirmation
   if(c1 <= neckline)
      return false;
   if(c2 > neckline)
      return false; // break already happened earlier — stale

   if((l2_shift - 1) > strategy_recency_bars)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double trough_min = MathMin(l1, l2);
   const double sl = trough_min - strategy_sl_buffer_atr * atr;
   const double risk = ask - sl;
   if(risk <= 0.0)
      return false;
   if(risk > strategy_sl_cap_atr * atr)
      return false;

   const double mm = neckline - trough_min;
   if(mm <= 0.0)
      return false;

   entry_sl  = NormalizeDouble(sl, _Digits);
   entry_tp  = NormalizeDouble(neckline + strategy_tp_mult * mm, _Digits);
   mm_out    = mm;
   neck_out  = neckline;
   fail_out  = higher_trough; // close back below max(L1,L2) => pattern failed
   l1t       = iTime(_Symbol, strategy_tf, l1_shift); // perf-allowed: pattern-identity timestamp
   l2t       = iTime(_Symbol, strategy_tf, l2_shift); // perf-allowed: pattern-identity timestamp
   return true;
  }

bool SelectOurPosition(ulong &ticket, int &direction, double &open_price, double &sl, double &tp, datetime &open_time)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

void RefreshPositionLifecycle()
  {
   ulong ticket = 0;
   int direction = 0;
   double open_price = 0.0, sl = 0.0, tp = 0.0;
   datetime open_time = 0;

   if(SelectOurPosition(ticket, direction, open_price, sl, tp, open_time))
     {
      if(ticket != g_active_ticket)
        {
         g_active_ticket = ticket;
         g_active_direction = direction;
         g_partial_done = false;
         if(g_measured_move_price <= 0.0)
            g_measured_move_price = MathAbs(open_price - sl);
        }
      return;
     }

   g_active_ticket = 0;
   g_active_direction = 0;
   g_measured_move_price = 0.0;
   g_neckline_price = 0.0;
   g_failure_level_price = 0.0;
   g_partial_done = false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   RefreshPositionLifecycle();

   // Fail-OPEN spread guard: .DWX quotes ask==bid (0 spread) in the tester, so
   // only block a genuinely wide live spread (ask>bid). Never reject on zero.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid && strategy_spread_atr_frac > 0.0)
     {
      const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
      if(atr > 0.0 && (ask - bid) > strategy_spread_atr_frac * atr)
         return true;
     }
   return false;
  }

bool PatternAlreadyConsumed(const datetime p1t, const datetime p2t, const double neck)
  {
   if(p1t != g_last_p1_time)
      return false;
   if(p2t != g_last_p2_time)
      return false;
   if(MathAbs(neck - g_last_neckline) > _Point * 0.5)
      return false;
   return true;
  }

void MarkPatternConsumed(const datetime p1t, const datetime p2t, const double neck)
  {
   g_last_p1_time   = p1t;
   g_last_p2_time   = p2t;
   g_last_neckline  = neck;
  }

// Pattern-reuse guard: a fresh pattern that SHARES P1 or P2 bar-time with the
// last consumed pattern is suppressed until guard_until_bartime passes.
bool PatternReuseBlocked(const datetime p1t, const datetime p2t)
  {
   if(g_guard_until_bartime == 0)
      return false;
   const datetime bar0 = iTime(_Symbol, strategy_tf, 0); // perf-allowed: reuse-guard cadence reference
   if(bar0 >= g_guard_until_bartime)
      return false; // guard window elapsed
   if(p1t == g_guard_p1_time || p1t == g_guard_p2_time ||
      p2t == g_guard_p1_time || p2t == g_guard_p2_time)
      return true;
   return false;
  }

void ArmReuseGuard(const datetime p1t, const datetime p2t)
  {
   g_guard_p1_time = p1t;
   g_guard_p2_time = p2t;
   const datetime bar0 = iTime(_Symbol, strategy_tf, 0); // perf-allowed: reuse-guard arming reference
   g_guard_until_bartime = bar0 + (datetime)(strategy_reuse_guard_bars * PeriodSeconds(strategy_tf));
  }

// Trade Entry — once per closed bar. SELL on double-top break-down, BUY on
// double-bottom break-up; market entry on the bar that closed beyond the neckline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   RefreshPositionLifecycle();
   if(g_active_ticket != 0)
      return false;

   double sl = 0.0, tp = 0.0, mm = 0.0, neck = 0.0, fail = 0.0;
   datetime p1t = 0, p2t = 0;

   // Double-top → SELL
   if(PatternSell(sl, tp, mm, neck, fail, p1t, p2t) &&
      !PatternAlreadyConsumed(p1t, p2t, neck) &&
      !PatternReuseBlocked(p1t, p2t))
     {
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "CLASSICAL_DOUBLE_TOP_BREAK_SELL_H4";
      g_measured_move_price = mm;
      g_neckline_price      = neck;
      g_failure_level_price = fail;
      g_active_atr_at_entry = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
      g_partial_done = false;
      MarkPatternConsumed(p1t, p2t, neck);
      ArmReuseGuard(p1t, p2t);
      return true;
     }

   // Double-bottom → BUY
   if(PatternBuy(sl, tp, mm, neck, fail, p1t, p2t) &&
      !PatternAlreadyConsumed(p1t, p2t, neck) &&
      !PatternReuseBlocked(p1t, p2t))
     {
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "CLASSICAL_DOUBLE_BOTTOM_BREAK_BUY_H4";
      g_measured_move_price = mm;
      g_neckline_price      = neck;
      g_failure_level_price = fail;
      g_active_atr_at_entry = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
      g_partial_done = false;
      MarkPatternConsumed(p1t, p2t, neck);
      ArmReuseGuard(p1t, p2t);
      return true;
     }

   return false;
  }

// Trade Management — partial close (50%) at 0.5*measured-move in favour, then
// shift SL to break-even. One-time, static (not an adaptive trail).
void Strategy_ManageOpenPosition()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0 || g_partial_done || g_measured_move_price <= 0.0)
      return;
   if(!PositionSelectByTicket(g_active_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double volume = PositionGetDouble(POSITION_VOLUME);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double moved = is_buy ? (market - open_price) : (open_price - market);

   if(moved >= strategy_partial_frac * g_measured_move_price)
     {
      // Close partial_close_pct of the position, then move SL to break-even.
      const double close_vol = QM_TM_NormalizeVolume(_Symbol, volume * strategy_partial_close_pct);
      if(close_vol > 0.0 && close_vol < volume)
         QM_TM_PartialClose(g_active_ticket, close_vol, QM_EXIT_STRATEGY);

      const double pip = PipDistance();
      const double be_price = is_buy ? (open_price + pip) : (open_price - pip);
      QM_TM_MoveSL(g_active_ticket, NormalizeDouble(be_price, _Digits), "classical_dblt_partial_be");
      g_partial_done = true;
     }
  }

// Trade Close — structural exits:
//   (a) pattern-failure hard exit: SELL closes if price closes back ABOVE
//       min(P1,P2); BUY closes if price closes back BELOW max(L1,L2).
//   (b) time stop: 48 H4 bars without TP/SL/failure → market close.
bool Strategy_ExitSignal()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0)
      return false;
   if(!PositionSelectByTicket(g_active_ticket))
      return false;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);

   // (a) pattern-failure hard exit — closed-bar confirmation.
   if(g_strategy_cadence_ready && g_failure_level_price > 0.0)
     {
      const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: pattern-failure confirmation close
      if(is_buy)
        {
         if(c1 < g_failure_level_price)
            return true;
        }
      else
        {
         if(c1 > g_failure_level_price)
            return true;
        }
     }

   // (b) time stop — closed-bar cadence only.
   if(g_strategy_cadence_ready)
     {
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_since_open = iBarShift(_Symbol, strategy_tf, open_time, false);
      if(bars_since_open >= strategy_time_stop_bars)
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode))
      return true;

   const datetime bar_time = iTime(_Symbol, strategy_tf, 1); // perf-allowed: signal-bar news overlap check
   if(bar_time > 0 && !QM_NewsAllowsTrade(_Symbol, bar_time, qm_news_mode))
      return true;

   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1399\",\"ea\":\"classical-double-top-h4\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   g_strategy_cadence_ready = false;

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   // Single new-bar consume per tick; latch and reuse.
   g_strategy_cadence_ready = QM_IsNewBar(_Symbol, strategy_tf);

   if(Strategy_NoTradeFilter())
      return;

   // Management runs every tick (partial-close trigger is intrabar).
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

   // Entry only on a fresh closed bar.
   if(!g_strategy_cadence_ready)
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
