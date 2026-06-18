#property strict
#property version   "5.0"
#property description "QM5_11392 justforex-momentum7-divergence-fib — Momentum(7) divergence + Fib extension (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11392 justforex-momentum7-divergence-fib
// -----------------------------------------------------------------------------
// Source: "Momentum Power Strategy" (JustForexSignals.com, anonymous), local PDF.
// Card: artifacts/cards_approved/QM5_11392_justforex-momentum7-divergence-fib.md
//       (g0_status APPROVED).
//
// Mechanics (H4, all reads on CLOSED bars, non-repainting):
//   Swing pivots : N-bar fractal. bar at shift s is a swing LOW iff its Low is
//                  strictly below the Low of the N bars on EACH side. The most
//                  recent CONFIRMABLE pivot therefore sits at shift >= N+1 (it
//                  has N closed bars to its right). Nothing references shift 0
//                  or an unclosed right shoulder -> non-repainting + bounded.
//   Divergence   : (LONG) two most-recent confirmed swing lows L1 (older) and
//                  L2 (newer) with Low(L2) < Low(L1)  AND  Mom(L2) > Mom(L1)
//                  (price lower low, momentum higher low). SHORT is the mirror
//                  on confirmed swing highs.
//   Trigger EVENT: the SINGLE event is Momentum(7) breaking its own pivot. For
//                  LONG that pivot is the MAX momentum on the bars strictly
//                  between L1 and L2 (the peak between the two lows). The break
//                  is a fresh cross: Mom[2] <= peak AND Mom[1] > peak -> one bar.
//                  SHORT mirrors with the trough (MIN momentum) between highs.
//   RSI filter   : optional. LONG requires RSI(7) > rsi_long_floor (not deeply
//                  oversold); SHORT requires RSI(7) < rsi_short_ceil.
//   Stop loss    : swing extreme opposite the trade, padded sl_buffer_pips, then
//                  capped at sl_cap_pips (card P2 cap 40 pips H4).
//   Take profit  : Fibonacci extension of the divergence leg. LONG leg =
//                  swing_high_between - L2_low; TP = entry + fib_tp_ext * leg.
//                  fib_tp_ext default 1.618 (161.8% extension), per card TP1.
//   Spread guard : fail-OPEN on .DWX zero modeled spread; block only a genuinely
//                  wide spread > spread_pct_of_stop of the stop distance.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact. Momentum(7) read via QM_Momentum
// (handle-pooled). Bounded structural Low/High scans use raw iLow/iHigh with a
// documented perf-allowed exception (bespoke pivot logic, no QM reader exists).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11392;
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
input int    strategy_mom_period         = 7;     // Momentum(7) period (rate-of-change)
input int    strategy_rsi_period         = 7;     // RSI(7) optional confirmation filter
input bool   strategy_use_rsi_filter     = true;  // apply RSI not-oversold/overbought gate
input double strategy_rsi_long_floor     = 20.0;  // LONG requires RSI > this (not oversold)
input double strategy_rsi_short_ceil     = 80.0;  // SHORT requires RSI < this (not overbought)
input int    strategy_fractal_n          = 3;     // N-bar fractal half-width (swing detect)
input int    strategy_pivot_lookback     = 60;    // bounded closed-bar window for pivot scan
input double strategy_fib_tp_ext         = 1.618; // Fib extension multiple of divergence leg
input int    strategy_sl_buffer_pips     = 5;     // pad beyond swing extreme (card: 5 pips)
input int    strategy_sl_cap_pips        = 40;    // max stop distance (card P2 cap: 40 pips H4)
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Bounded, non-repainting swing-pivot helpers.
// A swing LOW at shift s: Low[s] strictly below Low on N bars each side. Caller
// only ever passes s >= N+1, so the right shoulder (s-1 .. s-N) is fully closed
// -> deterministic, never repaints. Returns false if any required bar missing.
// -----------------------------------------------------------------------------
bool IsSwingLow(const int s, const int n)
  {
   const double pivot = iLow(_Symbol, _Period, s); // perf-allowed: bespoke pivot scan
   if(pivot <= 0.0)
      return false;
   for(int k = 1; k <= n; ++k)
     {
      const double l_left  = iLow(_Symbol, _Period, s + k); // perf-allowed
      const double l_right = iLow(_Symbol, _Period, s - k); // perf-allowed
      if(l_left <= 0.0 || l_right <= 0.0)
         return false;
      if(!(pivot < l_left) || !(pivot < l_right))
         return false;
     }
   return true;
  }

bool IsSwingHigh(const int s, const int n)
  {
   const double pivot = iHigh(_Symbol, _Period, s); // perf-allowed: bespoke pivot scan
   if(pivot <= 0.0)
      return false;
   for(int k = 1; k <= n; ++k)
     {
      const double h_left  = iHigh(_Symbol, _Period, s + k); // perf-allowed
      const double h_right = iHigh(_Symbol, _Period, s - k); // perf-allowed
      if(h_left <= 0.0 || h_right <= 0.0)
         return false;
      if(!(pivot > h_left) || !(pivot > h_right))
         return false;
     }
   return true;
  }

// Find the two most recent confirmed swing lows scanning OLD-to-NEW shifts.
// out_new = newer (smaller shift), out_old = older (larger shift). The right
// shoulder of the newest pivot is fully closed because the smallest candidate
// shift is n+1. Returns true only when two distinct pivots are found.
bool FindLastTwoSwingLows(const int n, const int lookback, int &out_new, int &out_old)
  {
   out_new = -1;
   out_old = -1;
   const int first = n + 1;             // smallest non-repainting shift
   const int last  = first + lookback;  // bounded window
   for(int s = first; s <= last; ++s)
     {
      if(!IsSwingLow(s, n))
         continue;
      if(out_new < 0)
        {
         out_new = s;
         continue;
        }
      out_old = s;
      return true;
     }
   return false;
  }

bool FindLastTwoSwingHighs(const int n, const int lookback, int &out_new, int &out_old)
  {
   out_new = -1;
   out_old = -1;
   const int first = n + 1;
   const int last  = first + lookback;
   for(int s = first; s <= last; ++s)
     {
      if(!IsSwingHigh(s, n))
         continue;
      if(out_new < 0)
        {
         out_new = s;
         continue;
        }
      out_old = s;
      return true;
     }
   return false;
  }

// Highest High on the bars strictly between shifts hi_shift (older) and
// lo_shift (newer), i.e. shifts (lo_shift+1 .. hi_shift-1). Used for the LONG
// Fib leg swing-high. Returns 0.0 if the interval is empty/invalid.
double HighestBetween(const int newer_shift, const int older_shift)
  {
   double best = 0.0;
   for(int s = newer_shift + 1; s <= older_shift - 1; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed
      if(h > best)
         best = h;
     }
   return best;
  }

double LowestBetween(const int newer_shift, const int older_shift)
  {
   double best = 0.0;
   for(int s = newer_shift + 1; s <= older_shift - 1; ++s)
     {
      const double l = iLow(_Symbol, _Period, s); // perf-allowed
      if(l > 0.0 && (best <= 0.0 || l < best))
         best = l;
     }
   return best;
  }

// Max / min Momentum on the bars strictly between two pivot shifts (the pivot
// the trigger event must break). Bounded loop over the divergence interval.
double MomentumPeakBetween(const int newer_shift, const int older_shift)
  {
   double peak = 0.0;
   for(int s = newer_shift + 1; s <= older_shift - 1; ++s)
     {
      const double m = QM_Momentum(_Symbol, _Period, strategy_mom_period, s);
      if(m > peak)
         peak = m;
     }
   return peak;
  }

double MomentumTroughBetween(const int newer_shift, const int older_shift)
  {
   double trough = 0.0;
   for(int s = newer_shift + 1; s <= older_shift - 1; ++s)
     {
      const double m = QM_Momentum(_Symbol, _Period, strategy_mom_period, s);
      if(m > 0.0 && (trough <= 0.0 || m < trough))
         trough = m;
     }
   return trough;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — all pivot/divergence work is on
// the closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on it

   // Spread cap scaled to a typical stop distance (the cap in pips).
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Fresh momentum samples for the break EVENT (shift 1 = last closed bar).
   const double mom_now  = QM_Momentum(_Symbol, _Period, strategy_mom_period, 1);
   const double mom_prev = QM_Momentum(_Symbol, _Period, strategy_mom_period, 2);
   if(mom_now <= 0.0 || mom_prev <= 0.0)
      return false;

   // ---------------- LONG: bullish divergence -----------------------------
   int lo_new = -1, lo_old = -1;
   if(FindLastTwoSwingLows(strategy_fractal_n, strategy_pivot_lookback, lo_new, lo_old))
     {
      const double low_new = iLow(_Symbol, _Period, lo_new); // perf-allowed
      const double low_old = iLow(_Symbol, _Period, lo_old); // perf-allowed
      const double mom_at_new = QM_Momentum(_Symbol, _Period, strategy_mom_period, lo_new);
      const double mom_at_old = QM_Momentum(_Symbol, _Period, strategy_mom_period, lo_old);

      const bool price_lower_low   = (low_new > 0.0 && low_old > 0.0 && low_new < low_old);
      const bool momentum_higher_low = (mom_at_new > 0.0 && mom_at_old > 0.0 && mom_at_new > mom_at_old);

      if(price_lower_low && momentum_higher_low)
        {
         // Pivot to break = peak momentum between the two lows.
         const double mom_peak = MomentumPeakBetween(lo_new, lo_old);
         if(mom_peak > 0.0)
           {
            // SINGLE EVENT: fresh upward break of that peak this bar.
            const bool broke_up = (mom_prev <= mom_peak && mom_now > mom_peak);
            if(broke_up)
              {
               bool rsi_ok = true;
               if(strategy_use_rsi_filter)
                 {
                  const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
                  rsi_ok = (rsi > strategy_rsi_long_floor);
                 }
               if(rsi_ok)
                 {
                  const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  const double swing_high = HighestBetween(lo_new, lo_old);
                  if(entry > 0.0 && swing_high > low_new)
                    {
                     // Stop: swing low (newer) padded; capped at sl_cap_pips.
                     const double pad = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
                     const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
                     double sl = low_new - pad;
                     if(entry - sl > cap)
                        sl = entry - cap;
                     // Fib extension TP off the divergence leg.
                     const double leg = swing_high - low_new;
                     const double tp = entry + strategy_fib_tp_ext * leg;
                     if(sl > 0.0 && sl < entry && tp > entry)
                       {
                        req.type   = QM_BUY;
                        req.price  = 0.0;
                        req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
                        req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
                        req.reason = "mom7_div_fib_long";
                        return true;
                       }
                    }
                 }
              }
           }
        }
     }

   // ---------------- SHORT: bearish divergence ----------------------------
   int hi_new = -1, hi_old = -1;
   if(FindLastTwoSwingHighs(strategy_fractal_n, strategy_pivot_lookback, hi_new, hi_old))
     {
      const double high_new = iHigh(_Symbol, _Period, hi_new); // perf-allowed
      const double high_old = iHigh(_Symbol, _Period, hi_old); // perf-allowed
      const double mom_at_new = QM_Momentum(_Symbol, _Period, strategy_mom_period, hi_new);
      const double mom_at_old = QM_Momentum(_Symbol, _Period, strategy_mom_period, hi_old);

      const bool price_higher_high   = (high_new > 0.0 && high_old > 0.0 && high_new > high_old);
      const bool momentum_lower_high  = (mom_at_new > 0.0 && mom_at_old > 0.0 && mom_at_new < mom_at_old);

      if(price_higher_high && momentum_lower_high)
        {
         const double mom_trough = MomentumTroughBetween(hi_new, hi_old);
         if(mom_trough > 0.0)
           {
            const bool broke_down = (mom_prev >= mom_trough && mom_now < mom_trough);
            if(broke_down)
              {
               bool rsi_ok = true;
               if(strategy_use_rsi_filter)
                 {
                  const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
                  rsi_ok = (rsi < strategy_rsi_short_ceil);
                 }
               if(rsi_ok)
                 {
                  const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  const double swing_low = LowestBetween(hi_new, hi_old);
                  if(entry > 0.0 && swing_low > 0.0 && high_new > swing_low)
                    {
                     const double pad = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
                     const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
                     double sl = high_new + pad;
                     if(sl - entry > cap)
                        sl = entry + cap;
                     const double leg = high_new - swing_low;
                     const double tp = entry - strategy_fib_tp_ext * leg;
                     if(sl > entry && tp > 0.0 && tp < entry)
                       {
                        req.type   = QM_SELL;
                        req.price  = 0.0;
                        req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
                        req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
                        req.reason = "mom7_div_fib_short";
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

// Fixed Fib TP + structural stop manage the trade; no active trailing here.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP. Divergence resolves into the Fib target
// or the structural stop.
bool Strategy_ExitSignal()
  {
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
