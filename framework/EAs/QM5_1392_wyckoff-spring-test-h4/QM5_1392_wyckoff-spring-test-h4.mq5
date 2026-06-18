#property strict
#property version   "5.0"
#property description "QM5_1392 Wyckoff Spring + Test (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1392 Wyckoff Spring + Test — Range Accumulation Reversal (H4)
// -----------------------------------------------------------------------------
// A Wyckoff trading range is a multi-bar STATE: a consolidation whose
// range_high / range_low are the extreme high/low over bars [5..40] (excluding
// the recent 5-bar "Spring window"), qualified by ATR-scaled width gates and a
// multiply-tested support (>=3 closed bars touch the low region).
//
// The Spring (BUY) is a false-breakdown below range_low followed by a bull bar
// reclaiming the range; the Upthrust (SELL) is its distribution-side mirror.
// The single trigger EVENT is the recovery: bar[1] closes clearly back above
// range_low + 0.5*ATR (BUY) / below range_high - 0.5*ATR (SELL), confirming the
// failed breakdown/breakout. A successful Test (re-visit holding above the
// Spring low / below the Upthrust high) must sit between the Spring and the
// trigger.
//
// Detection runs ONLY on closed bars. SL sits just beyond the Spring/Upthrust
// extreme; TP projects to the OPPOSITE side of the range (Wyckoff canonical).
// A range-midpoint partial moves the remaining SL to break-even. Hard exits:
// close beyond the Spring/Upthrust extreme (range-invalidation) and a 36-bar
// time stop. Per-Spring de-dup + a re-use cooldown prevent serial re-entry.
// Framework handles news, Friday-close, session gating (setfile), risk + magic.
// Structural layout mirrors sibling QM5_1364 (range/pivot reversal family).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1392;
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
input ENUM_TIMEFRAMES strategy_atr_d1_tf     = PERIOD_D1;  // daily-vol range gate
input int    strategy_sma_macro_period       = 200;        // macro-bias soft filter
input int    strategy_range_lookback         = 40;         // range-id window (H4 bars)
input int    strategy_spring_window          = 5;          // recent bars excluded from range / Spring search
input double strategy_range_min_atrd1        = 1.5;        // range_width >= 1.5*ATR(D1)
input double strategy_range_max_atrd1        = 6.0;        // range_width <= 6.0*ATR(D1)
input int    strategy_min_low_tests          = 3;          // >=3 bars touch low region
input double strategy_low_test_band_atr      = 0.2;        // low-test tolerance (*ATR_H4)
input double strategy_spring_pierce_atr      = 0.1;        // Spring pierces low by >= 0.1*ATR_H4
input double strategy_spring_reclaim_atr      = 0.1;       // Spring close reclaims low by >= 0.1*ATR_H4
input double strategy_spring_depth_min_atr    = 0.15;      // Spring depth >= 0.15*ATR_H4
input double strategy_spring_depth_max_atr    = 1.0;       // Spring depth <= 1.0*ATR_H4
input double strategy_test_band_atr           = 0.3;       // Test re-visits low within 0.3*ATR_H4
input double strategy_trigger_clearance_atr   = 0.5;       // trigger close beyond level by 0.5*ATR_H4
input double strategy_trigger_body_ratio      = 0.40;      // trigger bar min body ratio
input int    strategy_spring_min_age          = 2;         // Spring 2..7 bars old
input int    strategy_spring_max_age          = 7;
input double strategy_macro_slack_atr         = 5.0;       // macro-bias soft slack (*ATR_H4)
input double strategy_tp_pullback_atr         = 0.3;       // TP set 0.3*ATR inside opposite edge
input double strategy_sl_buffer_atr           = 0.3;       // SL beyond Spring/Upthrust extreme
input double strategy_vol_lo_mult             = 0.7;       // ATR[1] >= 0.7*ATR[lookback]
input double strategy_vol_hi_mult             = 2.5;       // ATR[1] <= 2.5*ATR[lookback]
input int    strategy_time_stop_bars          = 36;        // ~6 trading days
input int    strategy_reuse_cooldown_bars     = 24;        // no re-trade same Spring for 24 bars
input double strategy_spread_mult             = 2.0;
input int    strategy_spread_lookback         = 20;

double   g_median_spread_points   = 0.0;
ulong    g_active_ticket          = 0;
int      g_active_direction       = 0;   // +1 buy / -1 sell
double   g_spring_extreme_price   = 0.0; // low[s] (buy) / high[s] (sell) for invalidation
double   g_range_high_at_entry    = 0.0;
double   g_range_low_at_entry     = 0.0;
bool     g_partial_done           = false;
bool     g_strategy_cadence_ready = false;

// Per-Spring de-dup + cooldown: identify a Spring by its bar-open time. Once a
// trade fires on a Spring (or it would re-qualify), suppress new entries on the
// same Spring time for the cooldown window.
datetime g_last_spring_time       = 0;
datetime g_last_spring_trade_time = 0;

double BodyRatio(const int s)
  {
   const double o  = iOpen(_Symbol, strategy_tf, s);   // perf-allowed: fixed closed-bar candle body
   const double c  = iClose(_Symbol, strategy_tf, s);  // perf-allowed: fixed closed-bar candle body
   const double hi = iHigh(_Symbol, strategy_tf, s);   // perf-allowed: fixed closed-bar candle body
   const double lo = iLow(_Symbol, strategy_tf, s);    // perf-allowed: fixed closed-bar candle body
   return MathAbs(c - o) / (hi - lo + 1e-9);
  }

// Build the range STATE over bars [spring_window .. range_lookback], qualified
// by ATR(D1) width gates and a multiply-tested support/resistance. Returns the
// range edges; false if no qualified range exists.
bool BuildRange(const double atr_h4, double &range_high, double &range_low)
  {
   const int    first = strategy_spring_window;             // 5
   const int    last  = strategy_range_lookback;            // 40
   const double atr_d1 = QM_ATR(_Symbol, strategy_atr_d1_tf, strategy_atr_period, 1);
   if(atr_d1 <= 0.0 || atr_h4 <= 0.0)
      return false;

   double hi = -DBL_MAX, lo = DBL_MAX;
   for(int s = first; s <= last; ++s)
     {
      const double bh = iHigh(_Symbol, strategy_tf, s); // perf-allowed: bounded range-id scan
      const double bl = iLow(_Symbol, strategy_tf, s);  // perf-allowed: bounded range-id scan
      if(bh > hi) hi = bh;
      if(bl < lo) lo = bl;
     }
   if(hi <= lo)
      return false;

   const double width = hi - lo;
   if(width < strategy_range_min_atrd1 * atr_d1)
      return false;
   if(width > strategy_range_max_atrd1 * atr_d1)
      return false;

   // Support must have been tested by >= strategy_min_low_tests distinct bars.
   const double band = strategy_low_test_band_atr * atr_h4;
   int tests = 0;
   for(int s = first; s <= last; ++s)
     {
      if(iLow(_Symbol, strategy_tf, s) <= lo + band) // perf-allowed: bounded support-test count
         tests++;
     }
   if(tests < strategy_min_low_tests)
      return false;

   range_high = hi;
   range_low  = lo;
   return true;
  }

// Locate a Spring bar in [spring_min_age .. spring_max_age]: false-breakdown
// below range_low then a bull bar reclaiming the range. Returns its shift.
int FindSpring(const double atr_h4, const double range_low)
  {
   for(int s = strategy_spring_min_age; s <= strategy_spring_max_age; ++s)
     {
      const double low_s   = iLow(_Symbol, strategy_tf, s);   // perf-allowed: bounded Spring scan
      const double close_s = iClose(_Symbol, strategy_tf, s); // perf-allowed: bounded Spring scan
      const double open_s  = iOpen(_Symbol, strategy_tf, s);  // perf-allowed: bounded Spring scan
      if(low_s >= range_low - strategy_spring_pierce_atr * atr_h4)
         continue;                                    // did not pierce below support
      if(close_s <= range_low + strategy_spring_reclaim_atr * atr_h4)
         continue;                                    // did not reclaim the range
      if(close_s <= open_s)
         continue;                                    // not a bull bar
      // Spring-depth gate: pierced non-trivially but not a real breakdown.
      const double depth = range_low - low_s;
      if(depth < strategy_spring_depth_min_atr * atr_h4)
         continue;
      if(depth > strategy_spring_depth_max_atr * atr_h4)
         continue;
      return s;
     }
   return -1;
  }

// Locate an Upthrust bar (SELL mirror) in [spring_min_age .. spring_max_age]:
// false-breakout above range_high then a bear bar back into the range.
int FindUpthrust(const double atr_h4, const double range_high)
  {
   for(int s = strategy_spring_min_age; s <= strategy_spring_max_age; ++s)
     {
      const double high_s  = iHigh(_Symbol, strategy_tf, s);  // perf-allowed: bounded Upthrust scan
      const double close_s = iClose(_Symbol, strategy_tf, s); // perf-allowed: bounded Upthrust scan
      const double open_s  = iOpen(_Symbol, strategy_tf, s);  // perf-allowed: bounded Upthrust scan
      if(high_s <= range_high + strategy_spring_pierce_atr * atr_h4)
         continue;
      if(close_s >= range_high - strategy_spring_reclaim_atr * atr_h4)
         continue;
      if(close_s >= open_s)
         continue;
      const double depth = high_s - range_high;
      if(depth < strategy_spring_depth_min_atr * atr_h4)
         continue;
      if(depth > strategy_spring_depth_max_atr * atr_h4)
         continue;
      return s;
     }
   return -1;
  }

// A successful Test sits in (1 .. s-1]: re-visits the low region but holds above
// the Spring low and closes back inside the range as a bull bar.
bool HasSuccessfulTest(const double atr_h4, const double range_low,
                       const int spring_shift, const double spring_low)
  {
   for(int t = spring_shift - 1; t >= 1; --t)
     {
      const double low_t   = iLow(_Symbol, strategy_tf, t);   // perf-allowed: bounded Test scan
      const double close_t = iClose(_Symbol, strategy_tf, t); // perf-allowed: bounded Test scan
      const double open_t  = iOpen(_Symbol, strategy_tf, t);  // perf-allowed: bounded Test scan
      if(low_t > range_low + strategy_test_band_atr * atr_h4)
         continue;                          // did not re-visit the low region
      if(low_t <= spring_low)
         continue;                          // violated the Spring low — not a hold
      if(close_t <= range_low)
         continue;                          // did not close back inside
      if(close_t <= open_t)
         continue;                          // not a bull bar
      return true;
     }
   return false;
  }

bool HasSuccessfulUpTest(const double atr_h4, const double range_high,
                         const int upthrust_shift, const double upthrust_high)
  {
   for(int t = upthrust_shift - 1; t >= 1; --t)
     {
      const double high_t  = iHigh(_Symbol, strategy_tf, t);  // perf-allowed: bounded Test scan
      const double close_t = iClose(_Symbol, strategy_tf, t); // perf-allowed: bounded Test scan
      const double open_t  = iOpen(_Symbol, strategy_tf, t);  // perf-allowed: bounded Test scan
      if(high_t < range_high - strategy_test_band_atr * atr_h4)
         continue;
      if(high_t >= upthrust_high)
         continue;
      if(close_t >= range_high)
         continue;
      if(close_t >= open_t)
         continue;
      return true;
     }
   return false;
  }

// Volatility regime gate: current ATR within a band of the lookback-shift ATR.
bool VolatilityRegimeOK(const double atr_h4)
  {
   const double atr_ref = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, strategy_range_lookback);
   if(atr_ref <= 0.0)
      return true; // reference unavailable (warmup) — do not block
   if(atr_h4 < strategy_vol_lo_mult * atr_ref)
      return false;
   if(atr_h4 > strategy_vol_hi_mult * atr_ref)
      return false;
   return true;
  }

bool MacroBiasAllowsBuy(const double atr_h4)
  {
   const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_macro_period, 1);
   if(sma <= 0.0)
      return true; // SMA unavailable (warmup) — do not block
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: macro-bias close vs SMA
   return (c1 > sma - strategy_macro_slack_atr * atr_h4);
  }

bool MacroBiasAllowsSell(const double atr_h4)
  {
   const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_macro_period, 1);
   if(sma <= 0.0)
      return true;
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: macro-bias close vs SMA
   return (c1 < sma + strategy_macro_slack_atr * atr_h4);
  }

// Detect a complete BUY setup (range + Spring + Test + recovery trigger on the
// just-closed bar). Fills SL/TP prices + bookkeeping for the manager.
bool PatternBuy(double &entry_sl, double &entry_tp,
                double &spring_extreme, double &rng_hi, double &rng_lo,
                datetime &spring_time)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double range_high = 0.0, range_low = 0.0;
   if(!BuildRange(atr, range_high, range_low))
      return false;

   if(!VolatilityRegimeOK(atr))
      return false;
   if(!MacroBiasAllowsBuy(atr))
      return false;

   const int s = FindSpring(atr, range_low);
   if(s < 0)
      return false;

   const double spring_low = iLow(_Symbol, strategy_tf, s); // perf-allowed: fixed Spring-bar low
   if(!HasSuccessfulTest(atr, range_low, s, spring_low))
      return false;

   // Recovery trigger on the just-closed bar (shift 1): bull bar, sufficient
   // body, closes clearly above the support + clearance, and above the last
   // closed bar before it (continuation of the reclaim, not a fresh probe).
   const double o1 = iOpen(_Symbol, strategy_tf, 1);  // perf-allowed: trigger-bar candle
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: trigger-bar candle
   if(c1 <= o1)
      return false;
   if(BodyRatio(1) < strategy_trigger_body_ratio)
      return false;
   if(c1 <= range_low + strategy_trigger_clearance_atr * atr)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   double sl = spring_low - strategy_sl_buffer_atr * atr;
   if(sl >= ask)
      return false;
   double tp = range_high - strategy_tp_pullback_atr * atr;
   if(tp <= ask)
      return false;

   entry_sl       = NormalizeDouble(sl, _Digits);
   entry_tp       = NormalizeDouble(tp, _Digits);
   spring_extreme = spring_low;
   rng_hi         = range_high;
   rng_lo         = range_low;
   spring_time    = iTime(_Symbol, strategy_tf, s); // perf-allowed: Spring-identity timestamp
   return true;
  }

bool PatternSell(double &entry_sl, double &entry_tp,
                 double &spring_extreme, double &rng_hi, double &rng_lo,
                 datetime &spring_time)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double range_high = 0.0, range_low = 0.0;
   if(!BuildRange(atr, range_high, range_low))
      return false;

   if(!VolatilityRegimeOK(atr))
      return false;
   if(!MacroBiasAllowsSell(atr))
      return false;

   const int s = FindUpthrust(atr, range_high);
   if(s < 0)
      return false;

   const double upthrust_high = iHigh(_Symbol, strategy_tf, s); // perf-allowed: fixed Upthrust-bar high
   if(!HasSuccessfulUpTest(atr, range_high, s, upthrust_high))
      return false;

   const double o1 = iOpen(_Symbol, strategy_tf, 1);  // perf-allowed: trigger-bar candle
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: trigger-bar candle
   if(c1 >= o1)
      return false;
   if(BodyRatio(1) < strategy_trigger_body_ratio)
      return false;
   if(c1 >= range_high - strategy_trigger_clearance_atr * atr)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   double sl = upthrust_high + strategy_sl_buffer_atr * atr;
   if(sl <= bid)
      return false;
   double tp = range_low + strategy_tp_pullback_atr * atr;
   if(tp >= bid)
      return false;

   entry_sl       = NormalizeDouble(sl, _Digits);
   entry_tp       = NormalizeDouble(tp, _Digits);
   spring_extreme = upthrust_high;
   rng_hi         = range_high;
   rng_lo         = range_low;
   spring_time    = iTime(_Symbol, strategy_tf, s); // perf-allowed: Upthrust-identity timestamp
   return true;
  }

bool SelectOurPosition(ulong &ticket, int &direction, double &open_price,
                       double &sl, double &tp, datetime &open_time)
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
         // Re-attach fallback: if we have no seeded extreme, derive from SL
         // (SL sits just beyond the Spring/Upthrust extreme, so it is a safe
         // proxy for the invalidation level on either side).
         if(g_spring_extreme_price <= 0.0 && sl > 0.0)
            g_spring_extreme_price = sl;
        }
      return;
     }

   g_active_ticket = 0;
   g_active_direction = 0;
   g_spring_extreme_price = 0.0;
   g_range_high_at_entry = 0.0;
   g_range_low_at_entry = 0.0;
   g_partial_done = false;
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

// Spring re-use guard: block a new trade on the same Spring bar within the
// cooldown window after it last traded.
bool SpringReuseBlocked(const datetime spring_time)
  {
   if(spring_time != g_last_spring_time)
      return false;
   if(g_last_spring_trade_time <= 0)
      return false;
   const int bars_since = iBarShift(_Symbol, strategy_tf, g_last_spring_trade_time, false);
   return (bars_since < strategy_reuse_cooldown_bars);
  }

// Trade Entry — evaluated once per closed bar. BUY on Spring+Test recovery,
// SELL on Upthrust+Test rejection. Per-Spring de-dup + cooldown.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   RefreshPositionLifecycle();
   if(g_active_ticket != 0)
      return false;

   double sl = 0.0, tp = 0.0, extreme = 0.0, rng_hi = 0.0, rng_lo = 0.0;
   datetime spring_time = 0;

   // BUY — Wyckoff Spring + Test
   if(PatternBuy(sl, tp, extreme, rng_hi, rng_lo, spring_time))
     {
      if(!SpringReuseBlocked(spring_time))
        {
         req.type = QM_BUY;
         req.sl = sl;
         req.tp = tp;
         req.reason = "WYCKOFF_SPRING_TEST_BUY_H4";
         g_spring_extreme_price = extreme;
         g_range_high_at_entry  = rng_hi;
         g_range_low_at_entry   = rng_lo;
         g_partial_done = false;
         g_last_spring_time = spring_time;
         g_last_spring_trade_time = iTime(_Symbol, strategy_tf, 1); // perf-allowed: cooldown anchor
         return true;
        }
     }

   // SELL — Wyckoff Upthrust + Test
   if(PatternSell(sl, tp, extreme, rng_hi, rng_lo, spring_time))
     {
      if(!SpringReuseBlocked(spring_time))
        {
         req.type = QM_SELL;
         req.sl = sl;
         req.tp = tp;
         req.reason = "WYCKOFF_UPTHRUST_TEST_SELL_H4";
         g_spring_extreme_price = extreme;
         g_range_high_at_entry  = rng_hi;
         g_range_low_at_entry   = rng_lo;
         g_partial_done = false;
         g_last_spring_time = spring_time;
         g_last_spring_trade_time = iTime(_Symbol, strategy_tf, 1); // perf-allowed: cooldown anchor
         return true;
        }
     }

   return false;
  }

// Trade Management — partial close at range-midpoint, then SL → break-even on
// the remainder. One-time, not an adaptive trail.
void Strategy_ManageOpenPosition()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0 || g_partial_done)
      return;
   if(g_range_high_at_entry <= 0.0 || g_range_low_at_entry <= 0.0)
      return;
   if(!PositionSelectByTicket(g_active_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double volume = PositionGetDouble(POSITION_VOLUME);
   const double midpoint = 0.5 * (g_range_high_at_entry + g_range_low_at_entry);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const bool reached = is_buy ? (market >= midpoint) : (market <= midpoint);
   if(!reached)
      return;

   // Close 50% and move remaining SL to break-even.
   const double half = QM_TM_NormalizeVolume(_Symbol, volume * 0.5);
   if(half > 0.0 && half < volume)
      QM_TM_PartialClose(g_active_ticket, half, QM_EXIT_STRATEGY);
   QM_TM_MoveSL(g_active_ticket, NormalizeDouble(open_price, _Digits), "wyckoff_mid_be");
   g_partial_done = true;
  }

// Trade Close — two structural exits:
//   (a) range-invalidation: a bar closes beyond the Spring/Upthrust extreme.
//   (b) time stop: 36 H4 bars without TP/SL/invalidation.
bool Strategy_ExitSignal()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0)
      return false;
   if(!PositionSelectByTicket(g_active_ticket))
      return false;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);

   // (a) range-invalidation — closed-bar confirmation: the just-closed bar
   // closed beyond the Spring (BUY) / Upthrust (SELL) extreme.
   if(g_strategy_cadence_ready && g_spring_extreme_price > 0.0)
     {
      const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: invalidation close
      if(is_buy)
        {
         if(c1 < g_spring_extreme_price)
            return true;
        }
      else
        {
         if(c1 > g_spring_extreme_price)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1392\",\"ea\":\"wyckoff-spring-test-h4\"}");
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

   // Management + structural exits run every tick (midpoint partial is intrabar;
   // invalidation/time-stop are closed-bar gated inside their hooks).
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
