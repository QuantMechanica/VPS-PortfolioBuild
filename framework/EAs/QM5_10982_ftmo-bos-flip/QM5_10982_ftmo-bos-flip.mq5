#property strict
#property version   "5.0"
#property description "QM5_10982 ftmo-bos-flip — Break-of-Structure S/R Flip retest (H1, long+short)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10982 ftmo-bos-flip
// -----------------------------------------------------------------------------
// Source: FTMO "How to Read Market Structure and Price Action Patterns" (2026).
// Card: artifacts/cards_approved/QM5_10982_ftmo-bos-flip.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads, fractal market structure on H1):
//   Swings        : 3-left / 3-right fractal highs and lows.
//   BOS long      : an H1 close ABOVE the most recent confirmed swing-high
//                   (the "lower high" that capped bearish structure) by at
//                   least bos_atr_mult * ATR(14). That breaks bearish structure.
//   Retest long   : within retest_window bars after the break, price returns to
//                   the broken swing-high zone (+/- zone_atr_mult * ATR) and a
//                   rejection candle forms: lower wick >= wick_frac of range AND
//                   close in the upper half of its range. Enter LONG at close.
//   BOS short     : mirror — close BELOW the most recent confirmed swing-low by
//                   bos_atr_mult * ATR, retest the broken swing-low zone, upper
//                   wick >= wick_frac, close in lower half. Enter SHORT.
//   Stop          : long  = retest bar low  - zone_atr_mult * ATR.
//                   short = retest bar high + zone_atr_mult * ATR.
//   Target        : 2.0R (QM_TakeRR with the actual SL distance).
//   Manage        : move SL to break-even once price has travelled >= 1.0R.
//   Exit (discr.) : close if a bar closes back through the retest zone against
//                   the trade, or after time_exit_bars H1 bars held.
//   Filters       : skip if the break candle range > maxbreak_atr_mult * ATR
//                   (exhausted break); fail-OPEN spread guard; one position per
//                   magic; central news + Friday-close via framework wiring.
//
// All structure scanning runs ONLY on the closed-bar entry path (QM_IsNewBar
// gate in OnTick). The bespoke iHigh/iLow/iClose reads are bounded by a small
// fixed lookback window -> perf-allowed structural logic. Per-tick path is O(1).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10982;
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
input int    strategy_fractal_left      = 3;      // bars to the left of a swing pivot
input int    strategy_fractal_right     = 3;      // bars to the right (confirmation lag)
input int    strategy_atr_period        = 14;     // ATR period (break / zone / stop)
input double strategy_bos_atr_mult      = 0.15;   // close beyond swing by >= this * ATR = BOS
input double strategy_zone_atr_mult     = 0.25;   // retest zone half-width / stop buffer (* ATR)
input int    strategy_retest_window     = 12;     // max H1 bars from break to retest
input double strategy_wick_frac         = 0.40;   // rejection wick >= this fraction of candle range
input double strategy_maxbreak_atr_mult = 3.0;    // skip if break candle range > this * ATR
input double strategy_tp_rr             = 2.0;    // take-profit in R multiples
input double strategy_be_trigger_rr     = 1.0;    // move SL to break-even after this many R
input int    strategy_time_exit_bars    = 40;     // close after this many H1 bars held
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Structural helpers (closed-bar, bounded lookback — perf-allowed bespoke math).
// All shifts are >= 1 (closed bars only).
// -----------------------------------------------------------------------------

// Is the bar at `shift` a confirmed fractal swing high? (strictly highest high
// over [shift-left .. shift+right]). Requires shift >= right+1 so the right
// side is fully closed.
bool IsSwingHigh(const int shift, const int left, const int right)
  {
   const double h = iHigh(_Symbol, _Period, shift); // perf-allowed structural read
   if(h <= 0.0)
      return false;
   for(int i = 1; i <= left; ++i)
      if(iHigh(_Symbol, _Period, shift + i) >= h)
         return false;
   for(int i = 1; i <= right; ++i)
      if(iHigh(_Symbol, _Period, shift - i) >= h)
         return false;
   return true;
  }

// Is the bar at `shift` a confirmed fractal swing low?
bool IsSwingLow(const int shift, const int left, const int right)
  {
   const double l = iLow(_Symbol, _Period, shift); // perf-allowed structural read
   if(l <= 0.0)
      return false;
   for(int i = 1; i <= left; ++i)
      if(iLow(_Symbol, _Period, shift + i) <= l)
         return false;
   for(int i = 1; i <= right; ++i)
      if(iLow(_Symbol, _Period, shift - i) <= l)
         return false;
   return true;
  }

// Find the most recent confirmed swing-high price and the shift at which it sits,
// searching outward from the freshest confirmable swing. Returns false if none
// found in the bounded scan. `from_shift` is the first shift to consider as a
// swing-high candidate (must be >= right+1).
bool RecentSwingHigh(const int from_shift, const int left, const int right,
                     const int max_scan, double &out_price, int &out_shift)
  {
   for(int s = from_shift; s <= from_shift + max_scan; ++s)
     {
      if(IsSwingHigh(s, left, right))
        {
         out_price = iHigh(_Symbol, _Period, s); // perf-allowed structural read
         out_shift = s;
         return true;
        }
     }
   return false;
  }

bool RecentSwingLow(const int from_shift, const int left, const int right,
                    const int max_scan, double &out_price, int &out_shift)
  {
   for(int s = from_shift; s <= from_shift + max_scan; ++s)
     {
      if(IsSwingLow(s, left, right))
        {
         out_price = iLow(_Symbol, _Period, s); // perf-allowed structural read
         out_shift = s;
         return true;
        }
     }
   return false;
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
      return false; // no valid quote yet — never block on a missing quote

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_zone_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// BOS + S/R-flip retest entry. Caller guarantees QM_IsNewBar() == true.
// The most recently CLOSED bar (shift 1) is the candidate retest/rejection bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const int left  = strategy_fractal_left;
   const int right = strategy_fractal_right;

   // Candidate retest/rejection bar = last closed bar (shift 1).
   const double rt_high  = iHigh(_Symbol, _Period, 1);  // perf-allowed structural read
   const double rt_low   = iLow(_Symbol, _Period, 1);
   const double rt_close = iClose(_Symbol, _Period, 1);
   const double rt_open  = iOpen(_Symbol, _Period, 1);
   const double rt_range = rt_high - rt_low;
   if(rt_high <= 0.0 || rt_low <= 0.0 || rt_range <= 0.0)
      return false;

   const double zone_half = strategy_zone_atr_mult * atr_value;
   if(zone_half <= 0.0)
      return false;

   // First confirmable swing shift: needs `right` closed bars to its right, and
   // the retest bar itself sits at shift 1, so begin the swing scan beyond it.
   const int first_swing_shift = right + 1;
   const int max_scan = strategy_retest_window + left + right + 5;

   // -------------------------------------------------------------------------
   // LONG: prior bearish structure -> BOS up through a confirmed swing high ->
   // retest of that broken swing-high zone with a bullish rejection.
   // -------------------------------------------------------------------------
   double sh_price = 0.0; int sh_shift = 0;
   if(RecentSwingHigh(first_swing_shift, left, right, max_scan, sh_price, sh_shift))
     {
      // BOS confirmation: some bar between the swing and the retest bar closed
      // above the swing high by >= bos_atr_mult*ATR. Scan that window.
      bool bos_up = false;
      int  break_shift = 0;
      const int scan_to = MathMin(sh_shift - 1, strategy_retest_window + 1);
      for(int s = 1; s <= scan_to; ++s)
        {
         const double c = iClose(_Symbol, _Period, s); // perf-allowed structural read
         if(c > sh_price + strategy_bos_atr_mult * atr_value)
           {
            bos_up = true;
            break_shift = s;
            break;
           }
        }
      if(bos_up && break_shift >= 1)
        {
         // Exhausted-break filter: break candle range must not be too large.
         const double bk_range = iHigh(_Symbol, _Period, break_shift) - iLow(_Symbol, _Period, break_shift);
         const bool not_exhausted = (bk_range <= strategy_maxbreak_atr_mult * atr_value);

         // Retest: last closed bar dipped into the broken-level zone and rejected.
         const bool touched = (rt_low <= sh_price + zone_half && rt_high >= sh_price - zone_half);
         const double lower_wick = MathMin(rt_open, rt_close) - rt_low;
         const bool rejection = (lower_wick >= strategy_wick_frac * rt_range) &&
                                (rt_close >= rt_low + 0.5 * rt_range);

         if(not_exhausted && touched && rejection && break_shift <= strategy_retest_window)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(entry <= 0.0)
               return false;
            const double sl = QM_StopRulesNormalizePrice(_Symbol, rt_low - zone_half);
            if(sl <= 0.0 || sl >= entry)
               return false;
            const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
            if(tp <= 0.0)
               return false;
            req.type   = QM_BUY;
            req.price  = 0.0;   // framework fills market price at send
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "bos_flip_long";
            return true;
           }
        }
     }

   // -------------------------------------------------------------------------
   // SHORT: prior bullish structure -> BOS down through a confirmed swing low ->
   // retest of that broken swing-low zone with a bearish rejection.
   // -------------------------------------------------------------------------
   double sl_price = 0.0; int sl_shift = 0;
   if(RecentSwingLow(first_swing_shift, left, right, max_scan, sl_price, sl_shift))
     {
      bool bos_down = false;
      int  break_shift = 0;
      const int scan_to = MathMin(sl_shift - 1, strategy_retest_window + 1);
      for(int s = 1; s <= scan_to; ++s)
        {
         const double c = iClose(_Symbol, _Period, s); // perf-allowed structural read
         if(c < sl_price - strategy_bos_atr_mult * atr_value)
           {
            bos_down = true;
            break_shift = s;
            break;
           }
        }
      if(bos_down && break_shift >= 1)
        {
         const double bk_range = iHigh(_Symbol, _Period, break_shift) - iLow(_Symbol, _Period, break_shift);
         const bool not_exhausted = (bk_range <= strategy_maxbreak_atr_mult * atr_value);

         const bool touched = (rt_high >= sl_price - zone_half && rt_low <= sl_price + zone_half);
         const double upper_wick = rt_high - MathMax(rt_open, rt_close);
         const bool rejection = (upper_wick >= strategy_wick_frac * rt_range) &&
                                (rt_close <= rt_low + 0.5 * rt_range);

         if(not_exhausted && touched && rejection && break_shift <= strategy_retest_window)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(entry <= 0.0)
               return false;
            const double sl = QM_StopRulesNormalizePrice(_Symbol, rt_high + zone_half);
            if(sl <= 0.0 || sl <= entry)
               return false;
            const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
            if(tp <= 0.0)
               return false;
            req.type   = QM_SELL;
            req.price  = 0.0;
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "bos_flip_short";
            return true;
           }
        }
     }

   return false;
  }

// Move SL to break-even once price has travelled >= be_trigger_rr * initial R.
// Initial R = |entry - original SL|, reconstructed from the live SL distance is
// not reliable after a BE move, so we trigger off the position's own open price
// and the distance to its current SL only while SL is still on the loss side.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl     = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || cur_sl <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      // Only act while SL is still on the loss side (not yet moved to BE+).
      const double risk_dist = is_buy ? (open_price - cur_sl) : (cur_sl - open_price);
      if(risk_dist <= 0.0)
         continue; // already at/above break-even

      const double mkt = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(mkt <= 0.0)
         continue;

      const double travelled = is_buy ? (mkt - open_price) : (open_price - mkt);
      if(travelled < strategy_be_trigger_rr * risk_dist)
         continue;

      const double be_sl = QM_TM_NormalizePrice(_Symbol, open_price);
      if(be_sl <= 0.0)
         continue;
      QM_TM_MoveSL(ticket, be_sl, "bos_flip_breakeven");
     }
  }

// Discretionary exit: close if a closed bar reverses back through the retest
// zone against the trade, or after time_exit_bars H1 bars held. Returns TRUE to
// close the open position (framework closes by magic in OnTick). Evaluated on
// the closed-bar path is sufficient, but the framework calls this per tick — the
// reads below are O(1) closed-bar reads so cost is bounded.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this EA's position to read its type and open time.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);

      // Time exit: bars held since entry >= time_exit_bars.
      const datetime bar0_time = iTime(_Symbol, _Period, 0); // perf-allowed: current bar open time
      if(open_time > 0 && bar0_time > open_time)
        {
         const int per_secs = PeriodSeconds(_Period);
         if(per_secs > 0)
           {
            const int bars_held = (int)((bar0_time - open_time) / per_secs);
            if(bars_held >= strategy_time_exit_bars)
               return true;
           }
        }

      // Reverse-through-zone exit: last closed bar closed against the trade by
      // more than zone_half beyond the entry-adverse side.
      const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr_value > 0.0)
        {
         const double zone_half = strategy_zone_atr_mult * atr_value;
         const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed structural read
         const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         if(close1 > 0.0 && open_price > 0.0)
           {
            if(ptype == POSITION_TYPE_BUY && close1 < open_price - zone_half)
               return true;
            if(ptype == POSITION_TYPE_SELL && close1 > open_price + zone_half)
               return true;
           }
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
