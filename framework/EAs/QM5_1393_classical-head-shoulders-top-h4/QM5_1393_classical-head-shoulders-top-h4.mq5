#property strict
#property version   "5.0"
#property description "QM5_1393 Classical Head-and-Shoulders Top (H4) — 5-pivot neckline-break reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1393 Classical Head-and-Shoulders Top — 5-Pivot Reversal (H4)
// -----------------------------------------------------------------------------
// Schabacker 1932 / Edwards-Magee 1948 / Bulkowski 2021 canonical H&S Top.
//
// The H&S Top is a multi-bar STATE: five alternating CLOSED-bar fractal pivots
//   LS (swing-high) -> T1 (swing-low) -> H (swing-high, highest)
//                   -> T2 (swing-low) -> RS (swing-high, ~= LS)
// with a sloped NECKLINE through the two troughs (T1, T2). The neckline break
// (a closed bar closing below the neckline by >= 0.3*ATR_H4) is the single
// trigger EVENT -> market SELL. Target = head-to-neckline pattern height
// projected below the neckline-break point (Edwards & Magee rule).
//
// Detection runs ONLY on closed bars. With a 2-bar fractal wing the newest
// confirmable pivot sits at shift wing+1; the RS must be recent. Eight
// pattern-validity gates (head-dominance, shoulder symmetry, trough symmetry,
// magnitude, time symmetry, prior uptrend, duration, ordering) must all PASS.
//
// Inverse-H&S Bottom (BUY side) is DEFERRED per card § Entry-BUY — this EA is
// SELL-only on the H&S Top.
//
// Layout mirrors sibling QM5_1364 (Brooks double-top/bottom) — same fractal /
// neckline / pattern-height / news / Friday-close cadence; only the pattern
// primitive differs (5 pivots + sloped neckline vs 2 pivots + flat neckline).
//
// .DWX invariants honoured: fail-OPEN spread guard, no swap gate, broker-time
// via framework, prior-CLOSE break (not range), single QM_IsNewBar consume per
// tick (latched), one position per magic, RISK_FIXED, all in-EA (no ML).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1393;
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
input int    strategy_atr_period             = 14;     // ATR(14) on H4 and D1
input int    strategy_sma_fast               = 50;     // SMA(50) H4 macro / prior-uptrend
input int    strategy_sma_slow               = 200;    // SMA(200) H4 macro-bias soft-filter
input int    strategy_lookback_bars          = 200;    // pivot scan window (H4 bars)
input int    strategy_fractal_wing           = 2;      // bars left/right for a confirmed swing pivot
input int    strategy_rs_recency_bars        = 10;     // RS must be within N bars of current
// Pattern-validity gate tolerances (card § Pattern-validity gates)
input double strategy_head_dom_atr_h4        = 0.2;    // H > LS + k*ATR_H4 and H > RS + k*ATR_H4
input double strategy_shoulder_sym_atr_d1    = 0.5;    // |LS-RS| <= k*ATR_D1
input double strategy_trough_sym_atr_d1      = 0.7;    // |T1-T2| <= k*ATR_D1
input double strategy_magnitude_atr_d1       = 1.5;    // H - mean(T1,T2) >= k*ATR_D1
input double strategy_time_sym_lo            = 0.4;    // 0.4 <= (H-LS)/(RS-H) <= 2.5
input double strategy_time_sym_hi            = 2.5;
input int    strategy_duration_min_bars      = 20;     // RS_time - LS_time in [20,100] H4 bars
input int    strategy_duration_max_bars      = 100;
// Neckline-break trigger (card § Entry)
input double strategy_break_buffer_atr_h4    = 0.3;    // close < neckline - k*ATR_H4
input int    strategy_break_recency_bars     = 3;      // break bar within last N H4 bars
input double strategy_break_body_ratio_min   = 0.40;   // break bar body_ratio >= k
input double strategy_started_move_atr_d1    = 1.0;    // H - close[1] >= k*ATR_D1 (move started)
input double strategy_macro_bull_atr_h4      = 5.0;    // close[1] < SMA200 + k*ATR_H4
input double strategy_vol_lo_mult            = 0.7;    // ATR_H4[1] in [lo,hi]*ATR_H4[40]
input double strategy_vol_hi_mult            = 2.5;
input int    strategy_vol_ref_shift          = 40;
input double strategy_vol_shock_mult         = 2.5;    // skip if ATR_H4[1] > k*ATR_H4[60]
input int    strategy_vol_shock_ref_shift    = 60;
// Exit / SL (card § Exit)
input double strategy_sl_buffer_atr_h4       = 0.5;    // SL = max(LS,RS) + k*ATR_H4
input double strategy_partial_height_frac    = 0.5;    // partial+BE at neck - frac*height
input double strategy_neck_reclaim_atr_h4    = 0.5;    // hard-exit if close > neck + k*ATR_H4
input int    strategy_time_stop_bars         = 48;     // ~8 trading days
// Filters (card § Zusatzfilter)
input int    strategy_session_start_hour     = 7;      // broker-hour window [start, end)
input int    strategy_session_end_hour       = 21;
input int    strategy_friday_cutoff_hour     = 16;     // no new entries after this on Friday
input int    strategy_pattern_reuse_bars     = 48;     // same (LS,H,RS) triple cooldown
input int    strategy_freq_cap_bars          = 42;     // ~1 trade per symbol per week (H4)
input double strategy_pullback_tp_cut        = 0.30;   // reduce TP 30% on pullback-retest
input double strategy_spread_mult            = 2.0;
input int    strategy_spread_lookback        = 20;

// ---- file-scope state ------------------------------------------------------
double   g_median_spread_points   = 0.0;
ulong    g_active_ticket          = 0;
double   g_pattern_height_price   = 0.0;  // head-to-neckline height of the open trade
double   g_head_price             = 0.0;  // H price for head-violation hard-exit
double   g_neck_at_break          = 0.0;  // neckline price at break bar (reclaim exit)
double   g_partial_target_price   = 0.0;  // price at which to take partial + BE
bool     g_partial_done           = false;
bool     g_be_done                = false;
bool     g_cadence_ready          = false;
datetime g_last_entry_bar_time    = 0;    // for weekly-frequency cap

// Per-pattern de-dup: identify a pattern by its (LS,H,RS) pivot bar-times.
datetime g_used_ls_time           = 0;
datetime g_used_h_time            = 0;
datetime g_used_rs_time           = 0;
datetime g_used_until_time        = 0;    // reuse cooldown expiry (broker time)

double PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

// shift `s` is a confirmed swing-high fractal: strictly highest over the wing on
// both sides. Both sides are CLOSED bars (caller guarantees s >= wing+1).
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

// Neckline price (linear inter/extrapolation through (T1,price1)+(T2,price2))
// evaluated at the bar with shift `s_eval`. Shifts increase backward in time, so
// older T1 has the larger shift. We interpolate in shift-space (uniform H4 bars).
double NecklineAtShift(const int t1_shift, const double t1_price,
                       const int t2_shift, const double t2_price,
                       const int s_eval)
  {
   const int dshift = t2_shift - t1_shift; // negative (t2 newer => smaller shift)
   if(dshift == 0)
      return t2_price;
   const double slope = (t2_price - t1_price) / (double)dshift;
   return t1_price + slope * (double)(s_eval - t1_shift);
  }

// Find the most-recent valid H&S Top whose neckline broke on bar[1] (the just-
// closed bar). Fills SL/TP prices + pattern bookkeeping. SELL-only.
bool DetectHST(double &entry_sl, double &entry_tp, double &height_out,
               double &head_out, double &neck_at_break_out, double &partial_out,
               datetime &ls_t, datetime &h_t, datetime &rs_t)
  {
   const double atr_h4 = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_h4 <= 0.0 || atr_d1 <= 0.0)
      return false;

   const int wing = strategy_fractal_wing;
   const int first = wing + 1; // newest confirmable pivot shift
   // bound the scan to the lookback window (RS..LS within strategy_lookback_bars)
   int last = strategy_lookback_bars;
   if(last < strategy_duration_max_bars + 4 * wing + 5)
      last = strategy_duration_max_bars + 4 * wing + 5;

   // --- RS: most-recent confirmed swing-high within recency window ---
   int rs_shift = -1;
   const int rs_search_last = strategy_rs_recency_bars + wing;
   for(int s = first; s <= rs_search_last; ++s)
      if(IsSwingHigh(s)) { rs_shift = s; break; }
   if(rs_shift < 0)
      return false;

   // --- T2: first confirmed swing-low strictly older than RS ---
   int t2_shift = -1;
   for(int s = rs_shift + 1; s <= last; ++s)
      if(IsSwingLow(s)) { t2_shift = s; break; }
   if(t2_shift < 0)
      return false;

   // --- H: first confirmed swing-high strictly older than T2 ---
   int h_shift = -1;
   for(int s = t2_shift + 1; s <= last; ++s)
      if(IsSwingHigh(s)) { h_shift = s; break; }
   if(h_shift < 0)
      return false;

   // --- T1: first confirmed swing-low strictly older than H ---
   int t1_shift = -1;
   for(int s = h_shift + 1; s <= last; ++s)
      if(IsSwingLow(s)) { t1_shift = s; break; }
   if(t1_shift < 0)
      return false;

   // --- LS: first confirmed swing-high strictly older than T1 ---
   int ls_shift = -1;
   for(int s = t1_shift + 1; s <= last; ++s)
      if(IsSwingHigh(s)) { ls_shift = s; break; }
   if(ls_shift < 0)
      return false;

   const double ls = iHigh(_Symbol, strategy_tf, ls_shift); // perf-allowed: fixed closed-bar pivot
   const double t1 = iLow(_Symbol, strategy_tf, t1_shift);  // perf-allowed: fixed closed-bar pivot
   const double h  = iHigh(_Symbol, strategy_tf, h_shift);  // perf-allowed: fixed closed-bar pivot
   const double t2 = iLow(_Symbol, strategy_tf, t2_shift);  // perf-allowed: fixed closed-bar pivot
   const double rs = iHigh(_Symbol, strategy_tf, rs_shift); // perf-allowed: fixed closed-bar pivot

   // (1) ordering guaranteed by construction (ls>t1>h>t2>rs shifts, alternating).

   // (2) head dominance: H strictly highest of the three peaks
   if(h <= ls + strategy_head_dom_atr_h4 * atr_h4)
      return false;
   if(h <= rs + strategy_head_dom_atr_h4 * atr_h4)
      return false;

   // (3) shoulder symmetry
   if(MathAbs(ls - rs) > strategy_shoulder_sym_atr_d1 * atr_d1)
      return false;

   // (4) trough symmetry
   if(MathAbs(t1 - t2) > strategy_trough_sym_atr_d1 * atr_d1)
      return false;

   // (5) magnitude
   const double trough_mean = 0.5 * (t1 + t2);
   if((h - trough_mean) < strategy_magnitude_atr_d1 * atr_d1)
      return false;

   // (6) time symmetry, ratio = (H_time - LS_time) / (RS_time - H_time).
   // Shifts increase backward in time (ls_shift > h_shift > rs_shift), so each
   // positive duration is the OLDER-minus-NEWER shift difference (= bar count).
   const double left_bars  = (double)(ls_shift - h_shift); // H_time - LS_time, in bars
   const double right_bars = (double)(h_shift - rs_shift); // RS_time - H_time, in bars
   if(left_bars <= 0.0 || right_bars <= 0.0)
      return false;
   const double ratio = left_bars / right_bars;
   if(ratio < strategy_time_sym_lo || ratio > strategy_time_sym_hi)
      return false;

   // (7) prior uptrend: SMA(50,H4) at LS_time < SMA(50,H4) at H_time
   const double sma_at_ls = QM_SMA(_Symbol, strategy_tf, strategy_sma_fast, ls_shift);
   const double sma_at_h  = QM_SMA(_Symbol, strategy_tf, strategy_sma_fast, h_shift);
   if(sma_at_ls > 0.0 && sma_at_h > 0.0 && !(sma_at_ls < sma_at_h))
      return false;

   // (8) pattern duration in H4 bars: RS_time - LS_time = ls_shift - rs_shift
   const int duration_bars = ls_shift - rs_shift;
   if(duration_bars < strategy_duration_min_bars || duration_bars > strategy_duration_max_bars)
      return false;

   // ---- Neckline-break trigger (card § Entry 2-4) ----
   // neckline at the break bar shift 1 and confirmation that it is fresh.
   const double neck_at1 = NecklineAtShift(t1_shift, t1, t2_shift, t2, 1);
   const double neck_at2 = NecklineAtShift(t1_shift, t1, t2_shift, t2, 2);
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: neckline-break trigger close
   const double c2 = iClose(_Symbol, strategy_tf, 2); // perf-allowed: prior-close break confirmation
   const double o1 = iOpen(_Symbol, strategy_tf, 1);  // perf-allowed: break-bar body quality
   const double hi1 = iHigh(_Symbol, strategy_tf, 1); // perf-allowed: break-bar body quality
   const double lo1 = iLow(_Symbol, strategy_tf, 1);  // perf-allowed: break-bar body quality

   // confirmed break: bar[1] closes >= 0.3*ATR_H4 below neckline...
   if(c1 >= neck_at1 - strategy_break_buffer_atr_h4 * atr_h4)
      return false;
   // ...and it is the FIRST such close (bar[2] still at/above its neckline).
   if(c2 < neck_at2)
      return false;
   // break recency: bar[1] is within break_recency_bars of RS
   if((rs_shift - 1) > strategy_break_recency_bars)
      return false;

   // (3) break-bar quality: bear bar with body_ratio >= 0.40
   if(c1 >= o1)
      return false;
   const double rng1 = (hi1 - lo1) + 1e-9;
   const double body_ratio = MathAbs(c1 - o1) / rng1;
   if(body_ratio < strategy_break_body_ratio_min)
      return false;

   // (4) post-break confirmation: bar[1] close still below its neckline (raw line)
   if(c1 >= neck_at1)
      return false;

   // (5) magnitude re-check: some decline already materialised
   if((h - c1) < strategy_started_move_atr_d1 * atr_d1)
      return false;

   // (6) macro-bias soft-filter: avoid shorting in a strong bull regime
   const double sma200 = QM_SMA(_Symbol, strategy_tf, strategy_sma_slow, 1);
   if(sma200 > 0.0 && c1 >= sma200 + strategy_macro_bull_atr_h4 * atr_h4)
      return false;

   // (7) volatility gate: ATR_H4[1] within band of ATR_H4[40]
   const double atr_ref = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, strategy_vol_ref_shift);
   if(atr_ref > 0.0)
     {
      if(atr_h4 < strategy_vol_lo_mult * atr_ref || atr_h4 > strategy_vol_hi_mult * atr_ref)
         return false;
     }

   // (volatility regime shock guard, card § Zusatzfilter)
   const double atr_shock_ref = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, strategy_vol_shock_ref_shift);
   if(atr_shock_ref > 0.0 && atr_h4 > strategy_vol_shock_mult * atr_shock_ref)
      return false;

   // ---- SL / TP (card § Exit) ----
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   const double higher_shoulder = MathMax(ls, rs);
   double sl = higher_shoulder + strategy_sl_buffer_atr_h4 * atr_h4;
   if((sl - bid) <= 0.0)
      return false;

   // pattern height = H - mean(T1,T2); TP = neckline(at break) - height
   const double height = h - trough_mean;
   if(height <= 0.0)
      return false;

   double tp_height = height;
   // pullback-retest variant guard: a bar between break and now poked back to the
   // neckline -> reduce TP target by pullback_tp_cut. (break bar is shift 1, so a
   // retest can only exist if the break bar itself wicked back near neckline.)
   if(hi1 > neck_at1 - 0.1 * atr_h4)
      tp_height = height * (1.0 - strategy_pullback_tp_cut);

   const double tp = neck_at1 - tp_height;

   entry_sl          = NormalizeDouble(sl, _Digits);
   entry_tp          = NormalizeDouble(tp, _Digits);
   height_out        = height;
   head_out          = h;
   neck_at_break_out = neck_at1;
   partial_out       = NormalizeDouble(neck_at1 - strategy_partial_height_frac * height, _Digits);
   ls_t              = iTime(_Symbol, strategy_tf, ls_shift); // perf-allowed: pattern-identity timestamp
   h_t               = iTime(_Symbol, strategy_tf, h_shift);  // perf-allowed: pattern-identity timestamp
   rs_t              = iTime(_Symbol, strategy_tf, rs_shift); // perf-allowed: pattern-identity timestamp
   return true;
  }

bool SelectOurPosition(ulong &ticket)
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
      return true;
     }
   return false;
  }

void RefreshPositionLifecycle()
  {
   ulong ticket = 0;
   if(SelectOurPosition(ticket))
     {
      if(ticket != g_active_ticket)
        {
         g_active_ticket = ticket;
         g_partial_done = false;
         g_be_done = false;
         if(g_pattern_height_price <= 0.0 && PositionSelectByTicket(ticket))
           {
            const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            const double sl = PositionGetDouble(POSITION_SL);
            g_pattern_height_price = MathAbs(open_price - sl);
           }
        }
      return;
     }

   g_active_ticket = 0;
   g_pattern_height_price = 0.0;
   g_head_price = 0.0;
   g_neck_at_break = 0.0;
   g_partial_target_price = 0.0;
   g_partial_done = false;
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

// Session / Friday-cutoff gate on the signal bar (broker time).
bool SessionAllows(const datetime broker_now)
  {
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   const int hour = dt.hour;
   if(hour < strategy_session_start_hour || hour >= strategy_session_end_hour)
      return false;
   // Friday (day_of_week == 5): no new entries at/after the Friday cutoff hour.
   if(dt.day_of_week == 5 && hour >= strategy_friday_cutoff_hour)
      return false;
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   RefreshPositionLifecycle();
   RefreshSpreadMedian();

   // Fail-OPEN spread guard: .DWX quotes 0 spread in the tester; only block a
   // genuinely wide live spread. Never reject on zero / median-absent spread.
   if(g_median_spread_points > 0.0 && strategy_spread_mult > 0.0)
     {
      const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if((double)current_spread > strategy_spread_mult * g_median_spread_points)
         return true;
     }
   return false;
  }

bool PatternAlreadyConsumed(const datetime ls_t, const datetime h_t, const datetime rs_t,
                            const datetime now_broker)
  {
   if(ls_t != g_used_ls_time || h_t != g_used_h_time || rs_t != g_used_rs_time)
      return false;
   // same (LS,H,RS) triple — blocked until cooldown expires
   if(now_broker < g_used_until_time)
      return true;
   return false;
  }

void MarkPatternConsumed(const datetime ls_t, const datetime h_t, const datetime rs_t,
                         const datetime now_broker)
  {
   g_used_ls_time = ls_t;
   g_used_h_time  = h_t;
   g_used_rs_time = rs_t;
   const int per_bar_sec = PeriodSeconds(strategy_tf);
   g_used_until_time = now_broker + (datetime)(strategy_pattern_reuse_bars * per_bar_sec);
  }

// Trade Entry — evaluated once per closed bar. SELL on H&S-Top neckline break.
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

   const datetime broker_now = TimeCurrent();

   // Session / Friday-cutoff gate (on the just-closed signal bar's broker time).
   const datetime bar1_time = iTime(_Symbol, strategy_tf, 1); // perf-allowed: session gate on signal bar
   if(bar1_time > 0 && !SessionAllows(bar1_time))
      return false;

   // Weekly-frequency cap: max 1 H&S trade per symbol per ~week (freq_cap_bars).
   if(g_last_entry_bar_time > 0)
     {
      const int per_bar_sec = PeriodSeconds(strategy_tf);
      if(broker_now < g_last_entry_bar_time + (datetime)(strategy_freq_cap_bars * per_bar_sec))
         return false;
     }

   double sl = 0.0, tp = 0.0, height = 0.0, head = 0.0, neck = 0.0, partial = 0.0;
   datetime ls_t = 0, h_t = 0, rs_t = 0;

   if(DetectHST(sl, tp, height, head, neck, partial, ls_t, h_t, rs_t) &&
      !PatternAlreadyConsumed(ls_t, h_t, rs_t, broker_now))
     {
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "CLASSICAL_HST_NECKLINE_BREAK_SELL_H4";

      g_pattern_height_price = height;
      g_head_price           = head;
      g_neck_at_break        = neck;
      g_partial_target_price = partial;
      g_partial_done         = false;
      g_be_done              = false;
      g_last_entry_bar_time  = broker_now;
      MarkPatternConsumed(ls_t, h_t, rs_t, broker_now);
      return true;
     }

   return false;
  }

// Trade Management — partial TP at 50% of pattern-height then move remaining SL
// to break-even (card § Exit-2). One-time.
void Strategy_ManageOpenPosition()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0)
      return;
   if(!PositionSelectByTicket(g_active_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(ptype != POSITION_TYPE_SELL)
      return; // SELL-only strategy

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // a SELL is closed at ask; progress tracked vs ask
   if(ask <= 0.0)
      return;

   // Partial + BE when price reaches neckline - 0.5*height (g_partial_target_price).
   if(!g_partial_done && g_partial_target_price > 0.0 && ask <= g_partial_target_price)
     {
      const double cur_vol = PositionGetDouble(POSITION_VOLUME);
      const double half = QM_TM_NormalizeVolume(_Symbol, cur_vol * 0.5);
      if(half > 0.0 && half < cur_vol)
         QM_TM_PartialClose(g_active_ticket, half, QM_EXIT_STRATEGY);

      const double pip = PipDistance();
      const double be_price = open_price - pip; // BE for a SELL just below entry
      QM_TM_MoveSL(g_active_ticket, NormalizeDouble(be_price, _Digits), "hst_partial_be_shift");
      g_partial_done = true;
      g_be_done = true;
     }
  }

// Trade Close — structural hard-exits (card § Exit 4-6):
//   (a) head-violation: a bar closes above H -> close at market.
//   (b) neckline-reclaim: a bar closes above neckline + 0.5*ATR_H4 -> close.
//   (c) time stop: 48 H4 bars without TP/SL/invalidation -> market close.
bool Strategy_ExitSignal()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0)
      return false;
   if(!PositionSelectByTicket(g_active_ticket))
      return false;
   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(ptype != POSITION_TYPE_SELL)
      return false;

   // (a) head-violation — evaluated on closed bars (close above the head).
   if(g_cadence_ready && g_head_price > 0.0)
     {
      const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: head-violation closed-bar check
      if(c1 > g_head_price)
         return true;
     }

   // (b) neckline-reclaim — closed bar closes above neckline + 0.5*ATR_H4.
   if(g_cadence_ready && g_neck_at_break > 0.0)
     {
      const double atr_h4 = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
      const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: neckline-reclaim closed-bar check
      if(atr_h4 > 0.0 && c1 > g_neck_at_break + strategy_neck_reclaim_atr_h4 * atr_h4)
         return true;
     }

   // (c) time stop — closed-bar cadence only.
   if(g_cadence_ready)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1393\",\"ea\":\"classical-head-shoulders-top-h4\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   g_cadence_ready = false;

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
   g_cadence_ready = QM_IsNewBar(_Symbol, strategy_tf);

   if(Strategy_NoTradeFilter())
      return;

   // Management runs every tick (partial/BE is intrabar-reactive).
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
   if(!g_cadence_ready)
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
