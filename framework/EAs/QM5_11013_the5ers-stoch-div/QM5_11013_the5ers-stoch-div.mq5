#property strict
#property version   "5.0"
#property description "QM5_11013 the5ers-stoch-div — Stochastic Divergence Reversal (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11013 the5ers-stoch-div
// -----------------------------------------------------------------------------
// Source: The5ers blog "How to use Stochastic Oscillator in Forex?"
//         (source_id 1d445184-7c47-57da-9856-a123682a932d).
// Card: artifacts/cards_approved/QM5_11013_the5ers-stoch-div.md (g0_status APPROVED).
//
// Mechanics (counter-trend reversal on stochastic divergence, closed-bar reads):
//   Swings        : 2-left / 2-right fractal pivots on closed bars (high/low).
//   Long setup    : latest confirmed swing-low PRICE lower than prior swing low,
//                   %K AT the latest swing low HIGHER than %K at the prior swing
//                   low (bullish divergence), latest swing-low %K oversold
//                   (<osc_lo OR crossed up through osc_cross_lo within last 3 bars),
//                   signal candle (shift 1) closes above its open, swing spacing
//                   in [min_swing_gap, max_swing_gap].
//   Short setup   : mirror (bearish divergence, %K overbought, bearish candle).
//   Entry         : market at next H4 open, one position per magic.
//   Stop          : long  = swing_low  - sl_atr_mult * ATR(atr_period);
//                   short = swing_high + sl_atr_mult * ATR(atr_period).
//   Take profit   : tp_rr * R (R = |entry - SL|).
//   Oscillator ex : close long when %K closes above osc_exit_hi; close short
//                   when %K closes below osc_exit_lo.
//   Failure exit  : close if price closes beyond the entry swing by
//                   fail_atr_mult * ATR.
//   Time stop     : close after time_stop_bars closed H4 bars.
//   Vol filter    : reject if ATR below its rolling atr_pctile percentile.
//
// Divergence is a BOUNDED deterministic pivot computation on CLOSED bars only;
// anchors are never repainted after entry (entry swing latched at fire time).
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11013;
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
input int    strategy_stoch_k           = 14;    // Stochastic %K period
input int    strategy_stoch_d           = 3;     // Stochastic %D period
input int    strategy_stoch_slow        = 3;     // Stochastic slowing
input int    strategy_swing_width       = 2;     // fractal left/right bars (2-left/2-right)
input double strategy_osc_lo            = 30.0;  // long: latest swing-low %K oversold threshold
input double strategy_osc_hi            = 70.0;  // short: latest swing-high %K overbought threshold
input double strategy_osc_cross_lo      = 20.0;  // long: %K cross-up level within last 3 bars
input double strategy_osc_cross_hi      = 80.0;  // short: %K cross-down level within last 3 bars
input double strategy_osc_exit_hi       = 70.0;  // long oscillator exit: %K above this
input double strategy_osc_exit_lo       = 30.0;  // short oscillator exit: %K below this
input int    strategy_min_swing_gap     = 5;     // min closed bars between the two swing anchors
input int    strategy_max_swing_gap     = 60;    // max closed bars between the two swing anchors
input int    strategy_swing_scan_bars   = 80;    // bounded lookback window for swing detection
input int    strategy_atr_period        = 14;    // ATR period (filter / stop / failure exit)
input double strategy_sl_atr_mult       = 0.5;   // stop beyond swing = mult * ATR
input double strategy_tp_rr             = 1.5;   // take-profit R-multiple
input double strategy_fail_atr_mult     = 0.25;  // failure-exit distance beyond entry swing = mult * ATR
input int    strategy_time_stop_bars    = 24;    // close after this many closed H4 bars
input int    strategy_atr_pctile_bars   = 100;   // rolling window for the ATR percentile floor
input double strategy_atr_pctile        = 20.0;  // reject entries below this ATR percentile

// -----------------------------------------------------------------------------
// File-scope entry-anchored state (latched once at entry; never repainted).
// -----------------------------------------------------------------------------
double   g_entry_swing_price = 0.0;   // price of the swing anchor at entry
int      g_entry_dir         = 0;     // +1 long, -1 short, 0 flat
datetime g_entry_bar_time    = 0;     // bar-open time of the entry bar

// -----------------------------------------------------------------------------
// Helpers (bounded, closed-bar only)
// -----------------------------------------------------------------------------

// Is the bar at `shift` a confirmed fractal swing LOW?
// 2-left / 2-right (width) confirmation; the right bars are MORE RECENT, so the
// pivot is fully closed and never repaints once shift >= width+1.
bool IsSwingLow(const int shift, const int width)
  {
   const double pivot_low = iLow(_Symbol, _Period, shift); // perf-allowed: bounded pivot scan
   if(pivot_low <= 0.0)
      return false;
   for(int j = 1; j <= width; ++j)
     {
      const double l_left  = iLow(_Symbol, _Period, shift + j);
      const double l_right = iLow(_Symbol, _Period, shift - j);
      if(l_left <= 0.0 || l_right <= 0.0)
         return false;
      if(!(pivot_low < l_left) || !(pivot_low < l_right))
         return false;
     }
   return true;
  }

// Is the bar at `shift` a confirmed fractal swing HIGH?
bool IsSwingHigh(const int shift, const int width)
  {
   const double pivot_high = iHigh(_Symbol, _Period, shift); // perf-allowed: bounded pivot scan
   if(pivot_high <= 0.0)
      return false;
   for(int j = 1; j <= width; ++j)
     {
      const double h_left  = iHigh(_Symbol, _Period, shift + j);
      const double h_right = iHigh(_Symbol, _Period, shift - j);
      if(h_left <= 0.0 || h_right <= 0.0)
         return false;
      if(!(pivot_high > h_left) || !(pivot_high > h_right))
         return false;
     }
   return true;
  }

// ATR rolling-percentile floor: TRUE if the current ATR(shift 1) is at/above the
// `pctile`-th percentile of ATR over the last `window` closed bars. Bounded loop.
bool AtrAbovePercentile(const double atr_now, const int window, const double pctile)
  {
   if(atr_now <= 0.0)
      return false;
   if(window <= 1)
      return true;
   int below = 0;
   int counted = 0;
   for(int s = 1; s <= window; ++s)
     {
      const double a = QM_ATR(_Symbol, _Period, strategy_atr_period, s);
      if(a <= 0.0)
         continue;
      ++counted;
      if(a < atr_now)
         ++below;
     }
   if(counted <= 0)
      return false;
   const double rank_pct = 100.0 * (double)below / (double)counted;
   return (rank_pct >= pctile);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread guard needed beyond fail-open on .DWX:
// we never block on zero modeled spread. Regime/signal work is closed-bar only.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block
   // Fail-open on zero modeled spread; no genuinely-wide-spread cap configured.
   return false;
  }

// Reversal entry on confirmed stochastic divergence. Caller guarantees
// QM_IsNewBar() == true (closed-bar gate). Divergence anchors come from a
// bounded scan of CLOSED bars only.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic; no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int width = strategy_swing_width;
   if(width < 1)
      return false;

   // Volatility floor: reject flat ranges.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   if(!AtrAbovePercentile(atr_value, strategy_atr_pctile_bars, strategy_atr_pctile))
      return false;

   // Signal candle = the just-closed bar (shift 1).
   const double sig_open  = iOpen(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double sig_close = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sig_open <= 0.0 || sig_close <= 0.0)
      return false;

   // The earliest confirmable pivot shift is (width+1): it needs `width` bars to
   // its right, all closed. Scan outward to find the two most-recent confirmed
   // swing lows (long) and swing highs (short).
   const int first_shift = width + 1;
   const int last_shift  = first_shift + strategy_swing_scan_bars;

   // ---- LONG: bullish divergence on swing lows ----
   int    lo1_shift = -1; double lo1_price = 0.0;  // latest (more recent) swing low
   int    lo2_shift = -1; double lo2_price = 0.0;  // prior   (older)       swing low
   for(int s = first_shift; s <= last_shift; ++s)
     {
      if(!IsSwingLow(s, width))
         continue;
      if(lo1_shift < 0)
        { lo1_shift = s; lo1_price = iLow(_Symbol, _Period, s); }
      else
        { lo2_shift = s; lo2_price = iLow(_Symbol, _Period, s); break; }
     }

   if(lo1_shift > 0 && lo2_shift > 0 && lo1_price > 0.0 && lo2_price > 0.0)
     {
      const int gap = lo2_shift - lo1_shift; // older minus newer = bars between
      if(gap >= strategy_min_swing_gap && gap <= strategy_max_swing_gap)
        {
         // Price made a lower low; momentum made a higher low (bullish divergence).
         const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                      strategy_stoch_slow, lo1_shift);
         const double k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                      strategy_stoch_slow, lo2_shift);
         if(k1 > 0.0 && k2 > 0.0 && lo1_price < lo2_price && k1 > k2)
           {
            // Oversold confirmation: latest swing-low %K below osc_lo, OR %K
            // crossed UP through osc_cross_lo within the last 3 closed bars.
            bool oversold = (k1 < strategy_osc_lo);
            if(!oversold)
              {
               for(int b = 1; b <= 3 && !oversold; ++b)
                 {
                  const double kp = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                               strategy_stoch_slow, b + 1);
                  const double kn = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                               strategy_stoch_slow, b);
                  if(kp > 0.0 && kn > 0.0 &&
                     kp <= strategy_osc_cross_lo && kn > strategy_osc_cross_lo)
                     oversold = true;
                 }
              }
            // Signal candle bullish.
            if(oversold && sig_close > sig_open)
              {
               const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               if(entry <= 0.0)
                  return false;
               const double sl_raw = lo1_price - strategy_sl_atr_mult * atr_value;
               const double sl = QM_StopRulesNormalizePrice(_Symbol, sl_raw);
               if(sl <= 0.0 || sl >= entry)
                  return false;
               const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
               if(tp <= 0.0)
                  return false;
               req.type   = QM_BUY;
               req.price  = 0.0;
               req.sl     = sl;
               req.tp     = tp;
               req.reason = "stoch_div_long";
               g_entry_swing_price = lo1_price;
               g_entry_dir         = 1;
               g_entry_bar_time    = iTime(_Symbol, _Period, 0); // perf-allowed: latch entry bar open for time stop
               return true;
              }
           }
        }
     }

   // ---- SHORT: bearish divergence on swing highs ----
   int    hi1_shift = -1; double hi1_price = 0.0;
   int    hi2_shift = -1; double hi2_price = 0.0;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      if(!IsSwingHigh(s, width))
         continue;
      if(hi1_shift < 0)
        { hi1_shift = s; hi1_price = iHigh(_Symbol, _Period, s); }
      else
        { hi2_shift = s; hi2_price = iHigh(_Symbol, _Period, s); break; }
     }

   if(hi1_shift > 0 && hi2_shift > 0 && hi1_price > 0.0 && hi2_price > 0.0)
     {
      const int gap = hi2_shift - hi1_shift;
      if(gap >= strategy_min_swing_gap && gap <= strategy_max_swing_gap)
        {
         const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                      strategy_stoch_slow, hi1_shift);
         const double k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                      strategy_stoch_slow, hi2_shift);
         if(k1 > 0.0 && k2 > 0.0 && hi1_price > hi2_price && k1 < k2)
           {
            bool overbought = (k1 > strategy_osc_hi);
            if(!overbought)
              {
               for(int b = 1; b <= 3 && !overbought; ++b)
                 {
                  const double kp = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                               strategy_stoch_slow, b + 1);
                  const double kn = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                               strategy_stoch_slow, b);
                  if(kp > 0.0 && kn > 0.0 &&
                     kp >= strategy_osc_cross_hi && kn < strategy_osc_cross_hi)
                     overbought = true;
                 }
              }
            if(overbought && sig_close < sig_open)
              {
               const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(entry <= 0.0)
                  return false;
               const double sl_raw = hi1_price + strategy_sl_atr_mult * atr_value;
               const double sl = QM_StopRulesNormalizePrice(_Symbol, sl_raw);
               if(sl <= 0.0 || sl <= entry)
                  return false;
               const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
               if(tp <= 0.0)
                  return false;
               req.type   = QM_SELL;
               req.price  = 0.0;
               req.sl     = sl;
               req.tp     = tp;
               req.reason = "stoch_div_short";
               g_entry_swing_price = hi1_price;
               g_entry_dir         = -1;
               g_entry_bar_time    = iTime(_Symbol, _Period, 0); // perf-allowed: latch entry bar open for time stop
               return true;
              }
           }
        }
     }

   return false;
  }

// Fixed ATR stop / RR target handle the protective exits; no trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits: oscillator exit, failure exit beyond the entry swing,
// and a time stop. Evaluated on each new closed bar (OnTick gates closes by
// magic). Reads %K, ATR and prior CLOSE — all closed-bar values.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
     {
      // Flat: clear latched anchors so a stale anchor never leaks into the next trade.
      g_entry_dir = 0;
      return false;
     }
   if(g_entry_dir == 0)
      return false; // anchor not latched (e.g. restored position) — defer to SL/TP

   const double k_now = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                   strategy_stoch_slow, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(close1 <= 0.0)
      return false;

   // Time stop: count closed H4 bars since entry.
   if(g_entry_bar_time > 0)
     {
      // perf-allowed: maps the latched entry bar to a closed-bar count.
      const int bars_since = iBarShift(_Symbol, _Period, g_entry_bar_time, false);
      if(bars_since >= strategy_time_stop_bars)
         return true;
     }

   if(g_entry_dir > 0) // LONG
     {
      // Oscillator exit: %K closes above osc_exit_hi.
      if(k_now > 0.0 && k_now > strategy_osc_exit_hi)
         return true;
      // Failure exit: price closes beyond (below) the entry swing by fail_atr_mult*ATR.
      if(atr_value > 0.0 && g_entry_swing_price > 0.0)
        {
         const double fail_level = g_entry_swing_price - strategy_fail_atr_mult * atr_value;
         if(close1 < fail_level)
            return true;
        }
     }
   else // SHORT
     {
      if(k_now > 0.0 && k_now < strategy_osc_exit_lo)
         return true;
      if(atr_value > 0.0 && g_entry_swing_price > 0.0)
        {
         const double fail_level = g_entry_swing_price + strategy_fail_atr_mult * atr_value;
         if(close1 > fail_level)
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
