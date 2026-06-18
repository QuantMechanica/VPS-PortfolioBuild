#property strict
#property version   "5.0"
#property description "QM5_11715 tradingwalk-abc-fib-extension — ABC + Fibonacci extension reversal (H1, D1 macro filter)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11715 tradingwalk-abc-fib-extension
// -----------------------------------------------------------------------------
// Source: Johan Nordstrom (TradingWalk), "Winning Trading Strategy" PDF (2015),
//         source_id 694f33c6-526a-56b2-8b1c-364efb192124.
// Card: artifacts/cards_approved/QM5_11715_tradingwalk-abc-fib-extension.md
//       (g0_status APPROVED).
//
// Concept: Fibonacci ABC extension reversal, aligned to a D1 macro trend.
//
//   Macro STATE (D1): downtrend = Close_D1 < SMA(50,D1); uptrend = inverse.
//
//   ABC structure (H1, computed in-EA from 3-bar fractal swings on closed bars):
//     Downtrend context (SHORT setups):
//       A = most recent confirmed swing HIGH.
//       B = most recent confirmed swing LOW that occurred AFTER A.
//       AB = A - B   (price distance of the down leg, A > B).
//       Fib extension zone ABOVE A (the C-leg overshoot before resumption):
//         LowerZone = A + ext_lo * AB   (ext_lo = 1.279)
//         UpperZone = A + ext_hi * AB   (ext_hi = 1.618)
//     Uptrend context (LONG setups): mirror — A = swing LOW, B = rally HIGH
//       after A, AB = B - A, zone BELOW A:
//         UpperZone(near) = A - ext_lo * AB
//         LowerZone(far)  = A - ext_hi * AB
//
//   Setup STATE  : C-leg has pushed price into the [LowerZone, UpperZone] Fib
//                  extension band, beyond A (Close beyond A in the C-leg dir).
//   Trigger EVENT: the closed bar's close FIRST ENTERS that band — i.e. the
//                  previous closed bar's close was outside the band and the
//                  latest closed bar's close is inside it. One clean event per
//                  bar (no two-cross-same-bar trap, no every-bar re-fire while
//                  parked inside the zone).
//   Direction    : SHORT in a macro downtrend, LONG in a macro uptrend
//                  (extension reversal back toward the macro trend).
//   Stop         : SHORT -> UpperZone + buffer (above the 1.618 extension);
//                  LONG  -> LowerZone - buffer (below the 1.618 extension).
//   Take profit  : factory default 1:1 risk-reward from the stop distance,
//                  which targets ~A -/+ AB (back toward the B swing). Capped so
//                  it never points the wrong side of entry.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
//
// Symbols: GBPJPY.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX — all present in
// framework/registry/dwx_symbol_matrix.csv (no porting required).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11715;
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
input int    strategy_macro_ma_period    = 50;     // D1 SMA period for macro trend filter
input int    strategy_swing_fractal_n    = 1;      // fractal half-width (n bars each side; card's 3-bar window = n=1)
input int    strategy_swing_lookback     = 60;     // closed H1 bars scanned for swing A/B
input double strategy_ext_lo             = 1.279;  // near Fib extension multiple of AB
input double strategy_ext_hi             = 1.618;  // far  Fib extension multiple of AB
input double strategy_sl_buffer_pips     = 5.0;    // SL buffer beyond the far extension, in pips
input double strategy_target_rr          = 1.0;    // take-profit risk-reward multiple
input double strategy_max_spread_pips    = 6.0;    // skip only a genuinely wide spread (pips)

// -----------------------------------------------------------------------------
// File-scope cached ABC state — advanced once per closed H1 bar.
// -----------------------------------------------------------------------------
// dir: +1 = macro uptrend (LONG setups), -1 = macro downtrend (SHORT setups),
//       0 = no valid macro/ABC structure this bar.
int    g_setup_dir       = 0;
double g_a_price         = 0.0;
double g_b_price         = 0.0;
double g_zone_lo         = 0.0;   // lower price bound of the extension band
double g_zone_hi         = 0.0;   // upper price bound of the extension band
bool   g_cur_close_in    = false; // is the latest closed bar (shift 1) close inside the band?
bool   g_prev_close_in   = false; // was the prior closed bar (shift 2) close inside the band?
bool   g_state_valid      = false;

// Pip size for the active symbol (5-digit / JPY aware).
double PipSize()
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pt   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return pt * 10.0;
   return pt;
  }

// Find the most recent confirmed fractal swing in the closed-bar window.
// want_high=true -> swing high; false -> swing low. Returns shift via out_shift
// and price via out_price; false if none found. Confirmed fractal: a center bar
// strictly beyond its `n` neighbours on each side. Bounded scan: at most
// (lookback * (2n)) cheap comparisons per closed bar.
bool FindSwing(const bool want_high, const int n, const int lookback,
               int &out_shift, double &out_price)
  {
   // Center bar must have n confirmed bars to its right, so the nearest
   // testable center is at shift n+1 (shift 1 is the latest closed bar).
   const int first_center = n + 1;
   const int last_center  = lookback;
   for(int c = first_center; c <= last_center; ++c)
     {
      const double cval = want_high ? iHigh(_Symbol, _Period, c)   // perf-allowed: bounded structural swing scan
                                    : iLow(_Symbol, _Period, c);   // perf-allowed
      if(cval <= 0.0)
         continue;
      bool is_swing = true;
      for(int k = 1; k <= n && is_swing; ++k)
        {
         const double left  = want_high ? iHigh(_Symbol, _Period, c + k)  // perf-allowed
                                         : iLow(_Symbol, _Period, c + k); // perf-allowed
         const double right = want_high ? iHigh(_Symbol, _Period, c - k)  // perf-allowed
                                         : iLow(_Symbol, _Period, c - k); // perf-allowed
         if(left <= 0.0 || right <= 0.0)
           { is_swing = false; break; }
         if(want_high)
           {
            if(!(cval > left) || !(cval > right))
               is_swing = false;
           }
         else
           {
            if(!(cval < left) || !(cval < right))
               is_swing = false;
           }
        }
      if(is_swing)
        {
         out_shift = c;
         out_price = cval;
         return true;
        }
     }
   return false;
  }

// Recompute the cached ABC structure + Fib extension band once per closed bar.
void AdvanceState_OnNewBar()
  {
   // Membership of shift-1 (current) and shift-2 (previous) closed bars against
   // the freshly-computed band is recomputed from scratch every bar — no
   // cross-call latch race. The "first entry" event is cur_in && !prev_in.
   g_state_valid   = false;
   g_setup_dir     = 0;
   g_a_price       = 0.0;
   g_b_price       = 0.0;
   g_zone_lo       = 0.0;
   g_zone_hi       = 0.0;
   g_cur_close_in  = false;
   g_prev_close_in = false;

   // --- Macro trend on D1 (closed-bar reads via QM helpers) ---
   const double sma_d1   = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_ma_period, 1, PRICE_CLOSE);
   const double close_d1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed-bar read
   if(sma_d1 <= 0.0 || close_d1 <= 0.0)
      return;

   const int n        = (strategy_swing_fractal_n < 1) ? 1 : strategy_swing_fractal_n;
   const int lookback = (strategy_swing_lookback < (2 * n + 2)) ? (2 * n + 2) : strategy_swing_lookback;

   if(close_d1 < sma_d1)
     {
      // ---- Macro DOWNTREND -> SHORT setups. A = swing high, B = swing low after A.
      int    a_shift = 0; double a_price = 0.0;
      if(!FindSwing(true, n, lookback, a_shift, a_price))
         return;
      // B = most recent swing low that is OLDER than A (occurred after A in time
      // means a smaller shift; but B must be the low of the A->B down leg, which
      // is between A and now => shift < a_shift). Scan for a swing low at a
      // shift strictly less than a_shift.
      double b_price = 0.0;
      bool   found_b = false;
      const int b_first = n + 1;
      for(int c = b_first; c < a_shift; ++c)
        {
         const double lo = iLow(_Symbol, _Period, c); // perf-allowed
         if(lo <= 0.0) continue;
         bool is_low = true;
         for(int k = 1; k <= n && is_low; ++k)
           {
            const double left  = iLow(_Symbol, _Period, c + k); // perf-allowed
            const double right = iLow(_Symbol, _Period, c - k); // perf-allowed
            if(left <= 0.0 || right <= 0.0) { is_low = false; break; }
            if(!(lo < left) || !(lo < right)) is_low = false;
           }
         if(is_low) { b_price = lo; found_b = true; break; }
        }
      if(!found_b)
         return;
      const double AB = a_price - b_price;
      if(AB <= 0.0)
         return;

      g_setup_dir = -1;
      g_a_price   = a_price;
      g_b_price   = b_price;
      g_zone_lo   = a_price + strategy_ext_lo * AB; // near extension
      g_zone_hi   = a_price + strategy_ext_hi * AB; // far  extension
      g_state_valid = true;
     }
   else
     {
      // ---- Macro UPTREND -> LONG setups. A = swing low, B = rally high after A.
      int    a_shift = 0; double a_price = 0.0;
      if(!FindSwing(false, n, lookback, a_shift, a_price))
         return;
      double b_price = 0.0;
      bool   found_b = false;
      const int b_first = n + 1;
      for(int c = b_first; c < a_shift; ++c)
        {
         const double hi = iHigh(_Symbol, _Period, c); // perf-allowed
         if(hi <= 0.0) continue;
         bool is_high = true;
         for(int k = 1; k <= n && is_high; ++k)
           {
            const double left  = iHigh(_Symbol, _Period, c + k); // perf-allowed
            const double right = iHigh(_Symbol, _Period, c - k); // perf-allowed
            if(left <= 0.0 || right <= 0.0) { is_high = false; break; }
            if(!(hi > left) || !(hi > right)) is_high = false;
           }
         if(is_high) { b_price = hi; found_b = true; break; }
        }
      if(!found_b)
         return;
      const double AB = b_price - a_price;
      if(AB <= 0.0)
         return;

      g_setup_dir = +1;
      g_a_price   = a_price;
      g_b_price   = b_price;
      g_zone_lo   = a_price - strategy_ext_hi * AB; // far  extension (below)
      g_zone_hi   = a_price - strategy_ext_lo * AB; // near extension (below)
      g_state_valid = true;
     }

   // --- Membership of the two latest closed bars against the band. The entry
   //     EVENT is "shift-1 inside AND shift-2 outside" = first-entry into the
   //     Fib extension band. Recomputed every bar; no cross-call latch. ---
   if(g_state_valid)
     {
      const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
      const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
      g_cur_close_in  = (close1 > 0.0 && close1 >= g_zone_lo && close1 <= g_zone_hi);
      g_prev_close_in = (close2 > 0.0 && close2 >= g_zone_lo && close2 <= g_zone_hi);
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — do not block on it

   const double spread = ask - bid;
   const double cap    = strategy_max_spread_pips * PipSize();
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;
   return false;
  }

// ABC + Fib extension entry. Caller guarantees QM_IsNewBar() == true and that
// AdvanceState_OnNewBar() already refreshed the cached band THIS bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_state_valid || g_setup_dir == 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // STATE + EVENT (both precomputed once per closed bar in AdvanceState):
   //   STATE  : latest closed bar (shift 1) close inside the Fib extension band.
   //   EVENT  : prior closed bar (shift 2) was OUTSIDE the band -> first entry.
   // This is the single trigger event; it cannot collide with a second cross on
   // the same bar, and it does not re-fire while price is parked inside the zone.
   if(!g_cur_close_in)
      return false;
   if(g_prev_close_in)
      return false; // already inside last bar -> not a fresh entry event

   // Direction must extend BEYOND A in the C-leg direction (overshoot of A).
   if(g_setup_dir < 0)
     {
      // SHORT: extension is above A.
      if(!(close1 > g_a_price))
         return false;
     }
   else
     {
      // LONG: extension is below A.
      if(!(close1 < g_a_price))
         return false;
     }

   const double buffer = strategy_sl_buffer_pips * PipSize();

   if(g_setup_dir < 0)
     {
      // ---- SHORT entry ----
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      // SL above the far (1.618) extension + buffer.
      double sl = g_zone_hi + buffer;
      if(!(sl > entry))
         return false; // degenerate geometry — skip
      const double risk = sl - entry;
      double tp = entry - strategy_target_rr * risk;
      if(!(tp < entry) || tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0; // framework fills market price at send
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "abc_fib_ext_short";
      return true;
     }
   else
     {
      // ---- LONG entry ----
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // SL below the far (1.618) extension + buffer.
      double sl = g_zone_lo - buffer;
      if(!(sl < entry) || sl <= 0.0)
         return false; // degenerate geometry — skip
      const double risk = entry - sl;
      double tp = entry + strategy_target_rr * risk;
      if(!(tp > entry))
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "abc_fib_ext_long";
      return true;
     }
  }

// Fixed SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP / pattern invalidation (SL above 1.618
// covers invalidation). Exit handled by the bracket.
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

   // Refresh cached ABC structure + Fib band ONCE per closed bar before entry.
   AdvanceState_OnNewBar();

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
