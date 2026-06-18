#property strict
#property version   "5.0"
#property description "QM5_1364 Brooks Double Top / Double Bottom H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1364 Brooks-Style Double Top / Double Bottom (H4)
// -----------------------------------------------------------------------------
// Al Brooks DBLT / DBLB neckline-break reversal. The double-top/bottom is a
// multi-bar STATE: two sequential same-type swing pivots (3-left/3-right closed
// fractals) at approximately the same level (|P2-P1| <= 0.5*ATR), separated by
// 4..20 H4 bars, with no intervening higher pivot, and a meaningful corrective
// trough (magnitude >= 1.5*ATR). The neckline break is the single trigger
// EVENT: a bar closes beyond the neckline extreme between the two pivots.
//
// Detection runs ONLY on closed bars (3-right confirmation => most recent
// usable pivot is at shift 4). On a fresh neckline-break bar (shift 1) the EA
// enters at the next bar open (Brooks next-bar-open semantics) — SELL on a
// double-top break-down, BUY on a double-bottom break-up. Optional SMA-50
// macro-bias gate, pattern recency (break within `recency_bars` of P2),
// per-pattern de-dup, pattern-height-projected TP, one-time break-even shift,
// new-extreme invalidation, and a 24-bar time stop. Layout mirrors sibling
// QM5_1327 (Brooks pin-bar) for cadence/rearm/news/Friday-close handling — only
// the pattern primitive differs (two structural pivots vs single candle).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1364;
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
input int    strategy_sma_period             = 50;
input int    strategy_fractal_wing           = 3;     // bars left/right for swing pivot
input double strategy_level_equal_atr        = 0.5;   // |P2-P1| <= 0.5*ATR (peak equality)
input double strategy_magnitude_atr          = 1.5;   // (P1 - neckline) >= 1.5*ATR
input int    strategy_min_bars_between        = 4;     // >= 4 H4 bars between P1 and P2
input int    strategy_max_bars_between        = 20;    // <= 20 H4 bars between P1 and P2
input int    strategy_recency_bars           = 3;     // break within N bars of P2
input bool   strategy_use_macro_bias         = true;  // SMA-50 macro-context gate
input double strategy_tp_rmult               = 1.0;   // TP = R_mult * pattern-height
input double strategy_be_trigger_frac        = 0.5;   // BE shift after 0.5*height in favor
input double strategy_sl_buffer_atr          = 0.3;   // SL beyond pattern extreme
input double strategy_sl_cap_atr             = 2.5;   // cap on initial SL distance
input double strategy_invalidate_atr         = 0.2;   // new-extreme invalidation buffer
input int    strategy_time_stop_bars         = 24;    // ~4 trading days time stop
input double strategy_spread_mult            = 2.0;
input int    strategy_spread_lookback        = 20;

double   g_median_spread_points   = 0.0;
ulong    g_active_ticket          = 0;
int      g_active_direction       = 0;  // +1 buy / -1 sell
double   g_pattern_height_price   = 0.0; // height of the pattern that opened the trade
double   g_pattern_extreme_price  = 0.0; // P2 (sell) / L2 (buy) for invalidation
bool     g_be_done                = false;
bool     g_strategy_cadence_ready = false;

// Per-pattern de-dup: a pattern is identified by its two pivot bar-times +
// neckline price. Once it fires (or invalidates) we mark it consumed so the
// same structure cannot re-trigger on subsequent bars while it stays valid.
datetime g_last_p1_time           = 0;
datetime g_last_p2_time           = 0;
double   g_last_neckline          = 0.0;

double PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

// Is shift `s` a confirmed swing-high fractal: high[s] strictly the highest over
// the wing window on both sides. Both sides are CLOSED bars (s >= wing+1).
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

// Find the two most-recent confirmed swing-high pivots (P2 newer, P1 older).
// Returns their shifts; the newest confirmable pivot sits at shift wing+1.
bool FindLastTwoHighs(int &p2_shift, int &p1_shift)
  {
   const int wing  = strategy_fractal_wing;
   const int first = wing + 1; // shift 4 with wing=3 (3-right confirmation)
   // search window must comfortably cover max_bars_between + both wings
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

// Detect a confirmed DOUBLE TOP whose neckline broke on the just-closed bar
// (shift 1 closes below the neckline). Fills SL/TP prices + pattern bookkeeping.
bool PatternSell(double &entry_sl, double &entry_tp, double &height_out,
                 double &extreme_out, datetime &p1t, datetime &p2t, double &neck_out)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   int p2_shift = -1, p1_shift = -1;
   if(!FindLastTwoHighs(p2_shift, p1_shift))
      return false;

   const double p2 = iHigh(_Symbol, strategy_tf, p2_shift); // perf-allowed: fixed closed-bar pivot price
   const double p1 = iHigh(_Symbol, strategy_tf, p1_shift); // perf-allowed: fixed closed-bar pivot price

   // (2) approximately equal level
   if(MathAbs(p2 - p1) > strategy_level_equal_atr * atr)
      return false;

   // (5) bar-count window between the two peaks
   const int gap = p1_shift - p2_shift;
   if(gap < strategy_min_bars_between || gap > strategy_max_bars_between)
      return false;

   // (3) neckline = lowest low in the corrective trough between P1 and P2
   const double neckline = LowestLowBetween(p2_shift, p1_shift);

   // (4) magnitude meaningfulness (use the lower peak so both tops qualify)
   const double lower_peak = MathMin(p1, p2);
   if((lower_peak - neckline) < strategy_magnitude_atr * atr)
      return false;

   // (6) no higher high between P1 and P2 than the two peaks themselves
   const double peak_max = MathMax(p1, p2);
   if(HighestHighBetween(p2_shift, p1_shift) > peak_max + _Point * 0.5)
      return false;

   // (7) reversal trigger: the just-closed bar (shift 1) closes below neckline,
   // and it is the FIRST such close (shift 2 was still at/above the neckline).
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: neckline-break trigger close
   const double c2 = iClose(_Symbol, strategy_tf, 2); // perf-allowed: prior-close break confirmation
   if(c1 >= neckline)
      return false;
   if(c2 < neckline)
      return false; // break already happened on an earlier bar — stale

   // recency: the break bar (shift 1) is within recency_bars of P2
   if((p2_shift - 1) > strategy_recency_bars)
      return false;

   const double pip = PipDistance();
   if(pip <= 0.0)
      return false;

   // SL above the higher of the two tops, capped.
   double sl = peak_max + strategy_sl_buffer_atr * atr;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;
   double risk = sl - bid;
   if(risk <= 0.0)
      return false;
   const double cap = strategy_sl_cap_atr * atr;
   if(risk > cap)
     {
      sl = bid + cap;
      risk = cap;
     }

   // TP = pattern-height projection from entry: height = lower_peak - neckline.
   const double height = lower_peak - neckline;
   if(height <= 0.0)
      return false;

   entry_sl    = NormalizeDouble(sl, _Digits);
   entry_tp    = NormalizeDouble(bid - strategy_tp_rmult * height, _Digits);
   height_out  = height;
   extreme_out = peak_max;
   p1t         = iTime(_Symbol, strategy_tf, p1_shift); // perf-allowed: pattern-identity timestamp
   p2t         = iTime(_Symbol, strategy_tf, p2_shift); // perf-allowed: pattern-identity timestamp
   neck_out    = neckline;
   return true;
  }

// Detect a confirmed DOUBLE BOTTOM whose neckline broke up on the just-closed
// bar (shift 1 closes above the neckline). Mirror of PatternSell.
bool PatternBuy(double &entry_sl, double &entry_tp, double &height_out,
                double &extreme_out, datetime &l1t, datetime &l2t, double &neck_out)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   int l2_shift = -1, l1_shift = -1;
   if(!FindLastTwoLows(l2_shift, l1_shift))
      return false;

   const double l2 = iLow(_Symbol, strategy_tf, l2_shift); // perf-allowed: fixed closed-bar pivot price
   const double l1 = iLow(_Symbol, strategy_tf, l1_shift); // perf-allowed: fixed closed-bar pivot price

   if(MathAbs(l2 - l1) > strategy_level_equal_atr * atr)
      return false;

   const int gap = l1_shift - l2_shift;
   if(gap < strategy_min_bars_between || gap > strategy_max_bars_between)
      return false;

   const double neckline = HighestHighBetween(l2_shift, l1_shift);

   const double higher_trough = MathMax(l1, l2);
   if((neckline - higher_trough) < strategy_magnitude_atr * atr)
      return false;

   const double trough_min = MathMin(l1, l2);
   if(LowestLowBetween(l2_shift, l1_shift) < trough_min - _Point * 0.5)
      return false;

   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: neckline-break trigger close
   const double c2 = iClose(_Symbol, strategy_tf, 2); // perf-allowed: prior-close break confirmation
   if(c1 <= neckline)
      return false;
   if(c2 > neckline)
      return false; // break already happened earlier — stale

   if((l2_shift - 1) > strategy_recency_bars)
      return false;

   const double pip = PipDistance();
   if(pip <= 0.0)
      return false;

   double sl = trough_min - strategy_sl_buffer_atr * atr;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;
   double risk = ask - sl;
   if(risk <= 0.0)
      return false;
   const double cap = strategy_sl_cap_atr * atr;
   if(risk > cap)
     {
      sl = ask - cap;
      risk = cap;
     }

   const double height = neckline - higher_trough;
   if(height <= 0.0)
      return false;

   entry_sl    = NormalizeDouble(sl, _Digits);
   entry_tp    = NormalizeDouble(ask + strategy_tp_rmult * height, _Digits);
   height_out  = height;
   extreme_out = trough_min;
   l1t         = iTime(_Symbol, strategy_tf, l1_shift); // perf-allowed: pattern-identity timestamp
   l2t         = iTime(_Symbol, strategy_tf, l2_shift); // perf-allowed: pattern-identity timestamp
   neck_out    = neckline;
   return true;
  }

bool MacroBiasAllowsSell()
  {
   if(!strategy_use_macro_bias)
      return true;
   const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
   if(sma <= 0.0)
      return true; // SMA unavailable (warmup) — do not block
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: macro-bias close vs SMA
   return (c1 < sma);
  }

bool MacroBiasAllowsBuy()
  {
   if(!strategy_use_macro_bias)
      return true;
   const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
   if(sma <= 0.0)
      return true;
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: macro-bias close vs SMA
   return (c1 > sma);
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
         g_be_done = false;
         // height/extreme are seeded at entry; if a position appears without us
         // having seeded them (e.g. re-attach), fall back to a safe derived value.
         if(g_pattern_height_price <= 0.0)
            g_pattern_height_price = MathAbs(open_price - sl);
        }
      return;
     }

   g_active_ticket = 0;
   g_active_direction = 0;
   g_pattern_height_price = 0.0;
   g_pattern_extreme_price = 0.0;
   g_be_done = false;
  }

void RefreshSpreadMedian()
  {
   double spreads[];
   ArrayResize(spreads, strategy_spread_lookback);
   int n = 0;
   for(int shift = 1; shift <= strategy_spread_lookback; ++shift)
     {
      const long spread = iSpread(_Symbol, strategy_tf, shift);
      if(spread > 0)
        {
         spreads[n] = (double)spread;
         n++;
        }
     }
   if(n <= 0)
     {
      g_median_spread_points = 0.0;
      return;
     }
   ArrayResize(spreads, n);
   ArraySort(spreads);
   if((n % 2) == 1)
      g_median_spread_points = spreads[n / 2];
   else
      g_median_spread_points = 0.5 * (spreads[n / 2 - 1] + spreads[n / 2]);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   RefreshPositionLifecycle();
   RefreshSpreadMedian();

   // Fail-OPEN spread guard: .DWX quotes 0 spread in the tester, so only block a
   // genuinely wide live spread. Never reject on zero/median-absent spread.
   if(g_median_spread_points > 0.0 && strategy_spread_mult > 0.0)
     {
      const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if((double)current_spread > strategy_spread_mult * g_median_spread_points)
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

// Trade Entry — evaluated once per closed bar. Enters on the bar AFTER a fresh
// neckline-break bar (Brooks next-bar-open). SELL on double-top break-down, BUY
// on double-bottom break-up.
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

   double sl = 0.0, tp = 0.0, height = 0.0, extreme = 0.0, neck = 0.0;
   datetime p1t = 0, p2t = 0;

   // Double-top → SELL
   if(MacroBiasAllowsSell() &&
      PatternSell(sl, tp, height, extreme, p1t, p2t, neck) &&
      !PatternAlreadyConsumed(p1t, p2t, neck))
     {
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_DOUBLE_TOP_BREAK_SELL_H4";
      g_pattern_height_price  = height;
      g_pattern_extreme_price = extreme;
      g_be_done = false;
      MarkPatternConsumed(p1t, p2t, neck);
      return true;
     }

   // Double-bottom → BUY
   if(MacroBiasAllowsBuy() &&
      PatternBuy(sl, tp, height, extreme, p1t, p2t, neck) &&
      !PatternAlreadyConsumed(p1t, p2t, neck))
     {
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_DOUBLE_BOTTOM_BREAK_BUY_H4";
      g_pattern_height_price  = height;
      g_pattern_extreme_price = extreme;
      g_be_done = false;
      MarkPatternConsumed(p1t, p2t, neck);
      return true;
     }

   return false;
  }

// Trade Management — one-time break-even shift after price advances
// be_trigger_frac * pattern-height in favor. Static shift, not an adaptive trail.
void Strategy_ManageOpenPosition()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0 || g_be_done || g_pattern_height_price <= 0.0)
      return;
   if(!PositionSelectByTicket(g_active_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double moved = is_buy ? (market - open_price) : (open_price - market);

   if(moved >= strategy_be_trigger_frac * g_pattern_height_price)
     {
      const double pip = PipDistance();
      const double be_price = is_buy ? (open_price + pip) : (open_price - pip);
      QM_TM_MoveSL(g_active_ticket, NormalizeDouble(be_price, _Digits), "brooks_dblt_be_shift");
      g_be_done = true;
     }
  }

// Trade Close — two structural exits:
//   (a) new-extreme invalidation: SELL closes if high[0] exceeds P2 by
//       invalidate_atr*ATR (the failed-continuation read is wrong); mirror BUY.
//   (b) time stop: 24 H4 bars without TP/SL/invalidation → market close.
bool Strategy_ExitSignal()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0)
      return false;
   if(!PositionSelectByTicket(g_active_ticket))
      return false;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);

   // (a) new-extreme invalidation — evaluated every tick on the live bar.
   if(g_pattern_extreme_price > 0.0)
     {
      const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
      const double buf = strategy_invalidate_atr * MathMax(atr, 0.0);
      if(is_buy)
        {
         const double low0 = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(low0 > 0.0 && low0 < g_pattern_extreme_price - buf)
            return true;
        }
      else
        {
         const double high0 = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(high0 > 0.0 && high0 > g_pattern_extreme_price + buf)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1364\",\"ea\":\"brooks-double-top-bottom-h4\"}");
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

   // Management + structural exits run every tick (invalidation is intrabar).
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
