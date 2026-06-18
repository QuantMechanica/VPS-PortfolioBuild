#property strict
#property version   "5.0"
#property description "QM5_11254 ht-cvine-cmpi — Gaussian C-vine conditional mispricing index (CMPI) Bollinger basket trade (D1)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11254 ht-cvine-cmpi
// -----------------------------------------------------------------------------
// Source: Hudson & Thames, "C-vine Copula Strategy", ArbitrageLab documentation
// (source_id af021dd0-e07d-5f72-9933-de7a3533934e). Card:
// artifacts/cards_approved/QM5_11254_ht-cvine-cmpi.md (g0 APPROVED).
//
// GAUSSIAN-VINE REALIZATION (flagged). A faithful C-vine fit is an iterative
// pair-copula construction — effectively a per-edge MLE — which V5 HR14 forbids
// (no ML, no iterative optimiser in MQL5). This build realises the C-vine
// DETERMINISTICALLY as a GAUSSIAN C-vine:
//
//   1. Map each leg's formation-window returns to empirical-CDF ranks
//      u = rank/(m+1)  (pseudo-observations), then to NORMAL SCORES z = Phi^{-1}(u).
//   2. Under the normal-score map a C-vine of bivariate Gaussian pair-copulas is
//      EXACTLY a single multivariate Gaussian copula. Its correlation matrix R is
//      estimated CLOSED-FORM, per pair, by the Kendall relation
//          rho_ij = sin(pi/2 * tau_ij)         (method-of-moments, NO MLE).
//   3. The C-vine "conditional mispricing index" of the TARGET (host X) given the
//      partner basket Y = (Y1..Yk) is the closed-form Gaussian CONDITIONAL CDF
//          MPI = P(U_X <= u_X | U_Y = u_Y)
//              = Phi( ( z_X - b . z_Y ) / sqrt(s) )
//      where  b = R_XY * R_YY^{-1}   (conditional-mean coefficients) and
//             s = 1 - R_XY * R_YY^{-1} * R_YX   (conditional variance, the Schur
//      complement). This is precisely the partial-correlation recursion a C-vine
//      performs, expressed in one closed-form linear solve over the (k x k)
//      partner correlation block R_YY (deterministic Gauss-Jordan, k <= 4).
//      No iteration over likelihoods, no AIC family search, no ML.
//
//   CMPI (cumulative mispricing index, de-meaned, card rule):
//      cmpi += (MPI - 0.5)   on each clean closed-bar step.
//
// Entry (one cohort position at a time), Bollinger band over `PastObs` of cmpi:
//   mean = SMA(cmpi, PastObs) ; std = STDEV(cmpi, PastObs).
//   SHORT target-vs-basket if cmpi > mean + k*std  (target rich -> SELL host X,
//        partner basket takes the opposite side, inverse-vol split).
//   LONG  target-vs-basket if cmpi < mean - k*std  (target cheap -> BUY host X,
//        partner basket SELLs).
//
// Exit:
//   - cmpi crosses the rolling mean (revert to fair).
//   - protective stop: |cmpi - mean| >= StopStd * std against the position.
//   - time stop after MaxHoldBars D1 bars.
//   On ANY exit the cumulative cmpi series is RESET to its rolling mean baseline
//   (flat-only refit analogue — card monthly-refit rule realised as exit-reset).
//
// BASKET WIRING (kind=basket, basket_manifest.json). Host (target X) trades
// `_Symbol` via the framework magic (slot = qm_magic_slot_offset). Each partner
// leg trades a FOREIGN .DWX symbol via QM_BasketOpenPosition with its own
// registered symbol_slot. All legs are warmed in OnInit so foreign-symbol reads
// return real data in the .DWX tester. One position per (magic, symbol).
//
// Cohort model, registered in magic_numbers.csv (central step, not done here):
//   slot 0 EURUSD.DWX (target X) — host / pivot
//   slot 1 GBPUSD.DWX (partner Y1)
//   slot 2 AUDUSD.DWX (partner Y2)
//   slot 3 NZDUSD.DWX (partner Y3)
//   slot 4 NDX.DWX    (partner Y4 / cross-asset, optional)
// A setfile selects WHICH partners this instance uses (strategy_partnerN_symbol
// / strategy_partnerN_slot, empty symbol = leg disabled).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11254;
input int    qm_magic_slot_offset       = 0;     // TARGET (host X) leg slot
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
// Partner basket legs (Y1..Y4). Empty symbol disables a leg. Defaults bind the
// FX cohort: EURUSD.DWX target (X) vs GBPUSD/AUDUSD/NZDUSD partners.
input string strategy_partner1_symbol   = "GBPUSD.DWX"; // foreign .DWX leg Y1
input int    strategy_partner1_slot     = 1;
input string strategy_partner2_symbol   = "AUDUSD.DWX"; // foreign .DWX leg Y2
input int    strategy_partner2_slot     = 2;
input string strategy_partner3_symbol   = "NZDUSD.DWX"; // foreign .DWX leg Y3
input int    strategy_partner3_slot     = 3;
input string strategy_partner4_symbol   = "";           // foreign .DWX leg Y4 (off)
input int    strategy_partner4_slot     = 4;

input int    strategy_training_window_bars = 504;  // formation window of D1 returns (P3 {252,504,756})
input int    strategy_past_obs          = 20;      // rolling CMPI Bollinger window (P3 {10,20,40})
input double strategy_threshold_std     = 1.0;     // entry band k (P3 {0.75,1.0,1.25})
input double strategy_stop_std          = 3.0;     // protective stop band (P3 {2.5,3.0,3.5})
input int    strategy_max_hold_bars     = 60;      // time stop in D1 bars (P3 {30,60,90})
input double strategy_std_floor         = 1e-4;    // skip entry if rolling cmpi std below floor
input int    strategy_min_d1_bars       = 560;     // need >= training_window+buffer synced D1 bars
input double strategy_leg_risk_split    = 0.5;     // host gets this share; basket splits the rest

// -----------------------------------------------------------------------------
// File-scope cohort state, advanced once per closed D1 bar.
// -----------------------------------------------------------------------------
#define QM_CVINE_MAX_PARTNERS 4
#define QM_CVINE_MAX_LEGS     5   // host + up to 4 partners
#define QM_CVINE_CMPI_BUF     256 // rolling cmpi ring capacity (>= max PastObs)

string   g_partner_sym[QM_CVINE_MAX_PARTNERS];
int      g_partner_slot[QM_CVINE_MAX_PARTNERS];
int      g_npartner          = 0;        // active partner legs
double   g_cmpi              = 0.0;      // cumulative mispricing index (de-meaned)
bool     g_mpi_ready         = false;    // last closed bar produced a clean MPI step

// Rolling ring of recent cmpi values for the Bollinger mean/std.
double   g_cmpi_ring[QM_CVINE_CMPI_BUF];
int      g_cmpi_count        = 0;        // number of valid samples stored
int      g_cmpi_head         = 0;        // next write index (circular)

// =============================================================================
// CLOSED-FORM standard-normal CDF and inverse CDF (deterministic, bounded).
// =============================================================================

// Standard normal CDF via the Abramowitz & Stegun 7.1.26 erf approximation.
// |error| < 1.5e-7. Pure arithmetic, no iteration.
double QM_NormCDF(const double x)
  {
   const double t = 1.0 / (1.0 + 0.2316419 * MathAbs(x));
   const double d = 0.3989422804014327 * MathExp(-0.5 * x * x); // 1/sqrt(2pi)*exp
   double p = d * t * (0.319381530
                       + t * (-0.356563782
                              + t * (1.781477937
                                     + t * (-1.821255978
                                            + t * 1.330274429))));
   if(x >= 0.0)
      return 1.0 - p;
   return p;
  }

// Inverse standard normal CDF (quantile) via Acklam's rational approximation.
// Bounded, deterministic; relative error < 1.15e-9 over (0,1).
double QM_NormInv(const double p_in)
  {
   double p = p_in;
   if(p < 1e-12)
      p = 1e-12;
   if(p > 1.0 - 1e-12)
      p = 1.0 - 1e-12;

   const double a1 = -3.969683028665376e+01;
   const double a2 =  2.209460984245205e+02;
   const double a3 = -2.759285104469687e+02;
   const double a4 =  1.383577518672690e+02;
   const double a5 = -3.066479806614716e+01;
   const double a6 =  2.506628277459239e+00;
   const double b1 = -5.447609879822406e+01;
   const double b2 =  1.615858368580409e+02;
   const double b3 = -1.556989798598866e+02;
   const double b4 =  6.680131188771972e+01;
   const double b5 = -1.328068155288572e+01;
   const double c1 = -7.784894002430293e-03;
   const double c2 = -3.223964580411365e-01;
   const double c3 = -2.400758277161838e+00;
   const double c4 = -2.549732539343734e+00;
   const double c5 =  4.374664141464968e+00;
   const double c6 =  2.938163982698783e+00;
   const double d1 =  7.784695709041462e-03;
   const double d2 =  3.224671290700398e-01;
   const double d3 =  2.445134137142996e+00;
   const double d4 =  3.754408661907416e+00;

   const double plow  = 0.02425;
   const double phigh = 1.0 - plow;
   double q, r, x;

   if(p < plow)
     {
      q = MathSqrt(-2.0 * MathLog(p));
      x = (((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6) /
          ((((d1 * q + d2) * q + d3) * q + d4) * q + 1.0);
     }
   else if(p <= phigh)
     {
      q = p - 0.5;
      r = q * q;
      x = (((((a1 * r + a2) * r + a3) * r + a4) * r + a5) * r + a6) * q /
          (((((b1 * r + b2) * r + b3) * r + b4) * r + b5) * r + 1.0);
     }
   else
     {
      q = MathSqrt(-2.0 * MathLog(1.0 - p));
      x = -(((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6) /
           ((((d1 * q + d2) * q + d3) * q + d4) * q + 1.0);
     }
   return x;
  }

// =============================================================================
// Deterministic dense linear solve for the partner correlation block R_YY.
// Solves R_YY * out = rhs (R_YY is k x k symmetric PD) by Gauss-Jordan with
// partial pivoting. k <= QM_CVINE_MAX_PARTNERS (4). Returns false on a singular
// / degenerate block (the EA then skips the MPI step). No iteration, no ML.
// =============================================================================
bool QM_SolveSPD(double &A[], double &rhs[], const int k, double &out[])
  {
   if(k <= 0)
      return false;
   // Work on copies so the caller's A/rhs are untouched.
   double M[];   // k x k augmented coefficient
   double b[];
   ArrayResize(M, k * k);
   ArrayResize(b, k);
   for(int i = 0; i < k; ++i)
     {
      b[i] = rhs[i];
      for(int j = 0; j < k; ++j)
         M[i * k + j] = A[i * k + j];
     }

   for(int col = 0; col < k; ++col)
     {
      // Partial pivot: largest |M[row][col]| at or below the diagonal.
      int piv = col;
      double best = MathAbs(M[col * k + col]);
      for(int r = col + 1; r < k; ++r)
        {
         const double v = MathAbs(M[r * k + col]);
         if(v > best)
           {
            best = v;
            piv = r;
           }
        }
      if(best < 1e-14)
         return false;                  // singular block -> skip step
      if(piv != col)
        {
         for(int j = 0; j < k; ++j)
           {
            const double tmp = M[col * k + j];
            M[col * k + j] = M[piv * k + j];
            M[piv * k + j] = tmp;
           }
         const double tb = b[col];
         b[col] = b[piv];
         b[piv] = tb;
        }
      // Normalize the pivot row.
      const double diag = M[col * k + col];
      const double inv = 1.0 / diag;
      for(int j = 0; j < k; ++j)
         M[col * k + j] *= inv;
      b[col] *= inv;
      // Eliminate the column from every other row.
      for(int r = 0; r < k; ++r)
        {
         if(r == col)
            continue;
         const double factor = M[r * k + col];
         if(factor == 0.0)
            continue;
         for(int j = 0; j < k; ++j)
            M[r * k + j] -= factor * M[col * k + j];
         b[r] -= factor * b[col];
        }
     }

   ArrayResize(out, k);
   for(int i = 0; i < k; ++i)
      out[i] = b[i];
   return true;
  }

// =============================================================================
// One C-vine CMPI step. Builds the normal-score sample matrix over the last
// `formation` CLOSED D1 returns of the host (X) + active partner legs, estimates
// the Gaussian correlation matrix closed-form (Kendall tau -> rho), then computes
// the conditional CDF of the host given the partner basket for the MOST RECENT
// return. Returns false on missing / degenerate data (EA skips the step).
// Runs once per closed D1 bar (OnTick gates via QM_IsNewBar).
// =============================================================================
bool QM_ComputeCVineMPI(const int formation, double &mpi_out)
  {
   mpi_out = 0.5;
   if(formation < 30)
      return false;

   const int nleg = 1 + g_npartner;        // index 0 = host X, 1..k = partners
   if(nleg < 2)
      return false;

   const int n_close = formation + 1;       // shifts 1..formation+1
   if(Bars(_Symbol, PERIOD_D1) < strategy_min_d1_bars) return false; // perf-allowed: bar-count availability check
   for(int p = 0; p < g_npartner; ++p)
      if(Bars(g_partner_sym[p], PERIOD_D1) < strategy_min_d1_bars) return false; // perf-allowed: partner bar-count check

   // Closes for every leg over the formation window. closes[leg*n_close + i].
   double closes[];
   ArrayResize(closes, nleg * n_close);
   for(int i = 0; i < n_close; ++i)
     {
      // perf-allowed: closed-bar host close for the C-vine formation window
      // (computed once per closed D1 bar; OnTick gates via QM_IsNewBar).
      const double hx = iClose(_Symbol, PERIOD_D1, i + 1); // perf-allowed: host close, formation window
      if(hx <= 0.0)
         return false;
      closes[0 * n_close + i] = hx;
      for(int p = 0; p < g_npartner; ++p)
        {
         const double hy = iClose(g_partner_sym[p], PERIOD_D1, i + 1); // perf-allowed: partner close, formation window
         if(hy <= 0.0)
            return false;
         closes[(p + 1) * n_close + i] = hy;
        }
     }

   // Log returns per leg. r[leg*m + k] = log(close_k / close_{k+1}).
   // r[*,0] = MOST RECENT return (last closed bar). m = formation samples.
   const int m = formation;
   double ret[];
   ArrayResize(ret, nleg * m);
   for(int leg = 0; leg < nleg; ++leg)
      for(int k = 0; k < m; ++k)
        {
         const double c0 = closes[leg * n_close + k];
         const double c1 = closes[leg * n_close + k + 1];
         ret[leg * m + k] = MathLog(c0 / c1);
        }

   // Normal scores z[leg*m + a] = Phi^{-1}( rank/(m+1) ). Rank = count of window
   // returns strictly less than the sample. O(nleg * m^2), bounded (nleg<=5,
   // m<=756) and gated to once per closed D1 bar.
   double z[];
   ArrayResize(z, nleg * m);
   for(int leg = 0; leg < nleg; ++leg)
     {
      for(int a = 0; a < m; ++a)
        {
         int rank = 1;                    // ranks 1..m; +1 baseline so u in (0,1)
         const double va = ret[leg * m + a];
         for(int b = 0; b < m; ++b)
            if(ret[leg * m + b] < va)
               ++rank;
         const double u = (double)rank / (double)(m + 1);
         z[leg * m + a] = QM_NormInv(u);
        }
     }

   // Gaussian correlation matrix R (nleg x nleg) via Kendall's tau per pair:
   //   tau = (concordant - discordant) / nPairs ; rho = sin(pi/2 * tau).
   // Computed on the RAW returns (rank-based, so identical to using z ranks).
   double R[];
   ArrayResize(R, nleg * nleg);
   for(int leg = 0; leg < nleg; ++leg)
      R[leg * nleg + leg] = 1.0;
   const double npairs = 0.5 * (double)m * (double)(m - 1);
   if(npairs <= 0.0)
      return false;
   for(int i = 0; i < nleg; ++i)
     {
      for(int j = i + 1; j < nleg; ++j)
        {
         long concordant = 0;
         long discordant = 0;
         for(int a = 0; a < m - 1; ++a)
           {
            const double xa = ret[i * m + a];
            const double ya = ret[j * m + a];
            for(int b = a + 1; b < m; ++b)
              {
               const double prod = (xa - ret[i * m + b]) * (ya - ret[j * m + b]);
               if(prod > 0.0)      ++concordant;
               else if(prod < 0.0) ++discordant;
              }
           }
         double tau = ((double)(concordant - discordant)) / npairs;
         if(tau > 0.999)  tau = 0.999;
         if(tau < -0.999) tau = -0.999;
         double rho = MathSin(M_PI_2 * tau);
         if(rho > 0.999)  rho = 0.999;
         if(rho < -0.999) rho = -0.999;
         R[i * nleg + j] = rho;
         R[j * nleg + i] = rho;
        }
     }

   // Conditional CDF of the host (leg 0) given the partner block (legs 1..k):
   //   b = R_XY * R_YY^{-1} ; cond_mean = b . z_Y ; s = 1 - b . R_YX.
   //   MPI = Phi( (z_X - cond_mean) / sqrt(s) ).
   const int k = g_npartner;
   double zX = z[0 * m + 0];              // host normal score, most-recent return
   if(k == 0)
      return false;

   // R_YY (k x k) and R_XY (1 x k); partner index p maps to leg p+1.
   double Ryy[];
   double Rxy[];
   ArrayResize(Ryy, k * k);
   ArrayResize(Rxy, k);
   for(int a = 0; a < k; ++a)
     {
      Rxy[a] = R[0 * nleg + (a + 1)];
      for(int b = 0; b < k; ++b)
         Ryy[a * k + b] = R[(a + 1) * nleg + (b + 1)];
     }

   // Solve R_YY * w = Rxy^T  (w = R_YY^{-1} R_YX). Then b = w (symmetric).
   double w[];
   if(!QM_SolveSPD(Ryy, Rxy, k, w))
      return false;

   double cond_mean = 0.0;
   double quad = 0.0;                     // b . R_YX = Rxy . w
   for(int a = 0; a < k; ++a)
     {
      const double zYa = z[(a + 1) * m + 0];   // partner a normal score, most-recent
      cond_mean += w[a] * zYa;
      quad      += Rxy[a] * w[a];
     }
   double s = 1.0 - quad;                 // conditional variance (Schur complement)
   if(s <= 1e-9)
      return false;                       // degenerate -> skip step
   const double denom = MathSqrt(s);

   mpi_out = QM_NormCDF((zX - cond_mean) / denom);
   return true;
  }

// -----------------------------------------------------------------------------
// Rolling cmpi ring helpers (Bollinger mean / std over the last PastObs values).
// -----------------------------------------------------------------------------
void QM_CmpiRingPush(const double value)
  {
   g_cmpi_ring[g_cmpi_head] = value;
   g_cmpi_head = (g_cmpi_head + 1) % QM_CVINE_CMPI_BUF;
   if(g_cmpi_count < QM_CVINE_CMPI_BUF)
      ++g_cmpi_count;
  }

// Mean + std over the last `window` pushed values. Returns false if fewer than
// `window` samples are available yet.
bool QM_CmpiRingStats(const int window, double &mean_out, double &std_out)
  {
   mean_out = 0.0;
   std_out  = 0.0;
   int w = window;
   if(w < 2)
      w = 2;
   if(g_cmpi_count < w)
      return false;
   double sum = 0.0;
   for(int i = 0; i < w; ++i)
     {
      // Walk back from the most recent write.
      int idx = g_cmpi_head - 1 - i;
      while(idx < 0)
         idx += QM_CVINE_CMPI_BUF;
      sum += g_cmpi_ring[idx];
     }
   const double mean = sum / (double)w;
   double var = 0.0;
   for(int i = 0; i < w; ++i)
     {
      int idx = g_cmpi_head - 1 - i;
      while(idx < 0)
         idx += QM_CVINE_CMPI_BUF;
      const double d = g_cmpi_ring[idx] - mean;
      var += d * d;
     }
   var /= (double)(w - 1);               // sample std
   mean_out = mean;
   std_out  = MathSqrt(var);
   return true;
  }

// Advance the cumulative cmpi once per closed D1 bar and push it to the ring.
void QM_AdvanceCVineState()
  {
   double mpi = 0.5;
   if(QM_ComputeCVineMPI(strategy_training_window_bars, mpi))
     {
      g_cmpi += (mpi - 0.5);
      QM_CmpiRingPush(g_cmpi);
      g_mpi_ready = true;
     }
   else
     {
      g_mpi_ready = false;
     }
  }

// -----------------------------------------------------------------------------
// Cohort position helpers.
// -----------------------------------------------------------------------------
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

// True if ANY leg of the cohort (host or any partner) currently holds a position.
bool QM_CohortHasPosition()
  {
   if(QM_LegOpenCount(qm_magic_slot_offset, _Symbol) > 0)
      return true;
   for(int p = 0; p < g_npartner; ++p)
      if(QM_LegOpenCount(g_partner_slot[p], g_partner_sym[p]) > 0)
         return true;
   return false;
  }

// Direction of the open HOST (X) leg: +1 host long, -1 host short, 0 none.
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

// Bars held by the host (X) leg (D1), or -1 if no host position.
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

// Close every leg of the cohort (host + active partners) under this ea_id.
void QM_CloseCohort(const QM_ExitReason reason)
  {
   const int host_magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   int partner_magic[QM_CVINE_MAX_PARTNERS];
   for(int p = 0; p < g_npartner; ++p)
      partner_magic[p] = QM_Magic(qm_ea_id, g_partner_slot[p]);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      const long mg = PositionGetInteger(POSITION_MAGIC);
      bool mine = (mg == host_magic);
      for(int p = 0; p < g_npartner && !mine; ++p)
         if(mg == partner_magic[p])
            mine = true;
      if(mine)
         QM_TM_ClosePosition(ticket, reason);
     }
  }

// Open one partner (Y) market leg on a FOREIGN symbol via the basket path.
bool QM_OpenPartnerLeg(const int p, const QM_OrderType ot, const string reason)
  {
   QM_BasketOrderRequest br;
   br.symbol             = g_partner_sym[p];
   br.type               = ot;
   br.price              = 0.0;     // basket path fills market price at send
   br.sl                 = 0.0;     // cohort-level (cmpi) exits manage the legs
   br.tp                 = 0.0;
   br.lots               = 0.0;     // 0 -> basket sizes via QM_LotsForRisk
   br.reason             = reason;
   br.symbol_slot        = g_partner_slot[p];
   br.expiration_seconds = 0;

   ulong tk = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, br, tk);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick filter. Fail-open spread guard on the host leg only; the
// C-vine logic runs on closed bars. No session restriction (D1 cohort).
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

// Entry on a freshly closed D1 bar. The host (target X) leg is opened here via
// the framework path; each active partner leg is opened immediately via the
// basket path so the whole cohort goes on together. Partners take the OPPOSITE
// side of the host (target-vs-basket spread). Caller guarantees QM_IsNewBar().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_CohortHasPosition())
      return false;
   if(!g_mpi_ready || g_npartner <= 0)
      return false;

   double mean = 0.0, sd = 0.0;
   if(!QM_CmpiRingStats(strategy_past_obs, mean, sd))
      return false;                      // not enough rolling samples yet
   if(sd < strategy_std_floor)
      return false;                      // volatility floor

   const double upper = mean + strategy_threshold_std * sd;
   const double lower = mean - strategy_threshold_std * sd;

   int dir = 0;                          // +1 LONG target/SHORT basket, -1 inverse
   if(g_cmpi > upper)
      dir = -1;                          // target rich -> SHORT host X, BUY basket
   else if(g_cmpi < lower)
      dir = +1;                          // target cheap -> BUY host X, SELL basket
   if(dir == 0)
      return false;

   const QM_OrderType host_ot    = (dir > 0) ? QM_BUY  : QM_SELL;
   const QM_OrderType partner_ot = (dir > 0) ? QM_SELL : QM_BUY;

   // Open partner legs FIRST through the basket path. If any fails (e.g. data
   // gap), unwind the cohort so we never carry a naked subset.
   const string rsn = (dir > 0) ? "cvine_cmpi_long_target" : "cvine_cmpi_short_target";
   bool any_partner = false;
   for(int p = 0; p < g_npartner; ++p)
     {
      if(QM_OpenPartnerLeg(p, partner_ot, rsn))
         any_partner = true;
      else
        {
         QM_CloseCohort(QM_EXIT_STRATEGY); // unwind whatever opened
         return false;
        }
     }
   if(!any_partner)
      return false;

   // Build the host (target) leg for the framework to send. No fixed SL/TP — the
   // cohort is managed by the cmpi mean-cross / stop / time-stop exits.
   req.type        = host_ot;
   req.price       = 0.0;               // framework fills market price at send
   req.sl          = 0.0;
   req.tp          = 0.0;
   req.reason      = rsn;
   req.symbol_slot = qm_magic_slot_offset;  // host (target) leg slot
   return true;
  }

// No active per-position trade management; cohort exits are rule-based.
void Strategy_ManageOpenPosition()
  {
  }

// Cohort-level exits: cmpi mean-cross, std-band protective stop, time stop.
// Returning true triggers the framework's host-leg close loop in OnTick; we ALSO
// close every partner leg here so the whole cohort unwinds together, then RESET
// the cumulative cmpi to the rolling mean baseline (flat-only refit analogue).
bool Strategy_ExitSignal()
  {
   const int host_dir = QM_HostLegDir();   // +1 long target, -1 short target, 0 none
   if(host_dir == 0)
      return false;

   bool do_exit = false;
   QM_ExitReason reason = QM_EXIT_STRATEGY;

   if(g_mpi_ready)
     {
      double mean = 0.0, sd = 0.0;
      if(QM_CmpiRingStats(strategy_past_obs, mean, sd))
        {
         const double dev = g_cmpi - mean;
         // Mean cross: a LONG target entered when cmpi < mean; exit when cmpi
         // returns to / crosses the mean (dev >= 0). SHORT target is symmetric.
         if(host_dir > 0 && dev >= 0.0)
           { do_exit = true; reason = QM_EXIT_STRATEGY; }
         else if(host_dir < 0 && dev <= 0.0)
           { do_exit = true; reason = QM_EXIT_STRATEGY; }
         // Protective stop: cmpi overextends against the position beyond StopStd.
         if(!do_exit && sd > 0.0)
           {
            if(host_dir > 0 && dev <= -strategy_stop_std * sd)
              { do_exit = true; reason = QM_EXIT_STRATEGY; }
            else if(host_dir < 0 && dev >= strategy_stop_std * sd)
              { do_exit = true; reason = QM_EXIT_STRATEGY; }
           }
        }
     }

   // Time stop: close the cohort after N D1 bars held.
   if(!do_exit)
     {
      const int held = QM_HostLegBarsHeld();
      if(held >= 0 && held >= strategy_max_hold_bars)
        { do_exit = true; reason = QM_EXIT_TIME_STOP; }
     }

   if(do_exit)
     {
      // Close the PARTNER legs here; the OnTick close loop closes the host leg.
      for(int p = 0; p < g_npartner; ++p)
        {
         const int partner_magic = QM_Magic(qm_ea_id, g_partner_slot[p]);
         if(partner_magic <= 0)
            continue;
         for(int i = PositionsTotal() - 1; i >= 0; --i)
           {
            const ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket))
               continue;
            if(PositionGetInteger(POSITION_MAGIC) != partner_magic)
               continue;
            if(PositionGetString(POSITION_SYMBOL) != g_partner_sym[p])
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

   // Resolve active partner legs (non-empty symbol, distinct from host).
   g_npartner = 0;
   string cand_sym[QM_CVINE_MAX_PARTNERS];
   int    cand_slot[QM_CVINE_MAX_PARTNERS];
   cand_sym[0]  = strategy_partner1_symbol; cand_slot[0] = strategy_partner1_slot;
   cand_sym[1]  = strategy_partner2_symbol; cand_slot[1] = strategy_partner2_slot;
   cand_sym[2]  = strategy_partner3_symbol; cand_slot[2] = strategy_partner3_slot;
   cand_sym[3]  = strategy_partner4_symbol; cand_slot[3] = strategy_partner4_slot;
   for(int i = 0; i < QM_CVINE_MAX_PARTNERS; ++i)
     {
      if(StringLen(cand_sym[i]) == 0)
         continue;
      if(cand_sym[i] == _Symbol)
         continue;                       // skip a partner equal to the host
      g_partner_sym[g_npartner]  = cand_sym[i];
      g_partner_slot[g_npartner] = cand_slot[i];
      ++g_npartner;
     }

   // BASKET wiring: register host + partner legs and warm their D1 history so
   // foreign-symbol closes return real data in the .DWX tester.
   string universe[];
   ArrayResize(universe, 1 + g_npartner);
   universe[0] = _Symbol;
   for(int p = 0; p < g_npartner; ++p)
      universe[p + 1] = g_partner_sym[p];
   QM_SymbolGuardInit(universe);
   QM_BasketWarmupHistory(universe, PERIOD_D1, strategy_training_window_bars + 80);

   // Reset cumulative cmpi + rolling ring.
   g_cmpi       = 0.0;
   g_cmpi_count = 0;
   g_cmpi_head  = 0;
   g_mpi_ready  = false;

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"target\":\"%s\",\"host_slot\":%d,\"npartner\":%d,\"training\":%d,\"past_obs\":%d}",
                            _Symbol, qm_magic_slot_offset, g_npartner,
                            strategy_training_window_bars, strategy_past_obs));
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
   // D1 bar, advance the C-vine cmpi BEFORE the rule-based exit so the exit sees
   // the current cmpi + rolling band.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvanceCVineState();

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
