#property strict
#property version   "5.0"
#property description "QM5_11659 pp-triangle — Triangle (converging-trendline) breakout, H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11659 pp-triangle
// -----------------------------------------------------------------------------
// Source: Keith Orange / keithorange, PatternPy,
//   tradingpatterns/tradingpatterns.py -> detect_triangle_pattern
//   https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py
// Card: artifacts/cards_approved/QM5_11659_pp-triangle.md (g0_status APPROVED).
//
// The PatternPy detector is a broad rolling-window OHLC mask. The card's own
// "Lessons Learned" directs P3 to use stricter confirmation: "close beyond the
// pattern bar high/low". This V5 build mechanizes the triangle as a proper
// converging-trendline structure with a single breakout EVENT, which is the
// strict, zero-trade-trap-safe realization of the card's intent.
//
// Mechanics (closed-bar reads only; structure cached once per new bar):
//   Swing points : a closed bar at shift s is a swing HIGH if its high is the
//                  strict max over +/- swing_strength neighbours; swing LOW is
//                  the symmetric min. Scanned over a bounded lookback window.
//   Upper line   : straight line through the two most-recent swing highs.
//   Lower line   : straight line through the two most-recent swing lows.
//   Triangle STATE (converging range): upper-line slope <= +eps (non-rising)
//                  AND lower-line slope >= -eps (non-falling) AND the lines
//                  converge (lower-line value approaches upper-line value going
//                  forward) AND the current gap between the projected lines is
//                  meaningfully tighter than the lookback's full high-low range.
//                  This single STATE covers ascending / descending / symmetrical.
//   Trigger EVENT (single, never two-cross-same-bar):
//     LONG  : close[1] breaks ABOVE the upper line projected to bar 1, while
//             close[2] was still at/below the upper line projected to bar 2.
//             (the lower line / convergence is a STATE; the upper break is the
//             one EVENT.)
//     SHORT : close[1] breaks BELOW the lower line projected to bar 1, while
//             close[2] was still at/above the lower line projected to bar 2.
//   Stop         : ATR(14) emergency stop at sl_atr_mult * ATR (card: 2.0x).
//   Take profit  : tp_atr_mult * ATR (RR-style target via the same ATR value).
//   Time exit    : close after max_hold_bars closed bars (card: 12 H4 bars).
//   Defensive    : long closes if close falls below entry-bar low; short closes
//                  if close rises above entry-bar high (card exit rules).
//
// Only the 5 Strategy_* hooks + Strategy inputs + the cached-structure helper
// are EA-specific. Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11659;
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
input int    strategy_swing_strength    = 2;     // bars each side defining a swing pivot
input int    strategy_lookback_bars     = 60;    // bounded closed-bar window scanned for swings
input double strategy_converge_ratio    = 0.70;  // projected line gap must be <= this * full range
input double strategy_slope_eps_atr     = 0.05;  // slope tolerance, in ATR per bar, for "flat enough"
input int    strategy_atr_period        = 14;    // ATR period (filter / stop / target)
input double strategy_sl_atr_mult       = 2.0;   // stop distance = mult * ATR (card emergency stop)
input double strategy_tp_atr_mult       = 3.0;   // target distance = mult * ATR
input int    strategy_max_hold_bars     = 12;    // time exit after N closed bars (card: 12 H4)
input double strategy_spread_pct_of_stop = 15.0; // skip only if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Cached triangle structure (advanced ONCE per closed bar; never per tick).
// All "shift" indices are closed-bar shifts (1 = last closed bar).
// -----------------------------------------------------------------------------
bool   g_state_valid     = false;  // a valid converging-triangle structure exists
// Upper trendline (through 2 most recent swing highs): value = a_up + b_up*shift,
// where shift is the closed-bar shift (so shift 1 is the most recent closed bar).
double g_up_a            = 0.0;    // upper line value at shift 0 (intercept)
double g_up_b            = 0.0;    // upper line slope per shift (price units / bar)
double g_lo_a            = 0.0;    // lower line value at shift 0
double g_lo_b            = 0.0;    // lower line slope per shift
double g_struct_atr      = 0.0;    // ATR cached for the current structure

// Entry-bar reference levels for the card's defensive exit + time stop.
bool     g_in_long       = false;
bool     g_in_short      = false;
double   g_entry_bar_low  = 0.0;
double   g_entry_bar_high = 0.0;
datetime g_entry_bar_time = 0;

// Project a line (value at shift 0 = a, slope per shift = b) to a given shift.
double LineAtShift(const double a, const double b, const int shift)
  {
   return a + b * (double)shift;
  }

// Recompute the cached triangle structure from closed-bar swing points.
// Called ONCE per new closed bar from OnTick (post QM_IsNewBar gate). The only
// raw-OHLC scan in the EA; bounded by strategy_lookback_bars (perf-allowed
// bespoke structural logic). Reads are at shift >= 1 (closed bars only).
void AdvanceStructure_OnNewBar()
  {
   g_state_valid = false;

   const int strength = (strategy_swing_strength < 1 ? 1 : strategy_swing_strength);
   const int lookback = (strategy_lookback_bars < (4 * strength + 4)
                         ? (4 * strength + 4) : strategy_lookback_bars);

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;
   g_struct_atr = atr_value;

   // Pull the bounded closed-bar window once. Index i in these arrays maps to
   // closed-bar shift (i+1): highs[0] = high at shift 1, etc.
   const int need = lookback + strength + 2;
   double highs[];
   double lows[];
   // perf-allowed: single bounded CopyRates-equivalent read, gated by QM_IsNewBar.
   const int got_h = CopyHigh(_Symbol, _Period, 1, need, highs);
   const int got_l = CopyLow(_Symbol, _Period, 1, need, lows);
   if(got_h < need || got_l < need)
      return;

   // Find the two most-recent swing highs and two most-recent swing lows by
   // walking from the most recent closed bar backwards. A swing pivot at
   // array index i (shift i+1) requires `strength` neighbours each side inside
   // the window. We record their (shift, price) pairs.
   int    sh_shift[2];  double sh_price[2];  int sh_n = 0;
   int    sl_shift[2];  double sl_price[2];  int sl_n = 0;

   for(int i = strength; i < got_h - strength && (sh_n < 2 || sl_n < 2); ++i)
     {
      // Swing high test: highs[i] strictly >= neighbours, strictly > at least
      // the immediate neighbours (avoid flat plateaus counting twice).
      if(sh_n < 2)
        {
         bool is_high = true;
         for(int k = 1; k <= strength; ++k)
           {
            if(!(highs[i] >= highs[i - k] && highs[i] >= highs[i + k]))
              { is_high = false; break; }
           }
         if(is_high && highs[i] > highs[i - 1] && highs[i] > highs[i + 1])
           {
            sh_shift[sh_n] = i + 1;   // closed-bar shift
            sh_price[sh_n] = highs[i];
            sh_n++;
           }
        }
      // Swing low test.
      if(sl_n < 2)
        {
         bool is_low = true;
         for(int k = 1; k <= strength; ++k)
           {
            if(!(lows[i] <= lows[i - k] && lows[i] <= lows[i + k]))
              { is_low = false; break; }
           }
         if(is_low && lows[i] < lows[i - 1] && lows[i] < lows[i + 1])
           {
            sl_shift[sl_n] = i + 1;
            sl_price[sl_n] = lows[i];
            sl_n++;
           }
        }
     }

   if(sh_n < 2 || sl_n < 2)
      return; // not enough structure to draw two trendlines

   // Build upper line through the two swing highs. sh_shift[0] is the more
   // recent (smaller shift). Slope per shift: as shift increases (older), price.
   const int    sh0 = sh_shift[0], sh1 = sh_shift[1];
   const int    sl0 = sl_shift[0], sl1 = sl_shift[1];
   if(sh1 == sh0 || sl1 == sl0)
      return; // degenerate (same bar) — cannot define a slope

   const double up_b = (sh_price[1] - sh_price[0]) / (double)(sh1 - sh0); // price per +1 shift
   const double up_a = sh_price[0] - up_b * (double)sh0;                  // value at shift 0
   const double lo_b = (sl_price[1] - sl_price[0]) / (double)(sl1 - sl0);
   const double lo_a = sl_price[0] - lo_b * (double)sl0;

   // Convert slopes from "per +1 shift (going older)" to a directional read in
   // chart time. Going FORWARD in time = decreasing shift. A descending upper
   // line (falls as time advances) has price increasing with shift => up_b > 0.
   // An ascending lower line (rises as time advances) has price decreasing with
   // shift => lo_b < 0. We require a converging wedge:
   //   upper non-rising forward  => up_b >= -eps   (allows flat/descending tops)
   //   lower non-falling forward => lo_b <=  eps   (allows flat/ascending bottoms)
   const double eps = strategy_slope_eps_atr * atr_value;
   if(!(up_b >= -eps))
      return;
   if(!(lo_b <= eps))
      return;

   // Convergence: the projected gap at the most recent closed bar (shift 1)
   // must be meaningfully tighter than the full high-low range of the window,
   // AND the lines must be getting closer going forward (gap shrinks as shift
   // decreases toward the apex ahead of price).
   const double gap_recent = LineAtShift(up_a, up_b, 1) - LineAtShift(lo_a, lo_b, 1);
   if(gap_recent <= 0.0)
      return; // lines already crossed — no valid triangle interior

   // Gap at an older reference shift (the older of the two pivot anchors).
   const int    old_ref = (sh1 > sl1 ? sh1 : sl1);
   const double gap_old = LineAtShift(up_a, up_b, old_ref) - LineAtShift(lo_a, lo_b, old_ref);
   if(!(gap_recent < gap_old))
      return; // not converging (forward gap not shrinking)

   // Full high-low range over the lookback window for the compression ratio.
   double win_hi = highs[0];
   double win_lo = lows[0];
   const int win_end = (lookback < got_h ? lookback : got_h);
   for(int j = 1; j < win_end; ++j)
     {
      if(highs[j] > win_hi) win_hi = highs[j];
      if(lows[j]  < win_lo) win_lo = lows[j];
     }
   const double full_range = win_hi - win_lo;
   if(full_range <= 0.0)
      return;
   if(!(gap_recent <= strategy_converge_ratio * full_range))
      return; // range not compressed enough to call it a triangle

   // Structure accepted.
   g_up_a = up_a; g_up_b = up_b;
   g_lo_a = lo_a; g_lo_b = lo_b;
   g_state_valid = true;
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

   if(g_struct_atr <= 0.0)
      return false; // no structure ATR yet — defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * g_struct_atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Triangle breakout entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_state_valid)
      return false;

   const double atr_value = g_struct_atr;
   if(atr_value <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // Project both trendlines to the trigger bar (shift 1) and the prior bar
   // (shift 2). The convergence/lower-line is the STATE; the close breaking a
   // single line is the one EVENT (no two-cross-same-bar trap).
   const double up_1 = LineAtShift(g_up_a, g_up_b, 1);
   const double up_2 = LineAtShift(g_up_a, g_up_b, 2);
   const double lo_1 = LineAtShift(g_lo_a, g_lo_b, 1);
   const double lo_2 = LineAtShift(g_lo_a, g_lo_b, 2);

   // LONG breakout EVENT: prior close at/below upper line, current close above.
   const bool long_break = (close2 <= up_2 && close1 > up_1);
   // SHORT breakout EVENT: prior close at/above lower line, current close below.
   const bool short_break = (close2 >= lo_2 && close1 < lo_1);

   // Exactly one direction may fire on a given bar (a single close can't be
   // both above the top and below the bottom of a positive-gap triangle).
   if(long_break == short_break)
      return false; // neither, or (impossible) both

   const double entry = (long_break ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const QM_OrderType side = (long_break ? QM_BUY : QM_SELL);
   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0; // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (long_break ? "triangle_break_long" : "triangle_break_short");

   // Latch entry-bar reference levels for the defensive exit + time stop.
   g_in_long  = long_break;
   g_in_short = short_break;
   g_entry_bar_low  = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   g_entry_bar_high = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   g_entry_bar_time = iTime(_Symbol, _Period, 0);  // bar-open time of the bar we enter on
   return true;
  }

// No active SL/TP manipulation; fixed ATR stop/target. Clear stale latches when
// no position is open (e.g. SL/TP/news closed it outside the strategy exit).
void Strategy_ManageOpenPosition()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
     {
      g_in_long  = false;
      g_in_short = false;
     }
  }

// Discretionary exits (card): defensive break of the entry bar, and a time stop
// after strategy_max_hold_bars closed bars. SL/TP are handled by the framework.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   if(!(g_in_long || g_in_short))
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // Defensive break of the entry bar (card exit rule).
   if(g_in_long && g_entry_bar_low > 0.0 && close1 < g_entry_bar_low)
      return true;
   if(g_in_short && g_entry_bar_high > 0.0 && close1 > g_entry_bar_high)
      return true;

   // Time exit: close after N closed bars since entry (card: 12 H4 bars). Count
   // closed bars between the entry bar's open time and the current forming bar.
   if(g_entry_bar_time > 0)
     {
      const int held = iBarShift(_Symbol, _Period, g_entry_bar_time, false);
      if(held >= strategy_max_hold_bars)
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
      g_in_long  = false;
      g_in_short = false;
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Advance the cached triangle structure ONCE per closed bar (the only
   // bounded OHLC scan; never on the per-tick path).
   AdvanceStructure_OnNewBar();

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
