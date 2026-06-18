#property strict
#property version   "5.0"
#property description "QM5_11255 ht-regime-rvarb — Bock/Mestel regime-switching relative-value pair (D1, two-leg basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11255 ht-regime-rvarb
// -----------------------------------------------------------------------------
// Source: Hudson & Thames, "Statistical Arbitrage Strategy Based on the Markov
// Regime-Switching Model" (source_id af021dd0-e07d-5f72-9933-de7a3533934e);
// primary paper Bock, M. & Mestel, R. (2009) "A regime-switching relative value
// arbitrage rule". Card: artifacts/cards_approved/QM5_11255_ht-regime-rvarb.md
// (g0 APPROVED).
//
// REGIME-SWITCHING RELATIVE-VALUE PAIRS TRADE (BASKET EA). On each completed D1
// bar the EA fits a static hedge ratio by rolling OLS of the host close on the
// partner close over a TRAINING window (`training_window_bars` D1 bars), forms
// the log-ratio spread, then classifies the spread distribution into TWO
// DETERMINISTIC regimes and applies the card's regime-specific standard-deviation
// + probability entry/exit rules. The spread is traded market-neutrally as a
// two-leg basket (host = leg1 via framework magic, partner = leg2 .DWX via
// QM_BasketOpenPosition). Both legs open/close together.
//
// DETERMINISTIC REGIME MODEL (NO ML / NO HMM-EM). The card cites a two-state
// Markov regime-switching model; an EM/Hamilton-filter fit is an iterative
// likelihood optimisation and is BANNED under HR14. We realise the SAME
// two-state structure with a fully deterministic, closed-form classifier on
// CLOSED bars only — no iteration, no likelihood maximisation, no PnL-adaptive
// parameters:
//
//   1. Over the training window, split the spread sample by its MEDIAN into a
//      HIGH-mean cluster (state 1: samples >= median) and a LOW-mean cluster
//      (state 2: samples < median). For each cluster compute the sample mean
//      (mu_1, mu_2) and std (sigma_1, sigma_2). This is a fixed deterministic
//      partition of a fixed window — it always yields the same numbers for the
//      same data. No EM, no soft-assignment iteration.
//   2. The CURRENT regime of the latest closed bar X_t is the deterministic
//      rule: state 1 if X_t >= grand_mean, else state 2 (grand_mean = midpoint
//      of mu_1, mu_2). This is the "current regime is state k" the card's rules
//      key off.
//   3. P(state k | X_t) is the closed-form Gaussian posterior with EQUAL priors:
//          p_k(x) = phi((x-mu_k)/sigma_k) / sigma_k
//          P(1|x) = p_1 / (p_1 + p_2),  P(2|x) = 1 - P(1|x)
//      This is a fixed algebraic evaluation (Bayes with fixed priors), not a
//      fitted/learned probability. It supplies the card's `P(state|X_t) >= rho`
//      gate.
//
// CARD ENTRY/EXIT (regime-specific, X_t = latest closed-bar spread):
//   LONG spread (BUY host / SELL partner):
//     state 1: X_t <= mu_1 - delta*sigma_1  AND  P(1|X_t) >= rho
//     state 2: X_t <= mu_2 - delta*sigma_2
//   SHORT spread (SELL host / BUY partner):
//     state 1: X_t >= mu_1 + delta*sigma_1
//     state 2: X_t >= mu_2 + delta*sigma_2  AND  P(2|X_t) >= rho
//   CLOSE long:
//     state 1: X_t >= mu_1 + delta*sigma_1
//     state 2: X_t >= mu_2 + delta*sigma_2  AND  P(2|X_t) >= rho
//   CLOSE short:
//     state 1: X_t <= mu_1 - delta*sigma_1  AND  P(1|X_t) >= rho
//     state 2: X_t <= mu_2 - delta*sigma_2
//   Time stop after `max_hold_bars` D1 bars (default 60).
//
// QUALIFICATION FILTERS (card, deterministic):
//   - require >= training_window_bars synced D1 bars on BOTH legs,
//   - require BOTH cluster sigmas > 0 (else degenerate),
//   - SKIP if the regime means are nearly equal:
//       |mu_1 - mu_2| < min_regime_mean_gap_sigma * pooled_sigma
//     (card's "nearly equal regime means" gate).
//   - half-life sanity (card filter: half-life in [3,80] bars) via a bounded
//     AR(1) fit on the spread; degenerate/non-reverting spreads do not trade.
//   Refit is implicit per closed bar from a fixed rolling window while flat
//   (flat-only: regime params are only ACTED on to open when no pair position
//   is held); we never mutate parameters from running PnL.
//
// BASKET WIRING. Host leg trades `_Symbol` via the framework magic
// (slot = qm_magic_slot_offset). Partner leg trades a FOREIGN .DWX symbol via
// QM_BasketOpenPosition at its registered symbol_slot. Both legs warmed in
// OnInit. One position per (magic, symbol). Pair (host = leg1, partner = leg2),
// registered in magic_numbers.csv:
//   slot 0 EURUSD.DWX (host A) / slot 1 GBPUSD.DWX (partner A)
//   slot 2 AUDUSD.DWX (host B) / slot 3 NZDUSD.DWX (partner B)
//   slot 4 XAUUSD.DWX (host C) / slot 5 EURUSD.DWX is NOT reusable as a slot;
//          card pair C is XAUUSD/EURUSD, so leg pairing is set per-setfile via
//          strategy_partner_symbol + strategy_partner_slot.
// All legs are REAL .DWX symbols present in dwx_symbol_matrix.csv — no port.
// No external feed, no ML. =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11255;
input int    qm_magic_slot_offset       = 0;     // HOST leg slot (= host symbol slot)
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
// Partner (leg2) symbol + its registered magic slot. Host leg = _Symbol at
// qm_magic_slot_offset. Defaults bind pair A: EURUSD.DWX host / GBPUSD.DWX.
input string strategy_partner_symbol      = "GBPUSD.DWX"; // foreign .DWX leg2
input int    strategy_partner_slot        = 1;            // partner registered slot
input int    strategy_training_window_bars = 504;  // regime/hedge training window (P3 {252,504,756})
input double strategy_delta_sigma         = 1.5;   // sigma-band multiplier (P3 {1.0,1.5,2.0})
input double strategy_regime_prob_threshold = 0.70; // rho: P(state|X_t) gate (P3 {0.60,0.70,0.80})
input int    strategy_max_hold_bars       = 60;    // time stop in D1 bars (P3 {30,60,90})
input double strategy_min_regime_mean_gap_sigma = 0.5; // skip if |mu1-mu2| < gap*pooled_sigma (P3 {0.25,0.5,0.75})
input int    strategy_min_half_life       = 3;     // card half-life filter lower bound (D1 bars)
input int    strategy_max_half_life       = 80;    // card half-life filter upper bound (D1 bars)
input int    strategy_min_d1_bars         = 560;   // need >= training + buffer synced D1 bars
input double strategy_leg_risk_split      = 0.5;   // documentary share of RISK_FIXED per leg

// -----------------------------------------------------------------------------
// File-scope cached pair/regime state, advanced once per closed D1 bar.
// -----------------------------------------------------------------------------
string   g_partner       = "";     // resolved partner symbol (leg2)
bool     g_ready         = false;  // both legs synced + regime model well-formed
bool     g_qualified     = false;  // regime separation + half-life qualification passed
double   g_x_curr        = 0.0;    // latest closed-bar spread X_t
int      g_regime        = 0;      // current deterministic regime: 1 (high) or 2 (low)
double   g_mu1           = 0.0;    // state 1 (high) mean
double   g_sig1          = 0.0;    // state 1 std
double   g_mu2           = 0.0;    // state 2 (low) mean
double   g_sig2          = 0.0;    // state 2 std
double   g_p1            = 0.0;    // P(state 1 | X_t)
double   g_p2            = 0.0;    // P(state 2 | X_t)

// Gaussian density (unnormalised by constant 1/sqrt(2pi) — cancels in posterior).
double QM_GaussDensity(const double x, const double mu, const double sigma)
  {
   if(sigma <= 1e-12)
      return 0.0;
   const double z = (x - mu) / sigma;
   return MathExp(-0.5 * z * z) / sigma;
  }

// Insertion sort of a copied array (formation window is bounded ~756, O(n^2) is
// fine here and runs once per closed D1 bar).
void QM_SortAsc(double &a[], const int n)
  {
   for(int i = 1; i < n; ++i)
     {
      const double key = a[i];
      int j = i - 1;
      while(j >= 0 && a[j] > key)
        {
         a[j + 1] = a[j];
         --j;
        }
      a[j + 1] = key;
     }
  }

// -----------------------------------------------------------------------------
// Deterministic regime model on CLOSED D1 bars. Fits an OLS log-ratio hedge over
// the training window, forms the spread, splits it by its median into two regimes,
// computes per-regime mean/std + grand mean, classifies the current bar, evaluates
// closed-form Gaussian posteriors, and runs the half-life sanity filter. Returns
// false on missing/degenerate data so the EA simply does not trade.
// -----------------------------------------------------------------------------
bool QM_ComputeRegimeModel(const int train,
                           double &x_last, int &regime,
                           double &mu1, double &sig1, double &mu2, double &sig2,
                           double &p1, double &p2, bool &qualified)
  {
   x_last    = 0.0;
   regime    = 0;
   mu1 = 0.0; sig1 = 0.0; mu2 = 0.0; sig2 = 0.0;
   p1 = 0.0; p2 = 0.0;
   qualified = false;
   if(train < 60)
      return false;

   if(Bars(_Symbol,  PERIOD_D1) < strategy_min_d1_bars) return false;   // perf-allowed: host bar-count availability check
   if(Bars(g_partner, PERIOD_D1) < strategy_min_d1_bars) return false;  // perf-allowed: partner bar-count availability check

   const int n = train;                 // bars 1..n, index 0 = shift 1 (last closed)
   double h[];   // host close,    index 0 = last closed (shift 1)
   double p[];   // partner close, index 0 = last closed (shift 1)
   ArrayResize(h, n);
   ArrayResize(p, n);
   for(int i = 0; i < n; ++i)
     {
      // perf-allowed: closed-bar host+partner closes for the training window;
      // computed once per closed D1 bar (OnTick gates this via QM_IsNewBar).
      const double ch = iClose(_Symbol,   PERIOD_D1, i + 1);   // perf-allowed: closed-bar host close, training window
      const double cp = iClose(g_partner, PERIOD_D1, i + 1);   // perf-allowed: closed-bar partner close, training window
      if(ch <= 0.0 || cp <= 0.0)
         return false;                  // missing bar inside lookback -> no trade
      h[i] = ch;
      p[i] = cp;
     }

   // Log-ratio normalisation relative to the OLDEST training bar (card baseline:
   // ln(S1/S1_0) - beta*ln(S2/S2_0)). index n-1 is the oldest closed bar.
   const double h0 = h[n - 1];
   const double p0 = p[n - 1];
   if(h0 <= 0.0 || p0 <= 0.0)
      return false;
   double lh[];   // ln(host/host_0)
   double lp[];   // ln(partner/partner_0)
   ArrayResize(lh, n);
   ArrayResize(lp, n);
   for(int i = 0; i < n; ++i)
     {
      lh[i] = MathLog(h[i] / h0);
      lp[i] = MathLog(p[i] / p0);
     }

   // OLS hedge ratio beta over the training window: lh = a + beta*lp.
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   const double dn = (double)n;
   for(int i = 0; i < n; ++i)
     {
      sx  += lp[i];
      sy  += lh[i];
      sxx += lp[i] * lp[i];
      sxy += lp[i] * lh[i];
     }
   const double den = dn * sxx - sx * sx;
   if(MathAbs(den) < 1e-15)
      return false;                     // degenerate regressor -> no trade
   const double beta      = (dn * sxy - sx * sy) / den;
   const double intercept = (sy - beta * sx) / dn;

   // Spread series: spread[i] = lh[i] - (a + beta*lp[i]). index 0 = newest.
   double spread[];
   ArrayResize(spread, n);
   for(int i = 0; i < n; ++i)
      spread[i] = lh[i] - (intercept + beta * lp[i]);

   x_last = spread[0];

   // --- Two-regime split by the MEDIAN of the training-window spread ---------
   double sorted[];
   ArrayResize(sorted, n);
   for(int i = 0; i < n; ++i)
      sorted[i] = spread[i];
   QM_SortAsc(sorted, n);
   const double median = (n % 2 == 1)
                         ? sorted[n / 2]
                         : 0.5 * (sorted[n / 2 - 1] + sorted[n / 2]);

   // State 1 = HIGH cluster (spread >= median); state 2 = LOW cluster.
   double s1 = 0.0, s2 = 0.0;     // sums
   double q1 = 0.0, q2 = 0.0;     // sums of squares
   int    c1 = 0,   c2 = 0;       // counts
   for(int i = 0; i < n; ++i)
     {
      const double v = spread[i];
      if(v >= median) { s1 += v; q1 += v * v; ++c1; }
      else            { s2 += v; q2 += v * v; ++c2; }
     }
   if(c1 < 2 || c2 < 2)
      return false;                     // degenerate split -> no trade
   mu1 = s1 / (double)c1;
   mu2 = s2 / (double)c2;
   const double var1 = q1 / (double)c1 - mu1 * mu1;
   const double var2 = q2 / (double)c2 - mu2 * mu2;
   if(var1 <= 1e-15 || var2 <= 1e-15)
      return false;                     // zero in-cluster variance -> no trade
   sig1 = MathSqrt(var1);
   sig2 = MathSqrt(var2);

   // Pooled sigma + mean-separation qualification (card "nearly equal means" skip).
   const double pooled_sigma = MathSqrt(0.5 * (var1 + var2));
   if(pooled_sigma <= 1e-15)
      return false;
   const bool means_separated =
      (MathAbs(mu1 - mu2) >= strategy_min_regime_mean_gap_sigma * pooled_sigma);

   // Current regime: state 1 if X_t >= grand mean (midpoint of the two means).
   const double grand_mean = 0.5 * (mu1 + mu2);
   regime = (x_last >= grand_mean) ? 1 : 2;

   // Closed-form Gaussian posterior with equal priors.
   const double d1 = QM_GaussDensity(x_last, mu1, sig1);
   const double d2 = QM_GaussDensity(x_last, mu2, sig2);
   const double dsum = d1 + d2;
   if(dsum <= 1e-300)
     { p1 = 0.5; p2 = 0.5; }
   else
     { p1 = d1 / dsum; p2 = d2 / dsum; }

   // --- Half-life sanity filter (card: half-life in [min,max] D1 bars) -------
   // Bounded AR(1) of the spread: dS_t = lambda*S_{t-1} + c. lambda<0 = reverting,
   // half_life = -ln(2)/lambda. spread index 0 is newest, so S_{t-1}=spread[i+1].
   double ax = 0.0, ay = 0.0, axx = 0.0, axy = 0.0;
   const int m = n - 1;
   for(int i = 0; i < m; ++i)
     {
      const double s_prev = spread[i + 1];
      const double ds     = spread[i] - spread[i + 1];
      ax  += s_prev;
      ay  += ds;
      axx += s_prev * s_prev;
      axy += s_prev * ds;
     }
   const double dm   = (double)m;
   const double aden = dm * axx - ax * ax;
   bool hl_ok = false;
   if(MathAbs(aden) >= 1e-18)
     {
      const double lambda = (dm * axy - ax * ay) / aden;
      if(lambda < 0.0)
        {
         const double half_life = -MathLog(2.0) / lambda;
         if(half_life >= (double)strategy_min_half_life &&
            half_life <= (double)strategy_max_half_life)
            hl_ok = true;
        }
     }

   qualified = (means_separated && hl_ok);
   return true;
  }

// Advance cached regime state once per closed D1 bar.
void QM_AdvanceRegimeState()
  {
   double xl, m1, s1v, m2, s2v, pp1, pp2;
   int    reg;
   bool   qual;
   if(QM_ComputeRegimeModel(strategy_training_window_bars,
                            xl, reg, m1, s1v, m2, s2v, pp1, pp2, qual))
     {
      g_x_curr    = xl;
      g_regime    = reg;
      g_mu1       = m1;  g_sig1 = s1v;
      g_mu2       = m2;  g_sig2 = s2v;
      g_p1        = pp1; g_p2 = pp2;
      g_qualified = qual;
      g_ready     = true;
     }
   else
     {
      g_ready     = false;
      g_qualified = false;
     }
  }

// Count open positions for an arbitrary (slot,symbol) leg of THIS ea_id.
int QM_LegOpenCount(const int slot, const string sym)
  {
   const int magic = QM_Magic(qm_ea_id, slot);
   if(magic <= 0)
      return 0;
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      ++c;
     }
   return c;
  }

// True if EITHER leg of the pair currently holds a position.
bool QM_PairHasPosition()
  {
   if(QM_LegOpenCount(qm_magic_slot_offset, _Symbol) > 0)
      return true;
   if(QM_LegOpenCount(strategy_partner_slot, g_partner) > 0)
      return true;
   return false;
  }

// Direction of the open HOST leg: +1 host long (long-spread), -1 host short
// (short-spread), 0 none.
int QM_HostLegDir()
  {
   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   if(magic <= 0)
      return 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? +1 : -1;
     }
   return 0;
  }

// Bars held by the host leg (D1), or -1 if no host position.
int QM_HostLegBarsHeld()
  {
   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   if(magic <= 0)
      return -1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      // perf-allowed: single bar-open time read for the time-stop bar count.
      const datetime cur_bar = iTime(_Symbol, PERIOD_D1, 0);   // perf-allowed: bar-open time for time-stop count
      if(open_time <= 0 || cur_bar <= 0)
         return 0;
      return Bars(_Symbol, PERIOD_D1, open_time, cur_bar) - 1;  // perf-allowed: bars-held count for time stop
     }
   return -1;
  }

// Open the partner (leg2) market order on the FOREIGN symbol via the basket path.
bool QM_OpenPartnerLeg(const QM_OrderType ot, const string reason)
  {
   QM_BasketOrderRequest br;
   br.symbol             = g_partner;
   br.type               = ot;
   br.price              = 0.0;     // basket path fills market price at send
   br.sl                 = 0.0;     // pair-level exits manage the position
   br.tp                 = 0.0;
   br.lots               = 0.0;     // 0 -> basket sizes via QM_LotsForRisk(partner, sl_pts)
   br.reason             = reason;
   br.symbol_slot        = strategy_partner_slot;
   br.expiration_seconds = 0;

   ulong tk = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, br, tk);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick filter. Fail-OPEN spread guard on the host leg only; the
// pair logic runs on closed bars. No session restriction (D1 pairs).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                     // no valid quote — defer, never block
   const double atr = QM_ATR(_Symbol, PERIOD_D1, 14, 1);
   if(atr <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread > 0.0 && spread > 0.50 * atr)   // >50% of D1 ATR = pathological
      return true;
   return false;
  }

// Entry on a freshly closed D1 bar. Host leg via the framework path; the partner
// leg opened first via the basket path so both legs go on together. Caller
// guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Flat-only: skip if either leg already open (no pyramiding / averaging).
   if(QM_PairHasPosition())
      return false;
   if(!g_ready || !g_qualified)
      return false;

   const double x   = g_x_curr;
   const double rho = strategy_regime_prob_threshold;
   const double dl  = strategy_delta_sigma;

   int dir = 0;                          // +1 long-spread, -1 short-spread
   if(g_regime == 1)
     {
      // LONG  state 1: x <= mu1 - delta*sig1 AND P(1|x) >= rho
      if(x <= (g_mu1 - dl * g_sig1) && g_p1 >= rho)
         dir = +1;
      // SHORT state 1: x >= mu1 + delta*sig1
      else if(x >= (g_mu1 + dl * g_sig1))
         dir = -1;
     }
   else if(g_regime == 2)
     {
      // LONG  state 2: x <= mu2 - delta*sig2
      if(x <= (g_mu2 - dl * g_sig2))
         dir = +1;
      // SHORT state 2: x >= mu2 + delta*sig2 AND P(2|x) >= rho
      else if(x >= (g_mu2 + dl * g_sig2) && g_p2 >= rho)
         dir = -1;
     }
   if(dir == 0)
      return false;

   const QM_OrderType host_ot    = (dir > 0) ? QM_BUY : QM_SELL;
   const QM_OrderType partner_ot = (dir > 0) ? QM_SELL : QM_BUY;

   // Open partner FIRST. If it fails, abort so we never carry a naked leg.
   const string rsn = (dir > 0) ? "regime_long_spread" : "regime_short_spread";
   if(!QM_OpenPartnerLeg(partner_ot, rsn))
      return false;

   req.type        = host_ot;
   req.price       = 0.0;                // framework fills market price at send
   req.sl          = 0.0;
   req.tp          = 0.0;
   req.reason      = rsn;
   req.symbol_slot = qm_magic_slot_offset;  // host leg slot
   return true;
  }

// No active per-position trade management; pair exits are rule-based.
void Strategy_ManageOpenPosition()
  {
  }

// Pair-level exits: regime-specific close rules + time stop. Returning true
// triggers the framework's host-leg close loop in OnTick; we ALSO close the
// partner leg here so the whole pair unwinds together.
bool Strategy_ExitSignal()
  {
   const int host_dir = QM_HostLegDir();   // +1 long-spread, -1 short-spread, 0 none
   if(host_dir == 0)
      return false;

   bool do_exit = false;
   QM_ExitReason reason = QM_EXIT_STRATEGY;

   if(g_ready)
     {
      const double x   = g_x_curr;
      const double rho = strategy_regime_prob_threshold;
      const double dl  = strategy_delta_sigma;

      if(host_dir > 0)   // open LONG spread -> close-long rules
        {
         if(g_regime == 1)
           {
            // Close long state 1: x >= mu1 + delta*sig1
            if(x >= (g_mu1 + dl * g_sig1))
               do_exit = true;
           }
         else // regime 2
           {
            // Close long state 2: x >= mu2 + delta*sig2 AND P(2|x) >= rho
            if(x >= (g_mu2 + dl * g_sig2) && g_p2 >= rho)
               do_exit = true;
           }
        }
      else               // open SHORT spread -> close-short rules
        {
         if(g_regime == 1)
           {
            // Close short state 1: x <= mu1 - delta*sig1 AND P(1|x) >= rho
            if(x <= (g_mu1 - dl * g_sig1) && g_p1 >= rho)
               do_exit = true;
           }
         else // regime 2
           {
            // Close short state 2: x <= mu2 - delta*sig2
            if(x <= (g_mu2 - dl * g_sig2))
               do_exit = true;
           }
        }
     }

   // Time stop: close the pair after max_hold_bars D1 bars.
   if(!do_exit)
     {
      const int budget = (strategy_max_hold_bars > 0) ? strategy_max_hold_bars : 60;
      const int held = QM_HostLegBarsHeld();
      if(held >= 0 && held >= budget)
        { do_exit = true; reason = QM_EXIT_TIME_STOP; }
     }

   if(do_exit)
     {
      // Close the PARTNER leg here; the OnTick close loop closes the host leg.
      const int partner_magic = QM_Magic(qm_ea_id, strategy_partner_slot);
      if(partner_magic > 0)
        {
         for(int i = PositionsTotal() - 1; i >= 0; --i)
           {
            const ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket))
               continue;
            if(PositionGetInteger(POSITION_MAGIC) != partner_magic)
               continue;
            QM_TM_ClosePosition(ticket, reason);
           }
        }
      return true;
     }
   return false;
  }

// Defer to the central two-axis news filter.
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

   // Resolve the partner leg. If blank or equal to the host, the pair is
   // degenerate and the EA simply never trades (still a valid, safe init).
   g_partner = strategy_partner_symbol;
   if(StringLen(g_partner) == 0)
      g_partner = _Symbol;

   // BASKET wiring: register host + partner and warm their D1 history so the
   // foreign-symbol close reads return real data in the .DWX tester.
   string universe[];
   if(g_partner == _Symbol)
     {
      ArrayResize(universe, 1);
      universe[0] = _Symbol;
     }
   else
     {
      ArrayResize(universe, 2);
      universe[0] = _Symbol;
      universe[1] = g_partner;
     }
   QM_SymbolGuardInit(universe);
   QM_BasketWarmupHistory(universe, PERIOD_D1, strategy_training_window_bars + 60);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"host\":\"%s\",\"partner\":\"%s\",\"host_slot\":%d,\"partner_slot\":%d,\"train\":%d,\"delta\":%.2f,\"rho\":%.2f}",
                            _Symbol, g_partner, qm_magic_slot_offset,
                            strategy_partner_slot, strategy_training_window_bars,
                            strategy_delta_sigma, strategy_regime_prob_threshold));
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

   // Latch the closed-bar event ONCE (single-consume) and reuse it. On a fresh D1
   // bar refresh the regime/spread state BEFORE the rule-based exit so the exit
   // sees the current regime + X_t.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvanceRegimeState();

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

   if(!nb)
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
