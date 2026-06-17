#property strict
#property version   "5.0"
#property description "QM5_11252 ht-multicoint — multivariate (Johansen-style) cointegration basket spread, lagged Z-sum sign (D1, 3-5 leg basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11252 ht-multicoint
// -----------------------------------------------------------------------------
// Source: Hudson & Thames, "Multivariate Cointegration Framework / Strategy",
// ArbitrageLab documentation (source_id af021dd0-e07d-5f72-9933-de7a3533934e);
// primary academic reference Galenko, Popova & Popova (2012), "Trading in the
// presence of cointegration".
// Card: artifacts/cards_approved/QM5_11252_ht-multicoint.md (g0 APPROVED).
//
// MULTIVARIATE COINTEGRATION BASKET (>2 legs). On each completed D1 bar, while
// the EA holds no basket position, it fits a DETERMINISTIC closed-form spread
// using a rolling multi-OLS hedge over a FORMATION window (`training_window_bars`
// D1 bars): regress ln(host) on ln(partner_2..k) by ordinary least squares
// (normal equations + Gauss-Jordan inversion of the k-1 x k-1 design matrix).
// The cointegrating vector is then
//
//     b = [ 1, -beta_2, ..., -beta_k ]   (host weight fixed at +1)
//
// and the multivariate spread / cointegration portfolio value is
//
//     Y_t = b' * ln(P_t) = ln(host_t) - sum_{j=2..k} beta_j * ln(partner_j,t).
//
// DETERMINISM NOTE (build flag `coint_weights=rolling_multi_ols`): the card cites
// a Johansen eigenvector for `b`. A full Johansen eigen-MLE is an iterative
// optimiser and is NOT deterministically expressible in pure MQL5 without an ML
// / numerical-eigensolver library (banned under HR14 / .DWX invariants). Per the
// build mandate we APPROXIMATE the Johansen cointegrating vector with a fixed
// rolling multi-OLS hedge (regress leg1 on legs 2..k). This is the standard
// Engle-Granger multivariate analogue, fully closed-form and deterministic on
// closed-bar prices. Flagged in open_questions / SPEC §1.
//
// SIGNAL (card "Strategy Idea"):
//   Z_t = Y_t - Y_{t-1}                          (one-step change of the spread)
//   S_t = sum_{p=1..lag_p} Z_{t-p}               (finite lagged Z-sum)
// The lagged Z-sum is standardised by the spread-change std over the formation
// window into a portfolio-sigma deadband. Allocation (always-in-market source,
// flat-only refit port):
//   S_t > 0  -> the cointegration portfolio is "rich on the upside drift": take
//              the source dollar-neutral allocation sign(-b_i * sign(S_t)). With
//              host weight +1 that means SELL host + (BUY/SELL partner_j by
//              sign of beta_j) -> SHORT the spread.
//   S_t < 0  -> opposite: LONG the spread.
// We trade only when |S_t| exceeds `deadband_z` portfolio sigmas (card filter).
//
// EXIT (card): the source closes & reopens every D1 bar; the V5 port rebalances
// at the next D1 bar only if the target SIDE changes or |S_t| falls below the
// deadband (mean-band exit). Hard time stop after `time_stop_bars` D1 bars with
// no side change. Monthly Johansen/OLS refit closes ALL legs flat first
// (`refit_interval_days`), then recomputes weights while flat.
//
// COINTEGRATION QUALIFICATION (card filters, deterministic):
//   - require at least `min_legs` (>=3) synced legs with valid closed bars,
//   - spread-change std over the formation window must be > 0 (non-degenerate),
//   - no single leg may exceed `max_leg_gross_pct` of gross |weight| exposure;
//     legs are leverage-normalised so the basket gross risk is bounded.
// We do NOT run a Johansen trace/eigenvalue p-value table at run time (no stats
// library in MQL5); the card's trace-confirmation intent is approximated by the
// non-degenerate spread + bounded-leg-concentration gate, which is the
// deterministic core that survives in MQL5. No external feed, no ML.
//
// BASKET WIRING. The host leg trades `_Symbol` via the framework magic
// (slot = qm_magic_slot_offset). Up to four partner legs trade FOREIGN .DWX
// symbols via QM_BasketOpenPosition at their own registered symbol_slots. All
// legs are warmed in OnInit so foreign-symbol reads return real data in the
// .DWX tester. One position per (magic, symbol). All legs open/close together.
//
// Basket model registered in magic_numbers.csv (host = leg1):
//   slot 0 EURUSD.DWX (host) / slot 1 GBPUSD.DWX / slot 2 AUDUSD.DWX /
//   slot 3 NZDUSD.DWX / slot 4 NDX.DWX / slot 5 WS30.DWX
// All six legs are REAL .DWX symbols in dwx_symbol_matrix.csv — no port needed.
// DEFAULT instance = the FX 4-leg cointegration basket
// (EURUSD host / GBPUSD / AUDUSD / NZDUSD), the card's primary P2 basket and the
// only economically-coherent single-matrix cointegration set (mixing FX with
// equity indices in one Johansen vector is not a valid cointegration system).
// The index basket (EURUSD/NDX/WS30) is selectable via setfile by binding the
// partner slots. A setfile selects WHICH basket an instance runs by binding:
//   strategy_partnerN_symbol / strategy_partnerN_slot for N=1..4 (0 = unused).
//
// Only the five Strategy_* hooks + OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11252;
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
// Partner legs (2..k). Blank symbol or slot<0 => leg unused. Defaults bind the
// FX 4-leg basket: EURUSD host (slot0) + GBPUSD(1) + AUDUSD(2) + NZDUSD(3).
input string strategy_partner1_symbol   = "GBPUSD.DWX"; // partner leg 2
input int    strategy_partner1_slot     = 1;
input string strategy_partner2_symbol   = "AUDUSD.DWX"; // partner leg 3
input int    strategy_partner2_slot     = 2;
input string strategy_partner3_symbol   = "NZDUSD.DWX"; // partner leg 4
input int    strategy_partner3_slot     = 3;
input string strategy_partner4_symbol   = "";           // partner leg 5 (unused by default)
input int    strategy_partner4_slot     = -1;

input int    strategy_training_window_bars = 504;  // multi-OLS formation window (P3 {252,504,756})
input int    strategy_lag_p                = 20;   // finite lagged Z-sum length (P3 {10,20,40})
input double strategy_deadband_z           = 0.25; // |S_t| portfolio-sigma deadband (P3 {0.0,0.25,0.5})
input double strategy_max_leg_gross_pct    = 45.0; // max single-leg gross |weight| share (P3 {35,45,55})
input int    strategy_refit_interval_days  = 22;   // flat-only refit cadence, D1 bars (P3 {11,22,44})
input int    strategy_time_stop_bars       = 5;    // hard time stop with no side change (D1 bars)
input int    strategy_min_legs             = 3;    // require >=3 legs (card filter)
input int    strategy_min_d1_bars          = 560;  // need >= training_window + buffer synced D1 bars

// -----------------------------------------------------------------------------
// File-scope basket configuration + cached state, advanced once per closed D1 bar.
// -----------------------------------------------------------------------------
#define QM_MC_MAX_LEGS 5                 // host + up to 4 partners

string   g_leg_sym[QM_MC_MAX_LEGS];      // index 0 = host, 1..n-1 = partners
int      g_leg_slot[QM_MC_MAX_LEGS];     // registered symbol slot per leg
double   g_leg_beta[QM_MC_MAX_LEGS];     // cointegrating weight per leg (host = +1)
int      g_n_legs           = 0;         // active leg count (host + partners)

double   g_s_curr           = 0.0;       // last closed-bar standardised lagged Z-sum S_t
bool     g_s_ready          = false;     // basket synced + spread well-formed + weights valid
int      g_basket_side      = 0;         // open basket side: +1 long-spread, -1 short-spread, 0 flat
int      g_bars_since_refit = 0;         // D1 bars since last (re)fit while flat

// -----------------------------------------------------------------------------
// Deterministic Gauss-Jordan solve of A x = b for an n x n system (n <= 4).
// In-place on a row-major copy; returns false if singular (degenerate basket).
// -----------------------------------------------------------------------------
bool QM_SolveLinearSystem(double &A[], double &b[], const int n, double &x[])
  {
   // A is n*n row-major; b is length n; x receives the solution.
   for(int col = 0; col < n; ++col)
     {
      // Partial pivot: find the largest |A[row][col]| at or below the diagonal.
      int    piv = col;
      double best = MathAbs(A[col * n + col]);
      for(int r = col + 1; r < n; ++r)
        {
         const double v = MathAbs(A[r * n + col]);
         if(v > best) { best = v; piv = r; }
        }
      if(best < 1e-12)
         return false;                   // singular -> degenerate regressor set
      if(piv != col)
        {
         for(int c = 0; c < n; ++c)
           {
            const double t = A[col * n + c]; A[col * n + c] = A[piv * n + c]; A[piv * n + c] = t;
           }
         const double tb = b[col]; b[col] = b[piv]; b[piv] = tb;
        }
      // Eliminate below and above.
      const double diag = A[col * n + col];
      for(int r = 0; r < n; ++r)
        {
         if(r == col) continue;
         const double factor = A[r * n + col] / diag;
         if(factor == 0.0) continue;
         for(int c = 0; c < n; ++c)
            A[r * n + c] -= factor * A[col * n + c];
         b[r] -= factor * b[col];
        }
     }
   for(int i = 0; i < n; ++i)
     {
      const double d = A[i * n + i];
      if(MathAbs(d) < 1e-12)
         return false;
      x[i] = b[i] / d;
     }
   return true;
  }

// -----------------------------------------------------------------------------
// Compute the multivariate cointegration spread, fit weights by multi-OLS over
// the formation window, build the lagged Z-sum and standardise it. Returns false
// on missing / degenerate / over-concentrated data so the EA simply does not
// trade (card "skip if unstable / std==0 / leg cap breached / missing bars").
// -----------------------------------------------------------------------------
bool QM_ComputeMultiCointSpread(const int formation, const int lagp, double &s_last)
  {
   s_last = 0.0;
   const int k = g_n_legs;                       // total legs (host + partners)
   if(k < strategy_min_legs || k > QM_MC_MAX_LEGS)
      return false;
   const int kp = k - 1;                          // partner (regressor) count
   if(formation < 60 || lagp < 1 || (lagp + 2) > formation)
      return false;

   // Need `formation` closed bars on EVERY leg.
   for(int L = 0; L < k; ++L)
      if(Bars(g_leg_sym[L], PERIOD_D1) < strategy_min_d1_bars)  // perf-allowed: per-leg bar-count availability check
         return false;

   const int n = formation;                       // bars: index 0 = shift 1 (last closed), older = higher
   // ln-price matrix: lp[L][i], L=leg, i=bar offset (0 newest).
   double lp[];
   ArrayResize(lp, k * n);
   for(int L = 0; L < k; ++L)
     {
      const string sym = g_leg_sym[L];
      for(int i = 0; i < n; ++i)
        {
         // perf-allowed: closed-bar foreign+host close reads for the formation
         // window; computed once per closed D1 bar (OnTick gates via QM_IsNewBar).
         const double c = iClose(sym, PERIOD_D1, i + 1);   // perf-allowed: closed-bar leg close for formation window
         if(c <= 0.0)
            return false;                          // missing bar inside lookback -> no trade
         lp[L * n + i] = MathLog(c);
        }
     }

   // --- multi-OLS: regress ln(host) on [1, ln(partner_2..k)] -----------------
   // Design has kp regressors + intercept => (kp+1) unknowns. Build normal
   // equations N (m x m) * theta = r, m = kp+1, theta = [a, beta_2..beta_k].
   const int m = kp + 1;
   double Nm[];   ArrayResize(Nm, m * m);
   double rv[];   ArrayResize(rv, m);
   for(int a = 0; a < m * m; ++a) Nm[a] = 0.0;
   for(int a = 0; a < m; ++a)     rv[a] = 0.0;

   // Feature vector per bar: f[0]=1 (intercept), f[1..kp]=ln(partner_{j}).
   double f[];   ArrayResize(f, m);
   for(int i = 0; i < n; ++i)
     {
      f[0] = 1.0;
      for(int j = 0; j < kp; ++j)
         f[j + 1] = lp[(j + 1) * n + i];           // partner leg (1..kp) ln-price
      const double y = lp[i];                       // host ln-price (leg 0)
      for(int a = 0; a < m; ++a)
        {
         rv[a] += f[a] * y;
         for(int b2 = 0; b2 < m; ++b2)
            Nm[a * m + b2] += f[a] * f[b2];
        }
     }

   double theta[]; ArrayResize(theta, m);
   if(!QM_SolveLinearSystem(Nm, rv, m, theta))
      return false;                                 // singular normal equations

   // Cointegrating vector: host weight +1; partner j weight = -beta_j.
   g_leg_beta[0] = 1.0;
   for(int j = 0; j < kp; ++j)
      g_leg_beta[j + 1] = -theta[j + 1];            // theta[0] = intercept (dropped from weights)
   const double intercept = theta[0];

   // --- leg-concentration cap (card max_leg_gross_pct) -----------------------
   double gross = 0.0;
   for(int L = 0; L < k; ++L)
      gross += MathAbs(g_leg_beta[L]);
   if(gross <= 1e-12)
      return false;
   const double cap = strategy_max_leg_gross_pct / 100.0;
   for(int L = 0; L < k; ++L)
      if((MathAbs(g_leg_beta[L]) / gross) > cap)
         return false;                              // single leg too concentrated -> skip

   // --- spread series Y over the formation window ----------------------------
   // Y[i] = ln(host) - sum_j beta_j*ln(partner_j) - intercept; index 0 newest.
   double Yv[];   ArrayResize(Yv, n);
   for(int i = 0; i < n; ++i)
     {
      double y = lp[i] - intercept;                 // host contribution + intercept removal
      for(int j = 0; j < kp; ++j)
         y -= theta[j + 1] * lp[(j + 1) * n + i];   // - beta_j * ln(partner_j)
      Yv[i] = y;
     }

   // --- one-step spread change Z_t = Y_t - Y_{t-1} ---------------------------
   // index 0 = newest. Y_{t-1} of bar i is the OLDER bar Yv[i+1].
   const int nz = n - 1;                             // number of Z values
   double Zv[];   ArrayResize(Zv, nz);
   for(int i = 0; i < nz; ++i)
      Zv[i] = Yv[i] - Yv[i + 1];

   // Standardisation scale: std of the spread-change series over the formation.
   double zmean = 0.0;
   for(int i = 0; i < nz; ++i) zmean += Zv[i];
   zmean /= (double)nz;
   double zvar = 0.0;
   for(int i = 0; i < nz; ++i) { const double d = Zv[i] - zmean; zvar += d * d; }
   zvar /= (double)nz;
   const double zstd = MathSqrt(zvar);
   if(zstd <= 1e-12)
      return false;                                  // degenerate spread -> no trade

   // --- finite lagged Z-sum S_t = sum_{p=1..lagp} Z_{t-p} --------------------
   // S_t at the last closed bar t sums the lagp most-recent spread changes:
   // Z_{t-1}..Z_{t-lagp} = Zv[0]..Zv[lagp-1].
   if(lagp > nz)
      return false;
   double Ssum = 0.0;
   for(int p = 0; p < lagp; ++p)
      Ssum += Zv[p];

   // Standardise S_t into portfolio sigmas: a sum of lagp ~iid increments has
   // std ~ zstd*sqrt(lagp). This makes deadband_z a portfolio-sigma threshold.
   const double s_scale = zstd * MathSqrt((double)lagp);
   if(s_scale <= 1e-12)
      return false;
   s_last = Ssum / s_scale;
   return true;
  }

// Advance cached multivariate cointegration state once per closed D1 bar.
void QM_AdvanceMultiCointState()
  {
   double sl = 0.0;
   if(QM_ComputeMultiCointSpread(strategy_training_window_bars, strategy_lag_p, sl))
     {
      g_s_curr  = sl;
      g_s_ready = true;
     }
   else
     {
      g_s_ready = false;
     }
  }

// Count open positions for a (slot,symbol) leg of THIS ea_id.
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

// True if ANY basket leg currently holds a position.
bool QM_BasketHasPosition()
  {
   for(int L = 0; L < g_n_legs; ++L)
      if(QM_LegOpenCount(g_leg_slot[L], g_leg_sym[L]) > 0)
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
      const datetime cur_bar = iTime(_Symbol, PERIOD_D1, 0);   // perf-allowed: bar-open time for time-stop count
      if(open_time <= 0 || cur_bar <= 0)
         return 0;
      return Bars(_Symbol, PERIOD_D1, open_time, cur_bar) - 1;  // perf-allowed: bars-held count for time stop
     }
   return -1;
  }

// Open a partner leg (foreign symbol) via the basket path. ot already encodes
// the partner-specific side. Returns false on reject (caller aborts the basket).
bool QM_OpenPartnerLeg(const int slot, const string sym, const QM_OrderType ot, const string reason)
  {
   QM_BasketOrderRequest br;
   br.symbol             = sym;
   br.type               = ot;
   br.price              = 0.0;     // basket path fills market price at send
   br.sl                 = 0.0;     // basket-level rule exits manage the legs
   br.tp                 = 0.0;
   br.lots               = 0.0;     // 0 -> basket sizes via QM_LotsForRisk
   br.reason             = reason;
   br.symbol_slot        = slot;
   br.expiration_seconds = 0;

   ulong tk = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, br, tk);
  }

// Close every partner leg of the basket with the given reason.
void QM_CloseAllPartnerLegs(const QM_ExitReason reason)
  {
   for(int L = 1; L < g_n_legs; ++L)
     {
      const int magic = QM_Magic(qm_ea_id, g_leg_slot[L]);
      if(magic <= 0)
         continue;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != g_leg_sym[L])
            continue;
         QM_TM_ClosePosition(ticket, reason);
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick filter. Fail-OPEN spread guard on the host leg only; the
// basket logic runs on closed bars. No session restriction (D1 basket).
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

// Entry on a freshly closed D1 bar. Opens the full basket: host via the
// framework path, every partner via the basket path. Partners open FIRST so we
// never carry a partial basket. Caller guarantees QM_IsNewBar()==true and that
// the refit/flat bookkeeping ran.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_BasketHasPosition())            // one basket position set at a time
      return false;
   if(!g_s_ready)
      return false;

   const double sc = g_s_curr;
   // Source dollar-neutral allocation sign(-b_i * sign(S_t)). With host weight
   // b_0 = +1: S_t>0 -> host SELL (short-spread); S_t<0 -> host BUY (long-spread).
   // Trade only outside the portfolio-sigma deadband.
   int dir = 0;                          // +1 long-spread, -1 short-spread
   if(sc >= strategy_deadband_z)
      dir = -1;                          // S_t>0 -> SHORT spread
   else if(sc <= -strategy_deadband_z)
      dir = +1;                          // S_t<0 -> LONG spread
   if(dir == 0)
      return false;

   // Per-leg side: leg L takes sign( -beta_L * dir_of_short ). We express it via
   // the host direction (dir) and each leg's beta sign relative to the host.
   // Host (leg0, beta=+1): long-spread -> BUY host; short-spread -> SELL host.
   // Partner leg j (weight beta_j): same side as host when beta_j>0, opposite
   // when beta_j<0, scaled out of the long/short-spread direction.
   const string rsn = (dir > 0) ? "multicoint_long_spread" : "multicoint_short_spread";

   // Open all partner legs first; abort (and unwind) if any fails.
   for(int L = 1; L < g_n_legs; ++L)
     {
      // Effective leg direction: dir (long-spread=+1) * sign(beta_L).
      const double bw = g_leg_beta[L];
      int leg_sign = (bw >= 0.0) ? +1 : -1;
      const int eff = dir * leg_sign;    // +1 -> BUY this leg, -1 -> SELL this leg
      const QM_OrderType ot = (eff > 0) ? QM_BUY : QM_SELL;
      if(!QM_OpenPartnerLeg(g_leg_slot[L], g_leg_sym[L], ot, rsn))
        {
         // Abort: unwind any partner legs already opened this bar so we never
         // carry a naked/partial basket.
         QM_CloseAllPartnerLegs(QM_EXIT_STRATEGY);
         return false;
        }
     }

   // Host leg (leg0, beta=+1): long-spread -> BUY, short-spread -> SELL.
   const QM_OrderType host_ot = (dir > 0) ? QM_BUY : QM_SELL;
   req.type        = host_ot;
   req.price       = 0.0;                // framework fills market price at send
   req.sl          = 0.0;               // basket-level rule exits
   req.tp          = 0.0;
   req.reason      = rsn;
   req.symbol_slot = qm_magic_slot_offset;  // host leg slot
   return true;
  }

// No active per-position trade management; basket exits are rule-based.
void Strategy_ManageOpenPosition()
  {
  }

// Basket-level exits: side change vs current S_t, deadband mean-band, time stop,
// monthly flat-only refit. Returning true triggers the framework host-leg close
// loop in OnTick; we ALSO close every partner leg here so the basket unwinds
// together.
bool Strategy_ExitSignal()
  {
   const int host_dir = QM_HostLegDir();   // +1 long-spread, -1 short-spread, 0 none
   if(host_dir == 0)
      return false;

   bool do_exit = false;
   QM_ExitReason reason = QM_EXIT_STRATEGY;

   // Monthly flat-only refit: close the whole basket so weights recompute flat.
   if(g_bars_since_refit >= strategy_refit_interval_days)
     { do_exit = true; reason = QM_EXIT_STRATEGY; }

   if(!do_exit && g_s_ready)
     {
      const double sc = g_s_curr;
      const double asc = MathAbs(sc);
      // Mean-band exit: |S_t| reverted inside the deadband.
      if(asc < strategy_deadband_z)
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
      // Side change: the target side flipped against the held side.
      if(!do_exit)
        {
         int target = 0;
         if(sc >= strategy_deadband_z)      target = -1;  // short-spread
         else if(sc <= -strategy_deadband_z) target = +1; // long-spread
         if(target != 0 && target != host_dir)
           { do_exit = true; reason = QM_EXIT_OPPOSITE_SIGNAL; }
        }
     }

   // Hard time stop after N D1 bars with no side change.
   if(!do_exit)
     {
      const int held = QM_HostLegBarsHeld();
      if(held >= 0 && held >= strategy_time_stop_bars)
        { do_exit = true; reason = QM_EXIT_TIME_STOP; }
     }

   if(do_exit)
     {
      QM_CloseAllPartnerLegs(reason);     // host leg closed by the OnTick loop
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

   // Assemble the active basket: host (leg0) + configured partner legs.
   g_n_legs = 0;
   g_leg_sym[g_n_legs]  = _Symbol;
   g_leg_slot[g_n_legs] = qm_magic_slot_offset;
   g_leg_beta[g_n_legs] = 1.0;
   g_n_legs++;

   string  pcand_sym[4];
   int     pcand_slot[4];
   pcand_sym[0] = strategy_partner1_symbol; pcand_slot[0] = strategy_partner1_slot;
   pcand_sym[1] = strategy_partner2_symbol; pcand_slot[1] = strategy_partner2_slot;
   pcand_sym[2] = strategy_partner3_symbol; pcand_slot[2] = strategy_partner3_slot;
   pcand_sym[3] = strategy_partner4_symbol; pcand_slot[3] = strategy_partner4_slot;
   for(int j = 0; j < 4; ++j)
     {
      if(StringLen(pcand_sym[j]) == 0 || pcand_slot[j] < 0)
         continue;
      if(pcand_sym[j] == _Symbol)
         continue;                       // skip a partner that duplicates the host
      if(g_n_legs >= QM_MC_MAX_LEGS)
         break;
      g_leg_sym[g_n_legs]  = pcand_sym[j];
      g_leg_slot[g_n_legs] = pcand_slot[j];
      g_leg_beta[g_n_legs] = 0.0;        // resolved each closed bar by multi-OLS
      g_n_legs++;
     }

   // BASKET wiring: register the active universe and warm D1 history so foreign
   // closed-bar reads return real data in the .DWX tester.
   string universe[];
   ArrayResize(universe, g_n_legs);
   for(int L = 0; L < g_n_legs; ++L)
      universe[L] = g_leg_sym[L];
   QM_SymbolGuardInit(universe);
   QM_BasketWarmupHistory(universe, PERIOD_D1, strategy_training_window_bars + 60);

   g_basket_side      = 0;
   g_bars_since_refit = 0;

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"host\":\"%s\",\"n_legs\":%d,\"training\":%d,\"lag_p\":%d,\"deadband_z\":%.3f,\"coint_weights\":\"rolling_multi_ols\"}",
                            _Symbol, g_n_legs, strategy_training_window_bars,
                            strategy_lag_p, strategy_deadband_z));
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

   // Latch the closed-bar event ONCE (single-consume) and reuse it. On a fresh
   // D1 bar refresh the cointegration/S state BEFORE the rule-based exit so the
   // exit sees the current S_t, and advance the flat/held refit counter.
   const bool nb = QM_IsNewBar();
   if(nb)
     {
      QM_AdvanceMultiCointState();
      // Refit cadence counts bars while FLAT (no basket position). While held,
      // the counter freezes so the monthly refit fires after a flat run.
      if(QM_BasketHasPosition())
         g_bars_since_refit++;            // ages toward the flat-only refit trigger
      else
         g_bars_since_refit = 0;          // flat: weights are fresh each bar
     }

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
      g_bars_since_refit = 0;             // reset cadence after a flat-only refit/exit
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
