#property strict
#property version   "5.0"
#property description "QM5_11007 the5ers-pitchfork-bounce — Andrews Pitchfork outer-line mean-reversion bounce (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11007 the5ers-pitchfork-bounce
// -----------------------------------------------------------------------------
// Source: The5ers blog "All You Need to Know About Andrews Pitchforks Strategy".
// Card: artifacts/cards_approved/QM5_11007_the5ers-pitchfork-bounce.md (APPROVED).
//
// Mechanics (mean-reversion, closed-bar reads only):
//   Pitchfork is anchored to THREE deterministic, confirmed fractal pivots
//   (P0/P1/P2) found with a 3-left/3-right fractal rule on closed bars:
//     Bullish triplet : low(P0) - high(P1) - low(P2), with low(P2) > low(P0).
//     Bearish triplet : high(P0) - low(P1) - high(P2), with high(P2) < high(P0).
//   Andrews construction (per bar index, all values projected to the entry bar):
//     median line : from P0 through the midpoint of (P1,P2).
//     handle/slope: (mid_price - P0_price) / (mid_index - P0_index) per bar.
//     lower line  : parallel to median, anchored at the lower of P1/P2.
//     upper line  : parallel to median, anchored at the higher of P1/P2.
//   Long entry (next bar open, framework fills market at send) when:
//     - the lower pitchfork line at the prior closed bar is touched within
//       touch_atr_mult * ATR (low[1] within tolerance of lower_line[1]);
//     - rejection: close[1] > lower_line[1] and lower wick >= 50% of range;
//     - RSI(14)[1] < rsi_long_max;
//     - median target is >= 1.0R away; line spacing >= min_spacing_atr_mult*ATR;
//     - no open position under this magic.
//   Short entry is the mirror at the upper line with RSI[1] > rsi_short_min.
//   Stop : long  -> touch-low  - sl_atr_mult*ATR; short -> touch-high + sl_atr_mult*ATR.
//   Take : pitchfork median line at the current bar, capped at tp_cap_rr * R.
//   Exits: signal exit if price closes beyond the touched outer line by
//          touch_atr_mult*ATR; time stop after time_stop_bars closed H4 bars.
//
// .DWX invariants honoured: fail-OPEN spread guard, no swap gate, prior-CLOSE
// based geometry (no gap rules), no external feed, broker-time agnostic (no
// session window — pitchfork geometry is session-independent). Pivot scan is
// bounded and cached per closed bar (no per-tick history scans).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11007;
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
input int    strategy_fractal_width      = 3;      // bars left/right for a confirmed swing pivot
input int    strategy_scan_bars          = 200;    // bounded closed-bar scan window for pivots
input int    strategy_rsi_period         = 14;     // RSI lookback
input double strategy_rsi_long_max       = 35.0;   // long requires RSI[1] < this
input double strategy_rsi_short_min      = 65.0;   // short requires RSI[1] > this
input int    strategy_atr_period         = 14;     // ATR for tolerance/stop/spacing
input double strategy_touch_atr_mult     = 0.25;   // touch tolerance & signal-exit overshoot
input double strategy_sl_atr_mult        = 0.5;    // stop buffer beyond the touch extreme
input double strategy_wick_frac_min      = 0.50;   // rejection wick must be >= this fraction of range
input double strategy_min_spacing_atr    = 2.0;    // min upper-lower line spacing at entry, in ATR
input double strategy_min_target_rr      = 1.0;    // skip if median target < this * R
input double strategy_tp_cap_rr          = 2.5;    // cap median target at this * R
input int    strategy_min_anchor_bars    = 30;     // min bars between P0 and the entry bar
input int    strategy_max_age_bars       = 120;    // expire pitchfork this many bars after P2
input int    strategy_time_stop_bars     = 24;     // close after this many closed bars
input double strategy_spread_pct_of_stop = 25.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached pitchfork state — advanced ONCE per closed bar.
// Indices are bar-shift values relative to the just-closed bar (shift 1 = bar 0
// of the geometry frame). Prices are the pivot extremes.
// -----------------------------------------------------------------------------
// Bullish pitchfork (anchors a LOWER outer line for long bounces).
bool   g_bull_valid     = false;
double g_bull_lower1    = 0.0;   // lower outer line value projected to shift 1
double g_bull_median1   = 0.0;   // median line value projected to shift 1
double g_bull_spacing   = 0.0;   // upper-lower spacing at shift 1 (price units)
int    g_bull_p0_shift  = 0;     // P0 shift (oldest anchor) — for age/anchor checks
// Bearish pitchfork (anchors an UPPER outer line for short bounces).
bool   g_bear_valid     = false;
double g_bear_upper1    = 0.0;
double g_bear_median1   = 0.0;
double g_bear_spacing   = 0.0;
int    g_bear_p0_shift  = 0;

// Entry-bar bookkeeping for the time stop (bars elapsed since entry).
datetime g_entry_bar_time = 0;

// -----------------------------------------------------------------------------
// Fractal pivot detection on closed bars. A swing-high at shift s requires
// high[s] strictly greater than the `width` bars on each side; swing-low mirror.
// Scans from `from_shift` outward (increasing shift = older) up to scan_bars.
// Returns the shift of the found pivot, or -1. Bounded; called per closed bar.
// -----------------------------------------------------------------------------
int FindPivot(const bool want_high, const int from_shift, const int max_shift, const int width)
  {
   for(int s = from_shift; s <= max_shift; ++s)
     {
      const double pivot_val = want_high ? iHigh(_Symbol, _Period, s)  // perf-allowed: bounded closed-bar scan
                                         : iLow(_Symbol, _Period, s);
      if(pivot_val <= 0.0)
         continue;
      bool is_pivot = true;
      for(int k = 1; k <= width && is_pivot; ++k)
        {
         const double left  = want_high ? iHigh(_Symbol, _Period, s + k)
                                        : iLow(_Symbol, _Period, s + k);
         const double right = want_high ? iHigh(_Symbol, _Period, s - k)
                                        : iLow(_Symbol, _Period, s - k);
         if(left <= 0.0 || right <= 0.0)
           { is_pivot = false; break; }
         if(want_high)
           { if(!(pivot_val > left) || !(pivot_val > right)) is_pivot = false; }
         else
           { if(!(pivot_val < left) || !(pivot_val < right)) is_pivot = false; }
        }
      if(is_pivot)
         return s;
     }
   return -1;
  }

// Build one pitchfork from a confirmed P0-P1-P2 fractal triplet and project the
// median + the requested outer line to shift 1. want_bull=true builds the
// bullish (low-high-low) fork and its LOWER outer line; false builds the
// bearish (high-low-high) fork and its UPPER outer line.
void RebuildPitchfork(const bool want_bull)
  {
   const int width   = strategy_fractal_width;
   const int max_s   = strategy_scan_bars;
   const int first_s = width + 1; // need `width` confirming bars to the right (shifts >=1)

   // P2 = most-recent pivot of the inner type; P1 = opposite pivot older than P2;
   // P0 = same-type pivot older than P1. Bullish: P0 low, P1 high, P2 low.
   const bool p2_high = !want_bull; // bullish triplet ends on a low; bearish on a high
   const int p2 = FindPivot(p2_high, first_s, max_s, width);
   if(p2 < 0) { if(want_bull) g_bull_valid=false; else g_bear_valid=false; return; }

   const int p1 = FindPivot(!p2_high, p2 + 1, max_s, width);
   if(p1 < 0) { if(want_bull) g_bull_valid=false; else g_bear_valid=false; return; }

   const int p0 = FindPivot(p2_high, p1 + 1, max_s, width);
   if(p0 < 0) { if(want_bull) g_bull_valid=false; else g_bear_valid=false; return; }

   const double p0_price = p2_high ? iHigh(_Symbol, _Period, p0) : iLow(_Symbol, _Period, p0);
   const double p1_price = p2_high ? iLow(_Symbol, _Period, p1)  : iHigh(_Symbol, _Period, p1);
   const double p2_price = p2_high ? iHigh(_Symbol, _Period, p2) : iLow(_Symbol, _Period, p2);
   if(p0_price <= 0.0 || p1_price <= 0.0 || p2_price <= 0.0)
     { if(want_bull) g_bull_valid=false; else g_bear_valid=false; return; }

   // Card directional filter: bullish needs the 2nd low above the 1st low;
   // bearish needs the 2nd high below the 1st high. (P0 and P2 are same-type.)
   if(want_bull && !(p2_price > p0_price)) { g_bull_valid=false; return; }
   if(!want_bull && !(p2_price < p0_price)) { g_bear_valid=false; return; }

   // Age / anchor distance: P0 must be at least min_anchor_bars older than the
   // entry bar (shift 1), and the fork must not be older than max_age_bars past P2.
   if((p0 - 1) < strategy_min_anchor_bars) { if(want_bull) g_bull_valid=false; else g_bear_valid=false; return; }
   if((p2 - 1) > strategy_max_age_bars)    { if(want_bull) g_bull_valid=false; else g_bear_valid=false; return; }

   // Andrews median: from P0 through the midpoint of (P1,P2).
   // Use bar-shift as the x-axis. Smaller shift = more recent. Project to shift 1.
   const double mid_shift = (p1 + p2) / 2.0;
   const double mid_price = (p1_price + p2_price) / 2.0;
   const double dshift    = (double)p0 - mid_shift; // shift delta from mid to P0
   if(MathAbs(dshift) < 1e-9) { if(want_bull) g_bull_valid=false; else g_bear_valid=false; return; }
   // price per UNIT shift (note: increasing shift = older = back in time).
   const double slope = (p0_price - mid_price) / dshift; // price change per +1 shift
   // median value at shift 1: extrapolate from P0 along the slope.
   const double median1 = p0_price + slope * (1.0 - (double)p0);

   // Outer parallels pass through P1 and P2 (the two non-apex anchors), offset
   // from the median by each anchor's vertical distance at its own shift.
   const double median_at_p1 = p0_price + slope * ((double)p1 - (double)p0);
   const double median_at_p2 = p0_price + slope * ((double)p2 - (double)p0);
   const double off_p1 = p1_price - median_at_p1;
   const double off_p2 = p2_price - median_at_p2;
   const double upper_off = MathMax(off_p1, off_p2);
   const double lower_off = MathMin(off_p1, off_p2);
   const double upper1 = median1 + upper_off;
   const double lower1 = median1 + lower_off;
   const double spacing = upper1 - lower1;

   if(want_bull)
     {
      g_bull_valid   = true;
      g_bull_lower1  = lower1;
      g_bull_median1 = median1;
      g_bull_spacing = spacing;
      g_bull_p0_shift= p0;
     }
   else
     {
      g_bear_valid   = true;
      g_bear_upper1  = upper1;
      g_bear_median1 = median1;
      g_bear_spacing = spacing;
      g_bear_p0_shift= p0;
     }
  }

// Advance both cached pitchforks once per closed bar.
void AdvanceState_OnNewBar()
  {
   g_bull_valid = false;
   g_bear_valid = false;
   RebuildPitchfork(true);
   RebuildPitchfork(false);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Fail-OPEN spread guard only (.DWX models 0 spread).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on zero price

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;
   return false;
  }

// Entry: pitchfork outer-line bounce. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double tol = strategy_touch_atr_mult * atr_value;

   // Closed-bar OHLC at shift 1 (the bar that just closed).
   const double high1  = iHigh(_Symbol,  _Period, 1);  // perf-allowed: single closed-bar reads
   const double low1   = iLow(_Symbol,   _Period, 1);
   const double open1  = iOpen(_Symbol,  _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;
   const double range1 = high1 - low1;
   if(range1 <= 0.0)
      return false;

   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi1 <= 0.0)
      return false;

   // --- LONG: lower-line touch + rejection ---
   if(g_bull_valid && g_bull_spacing >= strategy_min_spacing_atr * atr_value)
     {
      const double lower = g_bull_lower1;
      const bool touched = (MathAbs(low1 - lower) <= tol) || (low1 < lower && (lower - low1) <= tol);
      const bool reject  = (close1 > lower);
      const double lower_wick = MathMin(open1, close1) - low1;
      const bool wick_ok = (lower_wick >= strategy_wick_frac_min * range1);
      const bool rsi_ok  = (rsi1 < strategy_rsi_long_max);
      if(touched && reject && wick_ok && rsi_ok)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry > 0.0)
           {
            const double sl = QM_StopRulesStopFromDistance(_Symbol, QM_BUY, entry,
                                                           (entry - low1) + strategy_sl_atr_mult * atr_value);
            const double risk = entry - sl;
            if(risk > 0.0)
              {
               double target = g_bull_median1;            // median-line TP at current bar
               const double cap = entry + strategy_tp_cap_rr * risk;
               if(target > cap) target = cap;             // cap at tp_cap_rr * R
               const double reward = target - entry;
               // protective floor: median target must be >= min_target_rr * R away
               if(reward >= strategy_min_target_rr * risk && target > entry)
                 {
                  req.type   = QM_BUY;
                  req.price  = 0.0;
                  req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
                  req.tp     = QM_StopRulesNormalizePrice(_Symbol, target);
                  req.reason = "pitchfork_lower_bounce_long";
                  return true;
                 }
              }
           }
        }
     }

   // --- SHORT: upper-line touch + rejection ---
   if(g_bear_valid && g_bear_spacing >= strategy_min_spacing_atr * atr_value)
     {
      const double upper = g_bear_upper1;
      const bool touched = (MathAbs(high1 - upper) <= tol) || (high1 > upper && (high1 - upper) <= tol);
      const bool reject  = (close1 < upper);
      const double upper_wick = high1 - MathMax(open1, close1);
      const bool wick_ok = (upper_wick >= strategy_wick_frac_min * range1);
      const bool rsi_ok  = (rsi1 > strategy_rsi_short_min);
      if(touched && reject && wick_ok && rsi_ok)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry > 0.0)
           {
            const double sl = QM_StopRulesStopFromDistance(_Symbol, QM_SELL, entry,
                                                           (high1 - entry) + strategy_sl_atr_mult * atr_value);
            const double risk = sl - entry;
            if(risk > 0.0)
              {
               double target = g_bear_median1;
               const double cap = entry - strategy_tp_cap_rr * risk;
               if(target < cap) target = cap;
               const double reward = entry - target;
               if(reward >= strategy_min_target_rr * risk && target < entry)
                 {
                  req.type   = QM_SELL;
                  req.price  = 0.0;
                  req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
                  req.tp     = QM_StopRulesNormalizePrice(_Symbol, target);
                  req.reason = "pitchfork_upper_bounce_short";
                  return true;
                 }
              }
           }
        }
     }

   return false;
  }

// Latch the entry bar-open time once a position is open (for the time stop).
void Strategy_ManageOpenPosition()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
     {
      if(g_entry_bar_time == 0)
         g_entry_bar_time = iTime(_Symbol, _Period, 0); // bar-open of current forming bar
     }
   else
      g_entry_bar_time = 0;
  }

// Signal exit (close beyond the touched outer line by tolerance) + time stop.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double tol = (atr_value > 0.0) ? strategy_touch_atr_mult * atr_value : 0.0;
   const double close1 = iClose(_Symbol, _Period, 1);
   if(close1 <= 0.0)
      return false;

   // Determine current position direction.
   const int magic = QM_FrameworkMagic();
   bool is_long = false, have = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      have = true;
      break;
     }
   if(!have)
      return false;

   // Signal exit: price closed beyond the touched outer line by tolerance.
   if(tol > 0.0)
     {
      if(is_long && g_bull_valid && close1 < (g_bull_lower1 - tol))
         return true;
      if(!is_long && g_bear_valid && close1 > (g_bear_upper1 + tol))
         return true;
     }

   // Time stop: close after strategy_time_stop_bars closed bars since entry.
   if(g_entry_bar_time > 0)
     {
      const int secs = PeriodSeconds(_Period);
      if(secs > 0)
        {
         const datetime now_bar = iTime(_Symbol, _Period, 0);
         const long elapsed = (long)(now_bar - g_entry_bar_time) / secs;
         if(elapsed >= strategy_time_stop_bars)
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

   AdvanceState_OnNewBar();   // refresh cached pitchforks once per closed bar

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
