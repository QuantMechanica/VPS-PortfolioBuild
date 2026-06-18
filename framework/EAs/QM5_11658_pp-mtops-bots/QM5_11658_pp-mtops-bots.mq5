#property strict
#property version   "5.0"
#property description "QM5_11658 pp-mtops-bots — Double/Triple Top & Bottom reversal (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11658 pp-mtops-bots
// -----------------------------------------------------------------------------
// Source: Keith Orange / PatternPy, tradingpatterns/tradingpatterns.py
//         detect_multiple_tops_bottoms.
// Card: artifacts/cards_approved/QM5_11658_pp-mtops-bots.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads only, fractal swings computed in-EA — perf-allowed):
//   PatternPy's detector flags repeated tops/bottoms at roughly equal price. The
//   V5 realization expresses that as the classic Double/Triple Top & Bottom
//   reversal:
//
//   STATE (structure):
//     Multiple Top   = 2..3 swing HIGHS within last lookback window, all at
//                      ~the same level (within tol * ATR of each other).
//     Multiple Bottom= 2..3 swing LOWS  within last lookback window, all at
//                      ~the same level (within tol * ATR of each other).
//   Swing high/low  = simple N-bar fractal on CLOSED bars (centre bar strictly
//                     above/below the `frac_wing` bars on each side).
//
//   TRIGGER (single EVENT — avoids the two-cross-same-bar zero-trade trap):
//     Top    -> neckline = the LOWEST swing-low (intervening valley) between the
//               matched tops. Short when close[1] crosses BELOW that neckline
//               (close[2] >= neckline AND close[1] < neckline). Top -> SHORT.
//     Bottom -> neckline = the HIGHEST swing-high (intervening peak) between the
//               matched bottoms. Long when close[1] crosses ABOVE that neckline
//               (close[2] <= neckline AND close[1] > neckline). Bottom -> LONG.
//   Exactly ONE crossing is the event; the equal-tops/bottoms structure is a
//   STATE detected before the cross — they are never required on the same bar.
//
//   Stop          : ATR(period) emergency stop at sl_atr_mult * ATR (card seed
//                   2.0x). Short stop above entry, long stop below.
//   Take profit   : tp_rr * stop distance (RR-multiple TP).
//   Time stop     : close after `max_hold_bars` closed H4 bars (card = 10).
//   Opposite exit : a short closes on a confirmed Multiple-Bottom long signal,
//                   a long closes on a confirmed Multiple-Top short signal.
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX 0).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11658;
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
input int    strategy_frac_wing         = 2;     // fractal wing: swing needs N strictly-lower/higher bars each side
input int    strategy_swing_lookback    = 40;    // closed bars scanned for swing points (structure window)
input int    strategy_min_peaks         = 2;     // min matched tops/bottoms (2 = double, 3 = triple)
input int    strategy_max_peaks         = 3;     // max matched tops/bottoms considered
input double strategy_level_tol_atr     = 0.75;  // tops/bottoms "equal" if within this * ATR of each other
input int    strategy_atr_period        = 14;    // ATR period (level tolerance + stop)
input double strategy_sl_atr_mult       = 2.0;   // emergency stop distance = mult * ATR
input double strategy_tp_rr             = 2.0;   // take-profit = tp_rr * stop distance
input int    strategy_max_hold_bars     = 10;    // time-stop: close after N closed H4 bars
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// In-EA closed-bar structure detection (perf-allowed bounded OHLC reads).
//   detected_dir : +1 = Multiple Bottom (LONG), -1 = Multiple Top (SHORT), 0 none
//   detected_neck: neckline price the close just crossed to trigger
// Returns true when a fresh neckline-cross EVENT fired on the last closed bar.
// -----------------------------------------------------------------------------
bool DetectMultiPattern(const double atr_value, int &detected_dir, double &detected_neck)
  {
   detected_dir  = 0;
   detected_neck = 0.0;

   if(atr_value <= 0.0)
      return false;

   const int wing     = (strategy_frac_wing < 1 ? 1 : strategy_frac_wing);
   const int lookback = (strategy_swing_lookback < (2 * wing + 4) ? (2 * wing + 4) : strategy_swing_lookback);
   const int min_pk   = (strategy_min_peaks < 2 ? 2 : strategy_min_peaks);
   const int max_pk   = (strategy_max_peaks < min_pk ? min_pk : strategy_max_peaks);
   const double tol   = strategy_level_tol_atr * atr_value;
   if(tol <= 0.0)
      return false;

   // Bounded scan window: shifts 1 .. lookback+wing (closed bars). perf-allowed.
   const int need_bars = lookback + wing + 2;

   // Collect swing highs/lows by centre-bar shift (most-recent first).
   // A centre bar at shift c is a swing high if high[c] > high of the `wing`
   // bars on each side (shifts c-wing..c-1 and c+1..c+wing). Mirror for lows.
   int    sh_shift[64];  double sh_price[64];  int sh_n = 0;  // swing highs
   int    sl_shift[64];  double sl_price[64];  int sl_n = 0;  // swing lows

   // Centre bars range from shift (1+wing) to (lookback+wing): a swing must have
   // `wing` confirmed closed bars on its RIGHT (more recent) side too.
   const int c_first = 1 + wing;
   const int c_last  = lookback + wing;
   for(int c = c_first; c <= c_last; ++c)
     {
      const double hc = iHigh(_Symbol, _Period, c); // perf-allowed: bounded closed-bar OHLC
      const double lc = iLow(_Symbol, _Period, c);
      if(hc <= 0.0 || lc <= 0.0)
         continue;

      bool is_high = true;
      bool is_low  = true;
      for(int k = 1; k <= wing; ++k)
        {
         const double hr = iHigh(_Symbol, _Period, c - k);
         const double hl = iHigh(_Symbol, _Period, c + k);
         const double lr = iLow(_Symbol, _Period, c - k);
         const double ll = iLow(_Symbol, _Period, c + k);
         if(!(hc > hr) || !(hc > hl)) is_high = false;
         if(!(lc < lr) || !(lc < ll)) is_low  = false;
         if(!is_high && !is_low)
            break;
        }

      if(is_high && sh_n < 64)
        {
         sh_shift[sh_n] = c;
         sh_price[sh_n] = hc;
         sh_n++;
        }
      if(is_low && sl_n < 64)
        {
         sl_shift[sl_n] = c;
         sl_price[sl_n] = lc;
         sl_n++;
        }
     }

   // Suppress an unused-variable warning on need_bars without C++ (void) idiom.
   if(need_bars < 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // ----- Multiple TOP -> SHORT -------------------------------------------
   // Take the most-recent matched cluster of swing highs near the SAME level.
   // sh arrays are ordered most-recent-first. Anchor on the most recent high
   // (sh index 0) and count how many subsequent highs sit within tol.
   if(sh_n >= min_pk)
     {
      const double anchor = sh_price[0];
      int    matched = 1;
      int    oldest_shift = sh_shift[0];
      const int newest_shift = sh_shift[0];
      for(int i = 1; i < sh_n && matched < max_pk; ++i)
        {
         if(MathAbs(sh_price[i] - anchor) <= tol)
           {
            matched++;
            oldest_shift = sh_shift[i]; // older (larger shift) edge of the cluster
           }
        }
      if(matched >= min_pk)
        {
         // Neckline = lowest swing-low (intervening valley) BETWEEN the matched
         // tops, i.e. swing lows with shift in (newest_shift .. oldest_shift).
         double neck = 0.0;
         bool   have_neck = false;
         for(int j = 0; j < sl_n; ++j)
           {
            if(sl_shift[j] > newest_shift && sl_shift[j] < oldest_shift)
              {
               if(!have_neck || sl_price[j] < neck)
                 {
                  neck = sl_price[j];
                  have_neck = true;
                 }
              }
           }
         if(have_neck)
           {
            // Single EVENT: close crosses DOWN through the neckline.
            if(close2 >= neck && close1 < neck)
              {
               detected_dir  = -1;
               detected_neck = neck;
               return true;
              }
           }
        }
     }

   // ----- Multiple BOTTOM -> LONG -----------------------------------------
   if(sl_n >= min_pk)
     {
      const double anchor = sl_price[0];
      int    matched = 1;
      int    oldest_shift = sl_shift[0];
      const int newest_shift = sl_shift[0];
      for(int i = 1; i < sl_n && matched < max_pk; ++i)
        {
         if(MathAbs(sl_price[i] - anchor) <= tol)
           {
            matched++;
            oldest_shift = sl_shift[i];
           }
        }
      if(matched >= min_pk)
        {
         // Neckline = highest swing-high (intervening peak) BETWEEN the matched
         // bottoms, i.e. swing highs with shift in (newest_shift .. oldest_shift).
         double neck = 0.0;
         bool   have_neck = false;
         for(int j = 0; j < sh_n; ++j)
           {
            if(sh_shift[j] > newest_shift && sh_shift[j] < oldest_shift)
              {
               if(!have_neck || sh_price[j] > neck)
                 {
                  neck = sh_price[j];
                  have_neck = true;
                 }
              }
           }
         if(have_neck)
           {
            // Single EVENT: close crosses UP through the neckline.
            if(close2 <= neck && close1 > neck)
              {
               detected_dir  = 1;
               detected_neck = neck;
               return true;
              }
           }
        }
     }

   return false;
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

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // defer to entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Reversal entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   int    dir  = 0;
   double neck = 0.0;
   if(!DetectMultiPattern(atr_value, dir, neck))
      return false;
   if(dir == 0)
      return false;

   if(dir < 0)
     {
      // Multiple Top -> SHORT.
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "multi_top_short";
      return true;
     }
   else
     {
      // Multiple Bottom -> LONG.
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "multi_bottom_long";
      return true;
     }
  }

// No active SL/TP modification beyond the fixed ATR stop/RR target. The time
// stop and opposite-signal exit live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: (a) time stop after max_hold_bars closed bars, or
// (b) opposite confirmed multi-pattern signal.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Resolve this EA's open position direction + open time.
   bool     have_pos = false;
   bool     is_long  = false;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      have_pos  = true;
      is_long   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(!have_pos)
      return false;

   // (a) Time stop: count closed bars whose open-time is >= position open time.
   const datetime bar1_open = iTime(_Symbol, _Period, 1); // perf-allowed: single read
   if(bar1_open > 0 && open_time > 0)
     {
      const int tf_secs = PeriodSeconds(_Period);
      if(tf_secs > 0)
        {
         const int bars_held = (int)((bar1_open - open_time) / tf_secs) + 1;
         if(bars_held >= strategy_max_hold_bars)
            return true;
        }
     }

   // (b) Opposite signal: a fresh confirmed pattern against the open direction.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value > 0.0)
     {
      int    dir  = 0;
      double neck = 0.0;
      if(DetectMultiPattern(atr_value, dir, neck) && dir != 0)
        {
         if(is_long && dir < 0)  return true; // long, but a Multiple-Top short fired
         if(!is_long && dir > 0) return true; // short, but a Multiple-Bottom long fired
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
