#property strict
#property version   "5.0"
#property description "QM5_11016 the5ers-fib-breaker — London D1-bias H1 Fibonacci breaker (H1)"

#include <QM/QM_Common.mqh>
#include <QM/QM_DSTAware.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11016 the5ers-fib-breaker
// -----------------------------------------------------------------------------
// Source: The5ers blog "The Most Important Thing in Forex is not Risking too
//   Much" (interview, Billy A.). Source id 1d445184-7c47-57da-9856-a123682a932d.
// Card: artifacts/cards_approved/QM5_11016_the5ers-fib-breaker.md (g0 APPROVED).
//
// Mechanics (H1 entries with D1 bias; all reads on CLOSED bars at shift>=1):
//
//   D1 BIAS (cached per closed H1 bar from closed D1 bars):
//     Bullish: close(D1,1) > EMA(D1, ema_bias_period) AND the latest confirmed
//              D1 swing high > previous D1 swing high AND latest D1 swing low >
//              previous D1 swing low.
//     Bearish: mirror (below EMA, lower-high + lower-low structure).
//     Neutral otherwise -> no trades.
//
//   H1 IMPULSE + FIB (cached per closed H1 bar via deterministic fractal swings):
//     Confirmed H1 swing pivots use a symmetric fractal of `swing_fractal_k`
//     bars on each side, so a pivot at shift s is only "confirmed" once
//     swing_fractal_k bars have closed after it. The latest impulse leg in the
//     bias direction is anchored to the two most recent CONFIRMED opposing
//     pivots (bull: swing low -> later swing high; bear: swing high -> later
//     swing low). Fibonacci retracement is drawn over that leg.
//
//   ENTRY (long shown; short mirrored):
//     - D1 bias bullish.
//     - Price has retraced into the [fib_lo, fib_hi] zone of the impulse
//       (default 50.0%-61.8%).
//     - Bullish breaker: the signal bar (shift 1) closes ABOVE the high of the
//       last bearish H1 candle that printed inside the retracement zone.
//     - Signal bar is bullish and closes in its top (1-signal_close_frac) range.
//     Order is sent at the next H1 open (the build fires on the new closed bar,
//     framework opens at market = the new bar's open tick).
//
//   STOP: long -> retracement swing low - sl_atr_mult*ATR(H1); short mirrored.
//   TAKE: rr_target R (default 2.0R) from the structural stop distance.
//   EXITS (per-tick discretionary, separate from SL/TP):
//     - Signal failure: H1 closes beyond the 61.8% retracement against us.
//     - Time stop: position older than time_stop_bars H1 bars.
//
//   FILTERS:
//     - London session only (broker-time window derived from UK local hours,
//       DST-aware), O(1) per tick.
//     - Skip impulse smaller than min_impulse_atr_mult*ATR(H1).
//     - Skip if retracement took longer than max_retrace_bars after the extreme.
//     - One position per magic; no pyramiding.
//     - Spread guard fails OPEN on .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs + the cached-state helpers are
// EA-specific. Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11016;
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
// --- D1 bias ---
input int    strategy_ema_bias_period   = 50;     // D1 EMA bias period {20,50,100}
input int    strategy_d1_fractal_k      = 2;      // D1 swing fractal half-width
// --- H1 swing / impulse / fib ---
input int    strategy_swing_fractal_k   = 2;      // H1 swing fractal half-width
input int    strategy_swing_scan_bars   = 90;     // H1 bars to scan for pivots
input double strategy_fib_lo            = 50.0;   // retrace zone lower % (of impulse)
input double strategy_fib_hi            = 61.8;   // retrace zone upper %
input double strategy_min_impulse_atr   = 2.0;    // skip impulse < mult*ATR(H1)
input int    strategy_max_retrace_bars  = 24;     // skip retrace older than N H1 bars
// --- stop / target / exits ---
input int    strategy_atr_period        = 14;     // ATR(H1) period for stop buffer
input double strategy_sl_atr_mult       = 0.5;    // stop buffer = mult*ATR beyond swing
input double strategy_rr_target         = 2.0;    // take profit = N*R
input int    strategy_time_stop_bars    = 30;     // close after N H1 bars
input double strategy_signal_close_frac = 0.60;   // signal bar must close in top/bot (1-frac)
// --- session (UK local hours; converted to broker time, DST-aware) ---
input int    strategy_london_start_uk   = 8;      // London open, UK local hour
input int    strategy_london_end_uk     = 16;     // London close, UK local hour
// --- spread guard ---
input double strategy_spread_pct_of_stop = 20.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached structural state — advanced ONCE per closed H1 bar.
// Strategy_EntrySignal runs only on the closed-bar path (OnTick gates it behind
// QM_IsNewBar), so it is the single place we recompute structure. The per-tick
// hooks (NoTradeFilter, ManageOpenPosition, ExitSignal) read O(1) cached values.
// -----------------------------------------------------------------------------
int      g_bias              = 0;     // +1 bull / -1 bear / 0 neutral
double   g_impulse_start     = 0.0;   // impulse anchor (bull: swing low; bear: swing high)
double   g_impulse_end       = 0.0;   // impulse extreme (bull: swing high; bear: swing low)
int      g_impulse_end_shift = -1;    // bar shift of the impulse extreme (>=1) when computed
double   g_fib_zone_near     = 0.0;   // retrace zone bound nearer the extreme (fib_lo level)
double   g_fib_zone_far      = 0.0;   // retrace zone bound farther from extreme (fib_hi level)
double   g_fib_618           = 0.0;   // exact 61.8% retracement price (signal-failure line)
double   g_atr_h1            = 0.0;   // cached ATR(H1) at shift 1
double   g_entry_bar_time    = 0;     // bar-open time of the bar we entered on (time stop)

// -----------------------------------------------------------------------------
// Deterministic confirmed-fractal swing detection on closed bars.
// Returns the shift of the most recent CONFIRMED swing HIGH at or beyond
// `from_shift`, scanning up to `scan_bars`. A confirmed swing high at center
// shift c requires high(c) strictly greater than the k bars on each side, and
// c >= 1 + k so that k bars have closed after it. -1 if none found.
// (perf-allowed: bounded scan, runs once per closed bar inside EntrySignal.)
// -----------------------------------------------------------------------------
int FindSwingHighShift(const int from_shift, const int k, const int scan_bars)
  {
   const int first = (from_shift > (1 + k)) ? from_shift : (1 + k);
   const int last  = first + scan_bars;
   for(int c = first; c <= last; ++c)
     {
      const double hc = iHigh(_Symbol, _Period, c); // perf-allowed: bounded closed-bar scan
      if(hc <= 0.0)
         continue;
      bool is_pivot = true;
      for(int j = 1; j <= k; ++j)
        {
         const double hl = iHigh(_Symbol, _Period, c - j);
         const double hr = iHigh(_Symbol, _Period, c + j);
         if(hl <= 0.0 || hr <= 0.0 || hc <= hl || hc <= hr)
           {
            is_pivot = false;
            break;
           }
        }
      if(is_pivot)
         return c;
     }
   return -1;
  }

int FindSwingLowShift(const int from_shift, const int k, const int scan_bars)
  {
   const int first = (from_shift > (1 + k)) ? from_shift : (1 + k);
   const int last  = first + scan_bars;
   for(int c = first; c <= last; ++c)
     {
      const double lc = iLow(_Symbol, _Period, c); // perf-allowed: bounded closed-bar scan
      if(lc <= 0.0)
         continue;
      bool is_pivot = true;
      for(int j = 1; j <= k; ++j)
        {
         const double ll = iLow(_Symbol, _Period, c - j);
         const double lr = iLow(_Symbol, _Period, c + j);
         if(ll <= 0.0 || lr <= 0.0 || lc >= ll || lc >= lr)
           {
            is_pivot = false;
            break;
           }
        }
      if(is_pivot)
         return c;
     }
   return -1;
  }

// D1 swing helpers (operate on the D1 timeframe of the same symbol).
int FindD1SwingHighShift(const int from_shift, const int k, const int scan_bars)
  {
   const int first = (from_shift > (1 + k)) ? from_shift : (1 + k);
   const int last  = first + scan_bars;
   for(int c = first; c <= last; ++c)
     {
      const double hc = iHigh(_Symbol, PERIOD_D1, c); // perf-allowed: bounded closed D1 scan
      if(hc <= 0.0)
         continue;
      bool is_pivot = true;
      for(int j = 1; j <= k; ++j)
        {
         const double hl = iHigh(_Symbol, PERIOD_D1, c - j);
         const double hr = iHigh(_Symbol, PERIOD_D1, c + j);
         if(hl <= 0.0 || hr <= 0.0 || hc <= hl || hc <= hr)
           {
            is_pivot = false;
            break;
           }
        }
      if(is_pivot)
         return c;
     }
   return -1;
  }

int FindD1SwingLowShift(const int from_shift, const int k, const int scan_bars)
  {
   const int first = (from_shift > (1 + k)) ? from_shift : (1 + k);
   const int last  = first + scan_bars;
   for(int c = first; c <= last; ++c)
     {
      const double lc = iLow(_Symbol, PERIOD_D1, c); // perf-allowed: bounded closed D1 scan
      if(lc <= 0.0)
         continue;
      bool is_pivot = true;
      for(int j = 1; j <= k; ++j)
        {
         const double ll = iLow(_Symbol, PERIOD_D1, c - j);
         const double lr = iLow(_Symbol, PERIOD_D1, c + j);
         if(ll <= 0.0 || lr <= 0.0 || lc >= ll || lc >= lr)
           {
            is_pivot = false;
            break;
           }
        }
      if(is_pivot)
         return c;
     }
   return -1;
  }

// Compute D1 bias (+1/-1/0) from closed D1 bars. Cheap bounded scan; called
// once per closed H1 bar.
int ComputeD1Bias()
  {
   const double close_d1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed D1 read
   if(close_d1 <= 0.0)
      return 0;
   const double ema_d1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_bias_period, 1);
   if(ema_d1 <= 0.0)
      return 0;

   const int k = strategy_d1_fractal_k;
   const int scan = 40; // up to ~40 confirmed-pivot search depth on D1

   const int sh1 = FindD1SwingHighShift(1, k, scan);
   if(sh1 < 0)
      return 0;
   const int sh2 = FindD1SwingHighShift(sh1 + 1, k, scan);
   if(sh2 < 0)
      return 0;
   const int sl1 = FindD1SwingLowShift(1, k, scan);
   if(sl1 < 0)
      return 0;
   const int sl2 = FindD1SwingLowShift(sl1 + 1, k, scan);
   if(sl2 < 0)
      return 0;

   const double hi_latest = iHigh(_Symbol, PERIOD_D1, sh1);
   const double hi_prev   = iHigh(_Symbol, PERIOD_D1, sh2);
   const double lo_latest = iLow(_Symbol, PERIOD_D1, sl1);
   const double lo_prev   = iLow(_Symbol, PERIOD_D1, sl2);
   if(hi_latest <= 0.0 || hi_prev <= 0.0 || lo_latest <= 0.0 || lo_prev <= 0.0)
      return 0;

   const bool higher_structure = (hi_latest > hi_prev && lo_latest > lo_prev);
   const bool lower_structure  = (hi_latest < hi_prev && lo_latest < lo_prev);

   if(close_d1 > ema_d1 && higher_structure)
      return +1;
   if(close_d1 < ema_d1 && lower_structure)
      return -1;
   return 0;
  }

// Recompute the cached H1 impulse + Fibonacci structure for the current bias.
// Returns true if a valid impulse leg + fib zone was found and cached.
bool RecomputeStructure()
  {
   g_impulse_start     = 0.0;
   g_impulse_end       = 0.0;
   g_impulse_end_shift = -1;
   g_fib_zone_near     = 0.0;
   g_fib_zone_far      = 0.0;
   g_fib_618           = 0.0;

   g_atr_h1 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(g_atr_h1 <= 0.0)
      return false;

   const int k    = strategy_swing_fractal_k;
   const int scan = strategy_swing_scan_bars;

   if(g_bias > 0)
     {
      // Bullish impulse: most recent confirmed swing HIGH (extreme/end), with a
      // confirmed swing LOW that occurred BEFORE it (start anchor).
      const int sh_end = FindSwingHighShift(1, k, scan);
      if(sh_end < 0)
         return false;
      const int sl_start = FindSwingLowShift(sh_end + 1, k, scan);
      if(sl_start < 0)
         return false;

      const double end_price   = iHigh(_Symbol, _Period, sh_end);
      const double start_price = iLow(_Symbol, _Period, sl_start);
      if(end_price <= 0.0 || start_price <= 0.0 || end_price <= start_price)
         return false;

      const double leg = end_price - start_price;
      if(leg < strategy_min_impulse_atr * g_atr_h1)
         return false;

      // Retracement age: bars since the impulse extreme must be within window.
      if((sh_end - 1) > strategy_max_retrace_bars)
         return false;

      g_impulse_start     = start_price;
      g_impulse_end       = end_price;
      g_impulse_end_shift = sh_end;
      // For a bull leg, retracement DOWN from the high: deeper retrace = lower
      // price. near = shallow bound (fib_lo), far = deep bound (fib_hi).
      g_fib_zone_near = end_price - (strategy_fib_lo / 100.0) * leg;
      g_fib_zone_far  = end_price - (strategy_fib_hi / 100.0) * leg;
      g_fib_618       = end_price - 0.618 * leg;
      return true;
     }

   if(g_bias < 0)
     {
      // Bearish impulse: most recent confirmed swing LOW (extreme/end), with a
      // confirmed swing HIGH that occurred BEFORE it (start anchor).
      const int sl_end = FindSwingLowShift(1, k, scan);
      if(sl_end < 0)
         return false;
      const int sh_start = FindSwingHighShift(sl_end + 1, k, scan);
      if(sh_start < 0)
         return false;

      const double end_price   = iLow(_Symbol, _Period, sl_end);
      const double start_price = iHigh(_Symbol, _Period, sh_start);
      if(end_price <= 0.0 || start_price <= 0.0 || start_price <= end_price)
         return false;

      const double leg = start_price - end_price;
      if(leg < strategy_min_impulse_atr * g_atr_h1)
         return false;

      if((sl_end - 1) > strategy_max_retrace_bars)
         return false;

      g_impulse_start     = start_price;
      g_impulse_end       = end_price;
      g_impulse_end_shift = sl_end;
      // Bear leg, retracement UP from the low: deeper retrace = higher price.
      g_fib_zone_near = end_price + (strategy_fib_lo / 100.0) * leg;
      g_fib_zone_far  = end_price + (strategy_fib_hi / 100.0) * leg;
      g_fib_618       = end_price + 0.618 * leg;
      return true;
     }

   return false;
  }

// Within the cached retracement zone, find the breaker reference: the extreme
// (high for long / low for short) of the last opposite-colour candle that
// printed inside the zone, scanning shifts 1..g_impulse_end_shift-1.
// Returns true and sets `ref` if found.
bool FindBreakerRef(const bool want_long, double &ref)
  {
   ref = 0.0;
   const double zlo = (g_fib_zone_far < g_fib_zone_near) ? g_fib_zone_far : g_fib_zone_near;
   const double zhi = (g_fib_zone_far < g_fib_zone_near) ? g_fib_zone_near : g_fib_zone_far;
   const int last = (g_impulse_end_shift > 1) ? (g_impulse_end_shift - 1) : 1;
   for(int s = 1; s <= last; ++s)
     {
      const double o = iOpen(_Symbol, _Period, s);  // perf-allowed: bounded closed-bar scan
      const double c = iClose(_Symbol, _Period, s);
      const double h = iHigh(_Symbol, _Period, s);
      const double l = iLow(_Symbol, _Period, s);
      if(o <= 0.0 || c <= 0.0)
         continue;
      // candle must intersect the retracement zone
      if(h < zlo || l > zhi)
         continue;
      if(want_long)
        {
         if(c < o) // bearish candle inside the zone
           {
            ref = h; // breaker reference = its high
            return true;
           }
        }
      else
        {
         if(c > o) // bullish candle inside the zone
           {
            ref = l; // breaker reference = its low
            return true;
           }
        }
     }
   return false;
  }

// UK DST offset (hours) for a given UTC instant: +1 between last Sunday of
// March 01:00 UTC and last Sunday of October 01:00 UTC, else +0.
int UKOffsetHoursForUTC(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   const int y = dt.year;

   const int mar_day = QM_DSTAware_NthWeekdayOfMonth(y, 3, SUNDAY, 5) > 0
                       ? QM_DSTAware_NthWeekdayOfMonth(y, 3, SUNDAY, 5)
                       : QM_DSTAware_NthWeekdayOfMonth(y, 3, SUNDAY, 4);
   const int oct_day = QM_DSTAware_NthWeekdayOfMonth(y, 10, SUNDAY, 5) > 0
                       ? QM_DSTAware_NthWeekdayOfMonth(y, 10, SUNDAY, 5)
                       : QM_DSTAware_NthWeekdayOfMonth(y, 10, SUNDAY, 4);

   MqlDateTime ds;
   ZeroMemory(ds);
   ds.year = y; ds.mon = 3; ds.day = mar_day; ds.hour = 1;
   const datetime start_utc = StructToTime(ds);

   MqlDateTime de;
   ZeroMemory(de);
   de.year = y; de.mon = 10; de.day = oct_day; de.hour = 1;
   const datetime end_utc = StructToTime(de);

   if(start_utc == 0 || end_utc == 0)
      return 0;
   return (utc >= start_utc && utc < end_utc) ? 1 : 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: London session window (broker time, DST-aware) +
// spread guard (fail-open on .DWX zero modeled spread).
bool Strategy_NoTradeFilter()
  {
   // --- London session in broker time. UK local -> UTC (UK DST last-Sun-Mar..
   //     last-Sun-Oct) -> broker time. We derive the broker-time window for the
   //     CURRENT day from the UK local start/end hours. ---
   const datetime broker_now = TimeCurrent();
   const datetime utc_now    = QM_BrokerToUTC(broker_now);
   MqlDateTime u;
   ZeroMemory(u);
   TimeToStruct(utc_now, u);
   const int uk_offset = UKOffsetHoursForUTC(utc_now); // +0 winter / +1 summer
   // broker hour = utc hour + broker_offset; uk local hour = utc hour + uk_offset.
   // So broker hour for a given uk local hour H = H - uk_offset + broker_offset.
   const int broker_offset = QM_IsUSDSTUTC(utc_now) ? 3 : 2;
   int start_broker = strategy_london_start_uk - uk_offset + broker_offset;
   int end_broker   = strategy_london_end_uk   - uk_offset + broker_offset;
   // normalize to [0,24)
   start_broker = ((start_broker % 24) + 24) % 24;
   end_broker   = ((end_broker   % 24) + 24) % 24;

   MqlDateTime b;
   ZeroMemory(b);
   TimeToStruct(broker_now, b);
   const int h = b.hour;
   bool in_session;
   if(start_broker <= end_broker)
      in_session = (h >= start_broker && h < end_broker);
   else
      in_session = (h >= start_broker || h < end_broker); // wrap-safe
   if(!in_session)
      return true;

   // --- Spread guard (fail-open on zero modeled spread) ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block
   if(g_atr_h1 > 0.0)
     {
      const double stop_distance = strategy_sl_atr_mult * g_atr_h1;
      const double spread = ask - bid;
      if(stop_distance > 0.0 && spread > 0.0 &&
         spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
         return true;
     }
   return false;
  }

// Entry — closed-bar path (OnTick gates this behind QM_IsNewBar). This is the
// single place structure is recomputed; cached values feed the per-tick hooks.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Refresh bias + structure once per closed H1 bar (bounded scans).
   g_bias = ComputeD1Bias();
   const bool have_structure = RecomputeStructure();

   // One open position per symbol/magic; no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_bias == 0 || !have_structure)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double open1  = iOpen(_Symbol, _Period, 1);
   const double high1  = iHigh(_Symbol, _Period, 1);
   const double low1   = iLow(_Symbol, _Period, 1);
   if(close1 <= 0.0 || open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;
   const double range1 = high1 - low1;
   if(range1 <= 0.0)
      return false;

   const double zlo = (g_fib_zone_far < g_fib_zone_near) ? g_fib_zone_far : g_fib_zone_near;
   const double zhi = (g_fib_zone_far < g_fib_zone_near) ? g_fib_zone_near : g_fib_zone_far;

   if(g_bias > 0)
     {
      // Signal bar must have retraced into the zone (its low touched the zone).
      if(!(low1 <= zhi && low1 >= zlo) && !(close1 >= zlo && close1 <= zhi))
         return false;
      // Bullish breaker reference: last bearish candle inside the zone.
      double breaker_ref = 0.0;
      if(!FindBreakerRef(true, breaker_ref))
         return false;
      // Signal bar closes ABOVE that high (the breaker).
      if(!(close1 > breaker_ref))
         return false;
      // Signal bar bullish and closes in top (1 - signal_close_frac) of range.
      if(!(close1 > open1))
         return false;
      const double close_pos = (close1 - low1) / range1; // 1 = at high
      if(close_pos < strategy_signal_close_frac)
         return false;

      // Structural stop: below the impulse swing low minus ATR buffer.
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, g_impulse_start, g_atr_h1, strategy_sl_atr_mult);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_rr_target);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0; // market at next-bar open tick
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "fib_breaker_long";
      g_entry_bar_time = iTime(_Symbol, _Period, 0); // current (new) bar open time
      return true;
     }

   // g_bias < 0 — short
   if(!(high1 >= zlo && high1 <= zhi) && !(close1 >= zlo && close1 <= zhi))
      return false;
   double breaker_ref_s = 0.0;
   if(!FindBreakerRef(false, breaker_ref_s))
      return false;
   if(!(close1 < breaker_ref_s))
      return false;
   if(!(close1 < open1))
      return false;
   const double close_pos_s = (high1 - close1) / range1; // 1 = at low
   if(close_pos_s < strategy_signal_close_frac)
      return false;

   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;
   const double sl_s = QM_StopATRFromValue(_Symbol, QM_SELL, g_impulse_start, g_atr_h1, strategy_sl_atr_mult);
   if(sl_s <= 0.0 || sl_s <= entry_s)
      return false;
   const double tp_s = QM_TakeRR(_Symbol, QM_SELL, entry_s, sl_s, strategy_rr_target);
   if(tp_s <= 0.0)
      return false;

   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl_s;
   req.tp     = tp_s;
   req.reason = "fib_breaker_short";
   g_entry_bar_time = iTime(_Symbol, _Period, 0);
   return true;
  }

// Fixed structural stop/target; no active trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits (per-tick): signal failure (H1 close beyond 61.8% against
// us) and time stop (older than time_stop_bars H1 bars). O(1) — reads cached
// fib level + the last closed bar only.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // Determine our open direction.
   const int magic = QM_FrameworkMagic();
   bool is_long = false;
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found = true;
      break;
     }
   if(!found)
      return false;

   // Time stop: bars elapsed since entry bar.
   if(g_entry_bar_time > 0 && strategy_time_stop_bars > 0)
     {
      const datetime cur_bar = iTime(_Symbol, _Period, 0); // perf-allowed: bar-open time
      const long secs = (long)(cur_bar - g_entry_bar_time);
      const long bar_secs = (long)PeriodSeconds(_Period);
      if(bar_secs > 0 && (secs / bar_secs) >= strategy_time_stop_bars)
         return true;
     }

   // Signal failure: last CLOSED H1 bar closed beyond the 61.8% line against us.
   if(g_fib_618 > 0.0)
     {
      const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
      if(close1 > 0.0)
        {
         if(is_long && close1 < g_fib_618)
            return true;
         if(!is_long && close1 > g_fib_618)
            return true;
        }
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
