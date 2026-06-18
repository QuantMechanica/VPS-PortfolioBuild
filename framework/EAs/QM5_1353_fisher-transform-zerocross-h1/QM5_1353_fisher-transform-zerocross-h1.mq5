#property strict
#property version   "5.0"
#property description "QM5_1353 fisher-transform-zerocross-h1 — Ehlers Fisher Transform zero-line cross entry, extreme-zone exit (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1353 fisher-transform-zerocross-h1
// -----------------------------------------------------------------------------
// Source: John F. Ehlers, "Cybernetic Analysis for Stocks and Futures"
//   (Wiley 2004, ISBN 978-0471463078), Fisher Transform chapter; Stocks &
//   Commodities Nov 2002. FF Trading-Systems Fisher cluster
//   (source_id 6e967762-b26d-59a3-b076-35c17f2e7c36).
// Card: artifacts/cards_approved/QM5_1353_fisher-transform-zerocross-h1.md
//   (g0 APPROVED). NOTE: card frontmatter carries a STALE ea_id "QM5_12146";
//   the canonical build target for this slug is ea_id 1353 (used here as
//   qm_ea_id). Flagged in build_result.frontmatter_mismatch.
//
// Ehlers Fisher Transform — inverse-hyperbolic transform of a normalized price
// oscillator. Computed entirely in-EA (no built-in indicator handle exists);
// the recursive value1 / Fisher series are reconstructed over a bounded warmup
// window on the CLOSED-BAR path only (Strategy_EntrySignal / Strategy_ExitSignal
// run under the QM_IsNewBar gate). No raw indicator handles, no CopyBuffer;
// ATR/EMA are read via the pooled QM_* readers.
//
//   For each closed bar t with lookback N (= fisher_lookback, Ehlers default 10):
//     midpoint_t = (high_t + low_t) / 2
//     HH_t       = max(midpoint[t-N+1..t]),  LL_t = min(midpoint[t-N+1..t])
//     raw_t      = (HH_t > LL_t) ? ((midpoint_t - LL_t)/(HH_t - LL_t) - 0.5) : 0
//     value1_t   = 0.66*raw_t + 0.67*value1_{t-1}          // Ehlers smoothing
//     value1_t   = clamp(value1_t, -clamp_lim, +clamp_lim) // keep log domain safe
//     Fisher_t   = 0.5*log((1+value1_t)/(1-value1_t)) + 0.5*Fisher_{t-1}
//
//   Output Fisher_t is unbounded but typically in [-2.5,+2.5]; |Fisher| > ~2 is
//   a rare-event extreme per Ehlers. The clamp on value1 prevents the ln domain
//   blowup at value1 = +/-1 (HH ~= LL degeneracy).
//
//   Entry (BUY) on the H1 close:
//     1. Zero-line cross UP = the single trigger EVENT:
//          Fisher[1] <= 0  AND  Fisher[0] > 0.
//        (shift 0 = last fully-closed bar under the QM_IsNewBar gate; shift 1 =
//         the bar before it.)
//     2. Prior dip STATE: min(Fisher[1..dip_lookback]) < -dip_threshold
//        (came from a meaningful low before crossing — kills shallow chop).
//     3. Macro bias STATE: close[0] > EMA(close, macro) on H1.
//   SELL mirrors: Fisher[1] >= 0 AND Fisher[0] < 0; max(Fisher[1..dip]) > +dip;
//        close[0] < EMA(macro).
//
//   Only the zero-line cross is an EVENT; the prior-dip and macro-bias are
//   STATES — no two-fresh-cross-same-bar zero-trade trap.
//
//   Exit (closed-bar, any of):
//     - Extreme-zone exit (primary): BUY closes when Fisher > +extreme_z;
//       SELL closes when Fisher < -extreme_z (Ehlers rare-extreme = turn imminent).
//     - Zero-line cross-back (secondary): BUY closes when Fisher crosses back
//       below zero; SELL closes when it crosses back above zero.
//     - Time-stop: position held >= time_stop_bars H1 bars → close.
//   Stop : entry -/+ sl_atr_mult * ATR(atr_period) (hard SL).
//   Take : tp_atr_mult * ATR from entry, expressed via QM_TakeRR off the stop
//          (acts as the alternative exit if neither Fisher exit fires first).
//
//   Session     : trade only inside [session_start_h, session_end_h) broker time
//                 (06:00-22:00 per card). O(1) per-tick gate.
//   Spread guard: only a genuinely wide spread blocks (fail-OPEN on .DWX zero
//                 modeled spread, ask == bid).
//   Re-arm      : one position per magic; the extreme/zero-cross-back exits mean
//                 a fresh zero-cross + prior-dip is required to re-enter (forces
//                 a full Fisher cycle, matching the card's "one zero-cross per
//                 direction" rule).
//   Numerical-safety: if value1 hits the clamp on the signal bar (HH ~= LL
//                 degeneracy), the Fisher signal for that bar is suppressed.
//
//   One position per magic. RISK_FIXED in tester, RISK_PERCENT live. No ML, no
//   external feed, $0-swap-independent (pure price-transform rule). All Fisher
//   math is fixed closed-form over bounded closed-bar windows — transparent
//   non-ML computation (HR14 compliant).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1353;
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
input int    fisher_lookback            = 10;    // N for HH/LL midpoint window (Ehlers default; P3 sweep 5-14)
input double fisher_clamp_lim           = 0.999; // value1 clamp to keep log domain safe
input double fisher_dip_threshold       = 1.0;   // prior dip/peak magnitude before the zero-cross (card 1.0)
input int    fisher_dip_lookback        = 10;    // bars back to scan for the prior dip/peak (card 10)
input double fisher_extreme_z           = 2.0;   // |Fisher| extreme-zone exit threshold (Ehlers ~95th pct)
input int    strategy_macro_ema_period  = 200;   // macro-bias EMA gate (card EMA200)
input int    strategy_atr_period        = 14;    // ATR period for stop/target (card 14)
input double strategy_sl_atr_mult       = 1.8;   // stop = entry -/+ mult*ATR (card 1.8, P3 1.2-2.5)
input double strategy_tp_atr_mult       = 2.5;   // take profit = mult*ATR from entry (card 2.5)
input int    strategy_time_stop_bars    = 36;    // close after N H1 bars without exit (card 36)
input int    strategy_session_start_h   = 6;     // broker-hour session open (inclusive, card 06:00)
input int    strategy_session_end_h     = 22;    // broker-hour session close (exclusive, card 22:00)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy helpers — Ehlers Fisher Transform computed in-EA.
// -----------------------------------------------------------------------------

// Normalized-midpoint "raw" oscillator value for one closed-bar shift: the
// position of the bar midpoint within its N-bar high/low midpoint range, mapped
// to [-0.5, +0.5]. Returns ok=false on warmup / degenerate (HH ~= LL) reads.
double FisherRawAt(const int shift, bool &ok)
  {
   ok = false;
   const int n = (fisher_lookback > 0 ? fisher_lookback : 10);
   double hh = -DBL_MAX, ll = DBL_MAX, mid0 = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const int s = shift + k;
      const double hi = iHigh(_Symbol, _Period, s); // perf-allowed: bounded closed-bar midpoint window
      const double lo = iLow(_Symbol, _Period, s);  // perf-allowed
      if(hi <= 0.0 || lo <= 0.0)
         return 0.0;
      const double mid = 0.5 * (hi + lo);
      if(k == 0)
         mid0 = mid;
      if(mid > hh) hh = mid;
      if(mid < ll) ll = mid;
     }
   if(hh - ll <= 0.0)
      return 0.0; // HH ~= LL degeneracy -> caller suppresses signal on this bar
   ok = true;
   return ((mid0 - ll) / (hh - ll)) - 0.5;
  }

// Fisher Transform at a closed-bar shift. Reconstructs the recursive value1 and
// Fisher series over a bounded warmup window, seeded at the oldest bar and
// rolled forward to `shift`. Closed-bar path only. Sets clamp_hit=true if the
// value1 clamp fired on the target bar (numerical-safety: suppress that signal).
double FisherAt(const int shift, bool &ok, bool &clamp_hit)
  {
   ok = false;
   clamp_hit = false;
   const double clim = (fisher_clamp_lim > 0.0 && fisher_clamp_lim < 1.0 ? fisher_clamp_lim : 0.999);
   // Warmup depth: the 0.67 recursion has a slow decay; 60 bars is ample for
   // value1/Fisher to converge well below the floating-point noise floor.
   const int warmup = 60;
   const int oldest = shift + warmup;

   bool seed_ok = false;
   double value1 = FisherRawAt(oldest, seed_ok);
   if(!seed_ok)
      return 0.0;             // no warmup data available
   value1 = 0.66 * value1;    // seed the smoother with the raw (value1_{prev}=0)
   if(value1 >  clim) value1 =  clim;
   if(value1 < -clim) value1 = -clim;
   double fisher = 0.5 * MathLog((1.0 + value1) / (1.0 - value1));

   for(int s = oldest - 1; s >= shift; --s)
     {
      bool r_ok = false;
      const double raw = FisherRawAt(s, r_ok);
      bool hit = false;
      double r = raw;
      if(!r_ok)
         { r = 0.0; hit = true; } // degenerate bar -> treat raw as neutral, flag
      value1 = 0.66 * r + 0.67 * value1;
      if(value1 >  clim) { value1 =  clim; hit = true; }
      if(value1 < -clim) { value1 = -clim; hit = true; }
      fisher = 0.5 * MathLog((1.0 + value1) / (1.0 - value1)) + 0.5 * fisher;
      if(s == shift)
         clamp_hit = hit;
     }

   ok = true;
   return fisher;
  }

// Broker-time session gate: true if `broker_now` is inside the [start, end) hour
// window. Wrap-safe. O(1).
bool InSession(const datetime broker_now)
  {
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   const int h = dt.hour;
   if(strategy_session_start_h == strategy_session_end_h)
      return true; // degenerate full-day
   if(strategy_session_start_h < strategy_session_end_h)
      return (h >= strategy_session_start_h && h < strategy_session_end_h);
   return (h >= strategy_session_start_h || h < strategy_session_end_h); // overnight wrap
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window + spread guard. The Fisher
// computation is on the closed-bar path in Strategy_EntrySignal. Fail-OPEN on
// .DWX zero modeled spread (ask == bid).
bool Strategy_NoTradeFilter()
  {
   if(!InSession(TimeCurrent()))
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Fisher zero-line-cross + prior-dip + macro-bias entry. Caller guarantees
// QM_IsNewBar() == true. Shift 0 = last fully-closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   bool f0_ok=false, f1_ok=false, clamp0=false, clamp1=false;
   const double f0 = FisherAt(0, f0_ok, clamp0);
   const double f1 = FisherAt(1, f1_ok, clamp1);
   if(!(f0_ok && f1_ok))
      return false;          // warmup / unavailable -> no trade
   if(clamp0)
      return false;          // numerical-safety: suppress signal on clamp-hit bar

   const double close0 = iClose(_Symbol, _Period, 0); // perf-allowed: single closed-bar read
   const double macro  = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   if(close0 <= 0.0 || macro <= 0.0)
      return false;

   // --- Zero-line cross = the single trigger EVENT ---
   const bool cross_up   = (f1 <= 0.0 && f0 > 0.0);
   const bool cross_down = (f1 >= 0.0 && f0 < 0.0);
   if(!cross_up && !cross_down)
      return false;

   // --- Prior dip/peak STATE: scan Fisher over [1 .. dip_lookback] ---
   const int dip_lb = (fisher_dip_lookback > 0 ? fisher_dip_lookback : 10);
   double fmin = DBL_MAX, fmax = -DBL_MAX;
   for(int s = 1; s <= dip_lb; ++s)
     {
      bool fk_ok=false, fk_clamp=false;
      const double fk = FisherAt(s, fk_ok, fk_clamp);
      if(!fk_ok)
         return false;
      if(fk < fmin) fmin = fk;
      if(fk > fmax) fmax = fk;
     }
   const bool prior_dip  = (fmin < -fisher_dip_threshold); // meaningful low before cross-up
   const bool prior_peak = (fmax >  fisher_dip_threshold); // meaningful high before cross-down

   // --- Macro bias STATE ---
   const bool macro_long  = (close0 > macro);
   const bool macro_short = (close0 < macro);

   QM_OrderType dir;
   double entry;

   if(cross_up && prior_dip && macro_long)
     {
      dir   = QM_BUY;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   else if(cross_down && prior_peak && macro_short)
     {
      dir   = QM_SELL;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     }
   else
      return false;

   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Hard SL: entry -/+ sl_atr_mult * ATR ---
   double sl;
   if(dir == QM_BUY)
      sl = entry - strategy_sl_atr_mult * atr_value;
   else
      sl = entry + strategy_sl_atr_mult * atr_value;
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   // --- Take profit: tp_atr_mult * ATR from entry, via RR off the stop so the
   //     framework's price normalization applies. ---
   const double sl_dist = MathAbs(entry - sl);
   if(sl_dist <= 0.0)
      return false;
   const double rr = (strategy_tp_atr_mult * atr_value) / sl_dist;
   if(rr <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "fisher_zerocross_prior_dip_macro";
   return true;
  }

// Primary exits are the broker-side hard stop and ATR target plus the closed-bar
// Fisher exits in Strategy_ExitSignal; no active trailing/BE per the card.
void Strategy_ManageOpenPosition()
  {
  }

// Closed-bar exits: Fisher extreme-zone OR Fisher zero-line cross-back against
// the position OR time-stop. Caller closes the magic's positions on true.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this magic's open position to read direction + open time.
   bool have_pos = false;
   long pos_type = -1;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type  = PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos  = true;
      break;
     }
   if(!have_pos)
      return false;

   // --- Time-stop: held >= N H1 bars ---
   if(strategy_time_stop_bars > 0 && open_time > 0)
     {
      const int held_bars = (int)((TimeCurrent() - open_time) / (PeriodSeconds(_Period)));
      if(held_bars >= strategy_time_stop_bars)
         return true;
     }

   bool f0_ok=false, f1_ok=false, clamp0=false, clamp1=false;
   const double f0 = FisherAt(0, f0_ok, clamp0);
   const double f1 = FisherAt(1, f1_ok, clamp1);
   if(!(f0_ok && f1_ok))
      return false;

   // --- Extreme-zone exit (primary) ---
   if(pos_type == POSITION_TYPE_BUY  && f0 >  fisher_extreme_z)
      return true;
   if(pos_type == POSITION_TYPE_SELL && f0 < -fisher_extreme_z)
      return true;

   // --- Zero-line cross-back exit (secondary) ---
   // BUY closes when Fisher crosses back below zero; SELL when back above.
   if(pos_type == POSITION_TYPE_BUY  && f1 >= 0.0 && f0 < 0.0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && f1 <= 0.0 && f0 > 0.0)
      return true;

   return false;
  }

// Defer to the central news filter (card: 30-min skip pre/post high-impact,
// satisfied by the framework's PRE30_POST30 temporal mode).
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
