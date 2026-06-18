#property strict
#property version   "5.0"
#property description "QM5_11006 the5ers-trendline-rsi — Trendline breakout-retest + RSI confirm (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11006 the5ers-trendline-rsi
// -----------------------------------------------------------------------------
// Source: The5ers blog "Strategies You Can Apply to Take Advantage of Market
//   Trends" (https://the5ers.com/market-trends-strategies/, 2022-04-10).
// Card: artifacts/cards_approved/QM5_11006_the5ers-trendline-rsi.md (APPROVED).
//
// Mechanics (deterministic, closed-bar reads at shift >= 1):
//   Trendline construction (pivot-anchored, non-repainting):
//     * Swing low  = low  lower  than the prior 2 and next 2 bars (fractal).
//     * Swing high = high higher than the prior 2 and next 2 bars (fractal).
//       A swing is CONFIRMED only when 2 bars have closed after it, so the
//       newest usable pivot sits at shift 3 (2-bar right window + current).
//     * Ascending trendline  = line through the two most recent confirmed swing
//       lows where the 2nd (more recent) low is HIGHER than the 1st.
//     * Descending trendline = line through the two most recent confirmed swing
//       highs where the 2nd (more recent) high is LOWER than the 1st.
//     * Trendline price at any bar = linear extension through the two anchor
//       (x, price) points, x = -shift (more recent bar => larger x). Fixed
//       geometry from closed anchors; never repainted by future bars.
//
//   SHORT breakout-retest (against a broken-down ascending support line):
//     * Within the last `retest_window` bars, a close was below the ascending
//       line by at least break_atr_mult*ATR (the breakout).
//     * Current closed bar (shift 1) retests the underside:
//         high[1] >= line@1 - retest_atr_mult*ATR
//     * Current closed bar rejects it: close[1] < line@1.
//     * RSI(1) < rsi_short_max.
//   LONG breakout-retest (against a broken-up descending resistance line):
//     * Within the last `retest_window` bars, a close was above the descending
//       line by at least break_atr_mult*ATR.
//     * Current closed bar retests the upper side:
//         low[1] <= line@1 + retest_atr_mult*ATR
//     * Current closed bar rejects it: close[1] > line@1.
//     * RSI(1) > rsi_long_min.
//
//   Stop loss : Long  = retest-candle low[1]  - sl_atr_mult*ATR.
//               Short = retest-candle high[1] + sl_atr_mult*ATR.
//   Take profit: tp_rr * R (R = |entry - SL|).
//   Exits     : (a) close after `time_stop_bars` H4 bars;
//               (b) signal-failure: Long closes if a closed bar falls back below
//                   the broken descending line; Short closes if a closed bar
//                   rallies back above the broken ascending line.
//   Filters   : min_anchor_bars between 1st anchor and entry; reject too-flat
//               lines (|slope/bar| <= slope_atr_mult*ATR); one position/magic.
//   Spread    : fail-open on .DWX zero modeled spread; block only genuinely
//               wide spread > spread_pct_of_stop of the stop distance.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11006;
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
input int    strategy_rsi_period         = 14;     // RSI lookback period
input double strategy_rsi_long_min        = 60.0;  // long requires RSI(1) > this
input double strategy_rsi_short_max       = 40.0;  // short requires RSI(1) < this
input int    strategy_atr_period          = 14;    // ATR period (buffers / stop)
input int    strategy_pivot_left          = 2;     // fractal left bars
input int    strategy_pivot_right         = 2;     // fractal right bars (confirm lag)
input int    strategy_scan_lookback       = 80;    // bars scanned for pivots/line
input int    strategy_retest_window       = 6;     // bars in which the break must have occurred
input double strategy_break_atr_mult      = 0.25;  // breakout depth, in ATR
input double strategy_retest_atr_mult     = 0.25;  // retest proximity, in ATR
input double strategy_slope_atr_mult      = 0.05;  // min |slope/bar| in ATR (reject flat lines)
input int    strategy_min_anchor_bars     = 20;    // min bars from 1st anchor to entry
input double strategy_sl_atr_mult         = 0.5;   // SL buffer beyond retest candle, in ATR
input double strategy_tp_rr               = 2.0;   // take-profit R-multiple
input int    strategy_time_stop_bars      = 30;    // close after N H4 bars
input double strategy_spread_pct_of_stop  = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope bookkeeping (closed-bar / per-position; advanced on new bar).
// -----------------------------------------------------------------------------
datetime g_entry_bar_time   = 0;     // open time of the bar we entered on
int      g_entry_dir        = 0;     // +1 long / -1 short for the open position
double   g_active_line_a    = 0.0;   // slope of the line that triggered entry
double   g_active_line_b    = 0.0;   // intercept (price at x=0) of that line

// -----------------------------------------------------------------------------
// Structural helpers (bespoke trendline geometry — perf-allowed closed-bar
// reads; all bounded by strategy_scan_lookback, gated by QM_IsNewBar upstream).
// -----------------------------------------------------------------------------

// Confirmed fractal swing low at `shift`: low[shift] strictly below the `left`
// bars to its left (older, larger shift) and `right` bars to its right (newer,
// smaller shift). Caller must ensure shift >= right so the right window is closed.
bool IsSwingLow(const int shift, const int left, const int right)
  {
   const double pivot = iLow(_Symbol, _Period, shift); // perf-allowed: structural pivot read
   if(pivot <= 0.0)
      return false;
   for(int k = 1; k <= left; ++k)
     {
      const double l = iLow(_Symbol, _Period, shift + k); // perf-allowed
      if(l <= 0.0 || !(pivot < l))
         return false;
     }
   for(int k = 1; k <= right; ++k)
     {
      const double r = iLow(_Symbol, _Period, shift - k); // perf-allowed
      if(r <= 0.0 || !(pivot < r))
         return false;
     }
   return true;
  }

bool IsSwingHigh(const int shift, const int left, const int right)
  {
   const double pivot = iHigh(_Symbol, _Period, shift); // perf-allowed: structural pivot read
   if(pivot <= 0.0)
      return false;
   for(int k = 1; k <= left; ++k)
     {
      const double h = iHigh(_Symbol, _Period, shift + k); // perf-allowed
      if(h <= 0.0 || !(pivot > h))
         return false;
     }
   for(int k = 1; k <= right; ++k)
     {
      const double r = iHigh(_Symbol, _Period, shift - k); // perf-allowed
      if(r <= 0.0 || !(pivot > r))
         return false;
     }
   return true;
  }

// Find the two most recent confirmed swing-low shifts (newer first). Returns
// true and fills s_new (more recent, smaller shift) and s_old (older).
bool TwoRecentSwingLows(const int left, const int right, const int lookback,
                        int &s_new, int &s_old)
  {
   s_new = -1;
   s_old = -1;
   const int start = right + 1;                 // newest confirmable pivot
   const int end   = lookback;                  // oldest scanned
   for(int s = start; s <= end; ++s)
     {
      if(!IsSwingLow(s, left, right))
         continue;
      if(s_new < 0)        { s_new = s; continue; }
      s_old = s;
      return true;                              // two found
     }
   return false;
  }

bool TwoRecentSwingHighs(const int left, const int right, const int lookback,
                         int &s_new, int &s_old)
  {
   s_new = -1;
   s_old = -1;
   const int start = right + 1;
   const int end   = lookback;
   for(int s = start; s <= end; ++s)
     {
      if(!IsSwingHigh(s, left, right))
         continue;
      if(s_new < 0)        { s_new = s; continue; }
      s_old = s;
      return true;
     }
   return false;
  }

// Linear line through two anchors given as (shift, price). x = -shift so a more
// recent bar (smaller shift) maps to a larger x. Fills slope a and intercept b
// (price = a*x + b). Returns false if the anchors share an x (degenerate).
bool LineFromAnchors(const int shift_old, const double price_old,
                     const int shift_new, const double price_new,
                     double &a, double &b)
  {
   const double x_old = -(double)shift_old;
   const double x_new = -(double)shift_new;
   const double dx = x_new - x_old;
   if(MathAbs(dx) < 1e-9)
      return false;
   a = (price_new - price_old) / dx;
   b = price_new - a * x_new;
   return true;
  }

// Trendline price at a given shift from slope/intercept (x = -shift).
double LinePriceAt(const double a, const double b, const int shift)
  {
   return a * (-(double)shift) + b;
  }

// Current ask (buy) / bid (sell) helper. Returns 0.0 on no quote.
double bidOrAsk(const bool is_buy)
  {
   return is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                 : SymbolInfoDouble(_Symbol, SYMBOL_BID);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/signal work is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Breakout-retest entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: trigger-bar close
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi1 <= 0.0)
      return false;

   const double break_dist  = strategy_break_atr_mult  * atr_value;
   const double retest_dist = strategy_retest_atr_mult * atr_value;
   const double min_slope   = strategy_slope_atr_mult  * atr_value; // per-bar, ATR-scaled

   // ===================== SHORT: broken-down ascending line =====================
     {
      int s_new, s_old;
      if(TwoRecentSwingLows(strategy_pivot_left, strategy_pivot_right,
                            strategy_scan_lookback, s_new, s_old))
        {
         const double p_old = iLow(_Symbol, _Period, s_old); // perf-allowed: anchor
         const double p_new = iLow(_Symbol, _Period, s_new); // perf-allowed: anchor
         double a, b;
         // Ascending = 2nd (newer) swing low higher than the 1st (older).
         if(p_new > p_old && LineFromAnchors(s_old, p_old, s_new, p_new, a, b))
           {
            const double line1 = LinePriceAt(a, b, 1); // line price at the trigger bar
            // Filters: min bars since the older anchor, and a non-flat slope.
            const bool enough_bars = (s_old >= strategy_min_anchor_bars);
            const bool steep_enough = (MathAbs(a) > min_slope);
            if(enough_bars && steep_enough && line1 > 0.0)
              {
               // Breakout: a closed bar within the retest window broke below the
               // line by >= break_dist (scan shifts 1..retest_window).
               bool broke_below = false;
               for(int s = 1; s <= strategy_retest_window; ++s)
                 {
                  const double c = iClose(_Symbol, _Period, s); // perf-allowed
                  const double ln = LinePriceAt(a, b, s);
                  if(c > 0.0 && ln > 0.0 && c < ln - break_dist)
                    { broke_below = true; break; }
                 }
               // Retest underside + rejection on the trigger bar + RSI weak.
               const bool retest   = (high1 >= line1 - retest_dist);
               const bool rejected = (close1 < line1);
               const bool rsi_ok   = (rsi1 < strategy_rsi_short_max);
               if(broke_below && retest && rejected && rsi_ok)
                 {
                  const double entry = bidOrAsk(false); // sell at bid
                  if(entry > 0.0)
                    {
                     const double sl = QM_StopRulesNormalizePrice(_Symbol,
                                       high1 + strategy_sl_atr_mult * atr_value);
                     const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
                     if(sl > entry && tp > 0.0)
                       {
                        req.type   = QM_SELL;
                        req.price  = 0.0;   // framework fills market price at send
                        req.sl     = sl;
                        req.tp     = tp;
                        req.reason = "tl_retest_short";
                        g_entry_dir     = -1;
                        g_active_line_a = a;
                        g_active_line_b = b;
                        return true;
                       }
                    }
                 }
              }
           }
        }
     }

   // ===================== LONG: broken-up descending line =======================
     {
      int s_new, s_old;
      if(TwoRecentSwingHighs(strategy_pivot_left, strategy_pivot_right,
                             strategy_scan_lookback, s_new, s_old))
        {
         const double p_old = iHigh(_Symbol, _Period, s_old); // perf-allowed: anchor
         const double p_new = iHigh(_Symbol, _Period, s_new); // perf-allowed: anchor
         double a, b;
         // Descending = 2nd (newer) swing high lower than the 1st (older).
         if(p_new < p_old && LineFromAnchors(s_old, p_old, s_new, p_new, a, b))
           {
            const double line1 = LinePriceAt(a, b, 1);
            const bool enough_bars = (s_old >= strategy_min_anchor_bars);
            const bool steep_enough = (MathAbs(a) > min_slope);
            if(enough_bars && steep_enough && line1 > 0.0)
              {
               bool broke_above = false;
               for(int s = 1; s <= strategy_retest_window; ++s)
                 {
                  const double c = iClose(_Symbol, _Period, s); // perf-allowed
                  const double ln = LinePriceAt(a, b, s);
                  if(c > 0.0 && ln > 0.0 && c > ln + break_dist)
                    { broke_above = true; break; }
                 }
               const bool retest   = (low1 <= line1 + retest_dist);
               const bool rejected = (close1 > line1);
               const bool rsi_ok   = (rsi1 > strategy_rsi_long_min);
               if(broke_above && retest && rejected && rsi_ok)
                 {
                  const double entry = bidOrAsk(true); // buy at ask
                  if(entry > 0.0)
                    {
                     const double sl = QM_StopRulesNormalizePrice(_Symbol,
                                       low1 - strategy_sl_atr_mult * atr_value);
                     const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
                     if(sl > 0.0 && sl < entry && tp > 0.0)
                       {
                        req.type   = QM_BUY;
                        req.price  = 0.0;
                        req.sl     = sl;
                        req.tp     = tp;
                        req.reason = "tl_retest_long";
                        g_entry_dir     = +1;
                        g_active_line_a = a;
                        g_active_line_b = b;
                        return true;
                       }
                    }
                 }
              }
           }
        }
     }

   return false;
  }

// Latch the entry bar time once a position is open (for the bar-count time stop).
void Strategy_ManageOpenPosition()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
     {
      g_entry_bar_time = 0;
      g_entry_dir      = 0;
      return;
     }
   if(g_entry_bar_time == 0)
      g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: position bookkeeping
  }

// Discretionary exits: time stop OR price closing back across the broken line.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // --- Time stop: close after strategy_time_stop_bars closed H4 bars ---
   if(g_entry_bar_time > 0)
     {
      const int entry_shift = iBarShift(_Symbol, _Period, g_entry_bar_time, false); // perf-allowed: bookkeeping
      if(entry_shift >= strategy_time_stop_bars)
         return true;
     }

   // --- Signal-failure exit: a closed bar moves back across the broken line ---
   if(g_entry_dir != 0)
     {
      const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
      const double line1  = LinePriceAt(g_active_line_a, g_active_line_b, 1);
      if(close1 > 0.0 && line1 > 0.0)
        {
         // Long was a break ABOVE the descending line; fail if price closes back below it.
         if(g_entry_dir > 0 && close1 < line1)
            return true;
         // Short was a break BELOW the ascending line; fail if price closes back above it.
         if(g_entry_dir < 0 && close1 > line1)
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
