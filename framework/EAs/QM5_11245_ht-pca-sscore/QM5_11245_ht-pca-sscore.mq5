#property strict
#property version   "5.0"
#property description "QM5_11245 ht-pca-sscore — Avellaneda-Lee PCA s-score stat-arb (D1, basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11245 ht-pca-sscore
// -----------------------------------------------------------------------------
// Source: Hudson & Thames "PCA Approach" (ArbitrageLab docs), primary reference
// Avellaneda, M. & Lee, J.H. (2010) "Statistical arbitrage in the US equities
// market". source_id af021dd0-e07d-5f72-9933-de7a3533934e.
// Card: artifacts/cards_approved/QM5_11245_ht-pca-sscore.md (g0_status APPROVED).
//
// BASKET EA. A fixed universe of liquid .DWX CFDs (FX majors + US indices) is
// decomposed by PCA of the rolling daily-return CORRELATION matrix. Each asset's
// standardized returns are regressed on the top-k principal-component factor
// returns (OLS); the regression residual is cumulated into an OU process X_i(t).
// The OU model is fit closed-form as an AR(1): X(t)=a+b*X(t-1)+eps. The s-score
//   s_i = (X_i - m_i) / sigma_eq_i,  m_i = a/(1-b),
//   sigma_eq_i = sqrt(var(eps)/(1-b^2)),  kappa_i = -ln(b)*252
// drives mean-reversion entries on the HOST symbol's own residual.
//
// DETERMINISM (HR14 — NO ML):
//   PCA  = symmetric Jacobi eigenvalue rotation on the 6x6 correlation matrix
//          (deterministic, bounded sweeps; no sklearn / power-method randomness).
//   OLS  = closed-form normal equations (k<=3 factors -> small symmetric solve).
//   OU   = closed-form AR(1) regression (b=cov/var). No online learning, no
//          PnL-adaptive parameters. All math runs on CLOSED D1 bars, advanced
//          ONCE per new D1 bar and cached.
//
// Universe is fixed and identical for every host instance; each instance trades
// only its own host residual. One position per magic on the host.
//
// Only the 5 Strategy_* hooks + the OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11245;
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
input int    strategy_corr_window       = 252;   // PCA correlation window (D1 bars). P3 {126,252,504}
input int    strategy_residual_window   = 60;    // OLS/OU residual window (D1 bars). P3 {40,60,90}
input int    strategy_num_factors       = 2;     // top-k principal components used as factors
input double strategy_k_min             = 8.4;   // min OU mean-reversion speed kappa. P3 {6.0,8.4,12.0}
input double strategy_sbo               = 1.25;  // s-score: open LONG  when s < -sbo. P3 {1.0,1.25,1.5}
input double strategy_sso               = 1.25;  // s-score: open SHORT when s > +sso. P3 {1.0,1.25,1.5}
input double strategy_sbc               = 0.75;  // close LONG  when s >= -sbc. P3 {0.5,0.75,1.0}
input double strategy_ssc               = 0.50;  // close SHORT when s <= +ssc. P3 {0.25,0.50,0.75}
input double strategy_s_protect         = 3.0;   // protective stop at |s| >= this
input int    strategy_time_stop_bars    = 60;    // close after this many D1 bars in trade
input int    strategy_min_members       = 4;     // min tradable universe symbols after data QC
input int    strategy_atr_period        = 20;    // emergency-stop ATR period (D1)
input double strategy_stop_atr_mult     = 4.0;   // emergency MT5 stop = mult * ATR (bounds worst case)
input double strategy_spread_pct_of_stop = 20.0; // skip new entry if host spread > this % of stop

// -----------------------------------------------------------------------------
// Fixed PCA universe (card target_symbols; all verified in dwx_symbol_matrix.csv).
// FX majors + US indices. Identical for every host instance.
// -----------------------------------------------------------------------------
#define QM_UNIV     6
#define QM_MAXWIN   520     // max corr_window supported by fixed buffers
#define QM_RETBUF   (QM_MAXWIN + 4)

string g_univ[QM_UNIV] =
  {
   "EURUSD.DWX","GBPUSD.DWX","AUDUSD.DWX","NZDUSD.DWX","NDX.DWX","WS30.DWX"
  };

int g_host_idx = -1;        // index of _Symbol within g_univ (-1 if host not in universe)

// Cached per-closed-bar state.
double g_s_score   = 0.0;   // host residual s-score this bar
double g_kappa     = 0.0;   // host OU speed
bool   g_ready     = false; // true when s-score is valid this bar
int    g_bars_in_trade = 0; // D1 bars held (advanced once per new bar while open)

// =============================================================================
// Linear-algebra helpers (deterministic, no ML).
// =============================================================================

// Symmetric Jacobi eigenvalue decomposition of an n x n symmetric matrix A.
// On return, eval[i] = eigenvalues, evec[i][j] = j-th component of eigenvector i
// (rows = eigenvectors). Deterministic: fixed sweep count, classic cyclic Jacobi.
void QM_JacobiEigen(double &A[][QM_UNIV], const int n,
                    double &eval[], double &evec[][QM_UNIV])
  {
   double a[QM_UNIV][QM_UNIV];
   double v[QM_UNIV][QM_UNIV];
   for(int i = 0; i < n; ++i)
      for(int j = 0; j < n; ++j)
        {
         a[i][j] = A[i][j];
         v[i][j] = (i == j) ? 1.0 : 0.0;
        }

   const int max_sweeps = 100;
   for(int sweep = 0; sweep < max_sweeps; ++sweep)
     {
      // Off-diagonal magnitude.
      double off = 0.0;
      for(int p = 0; p < n - 1; ++p)
         for(int q = p + 1; q < n; ++q)
            off += a[p][q] * a[p][q];
      if(off < 1.0e-18)
         break;

      for(int p = 0; p < n - 1; ++p)
        {
         for(int q = p + 1; q < n; ++q)
           {
            const double apq = a[p][q];
            if(MathAbs(apq) < 1.0e-300)
               continue;
            const double app = a[p][p];
            const double aqq = a[q][q];
            const double phi = 0.5 * (aqq - app);
            double t;   // tan of rotation angle
            const double denom = MathAbs(phi) + MathSqrt(phi * phi + apq * apq);
            if(denom < 1.0e-300)
               continue;
            t = apq / denom;
            if(phi < 0.0)
               t = -t;
            const double c = 1.0 / MathSqrt(t * t + 1.0);
            const double s = t * c;
            const double tau = s / (1.0 + c);

            a[p][p] = app - t * apq;
            a[q][q] = aqq + t * apq;
            a[p][q] = 0.0;
            a[q][p] = 0.0;

            for(int i = 0; i < n; ++i)
              {
               if(i != p && i != q)
                 {
                  const double aip = a[i][p];
                  const double aiq = a[i][q];
                  a[i][p] = aip - s * (aiq + tau * aip);
                  a[p][i] = a[i][p];
                  a[i][q] = aiq + s * (aip - tau * aiq);
                  a[q][i] = a[i][q];
                 }
              }
            for(int i = 0; i < n; ++i)
              {
               const double vip = v[i][p];
               const double viq = v[i][q];
               v[i][p] = vip - s * (viq + tau * vip);
               v[i][q] = viq + s * (vip - tau * viq);
              }
           }
        }
     }

   // eval = diagonal; evec rows = eigenvectors (v columns).
   for(int i = 0; i < n; ++i)
     {
      eval[i] = a[i][i];
      for(int j = 0; j < n; ++j)
         evec[i][j] = v[j][i];   // row i = i-th eigenvector
     }

   // Deterministic descending sort by eigenvalue (selection sort, n<=6).
   for(int i = 0; i < n - 1; ++i)
     {
      int mx = i;
      for(int j = i + 1; j < n; ++j)
         if(eval[j] > eval[mx])
            mx = j;
      if(mx != i)
        {
         const double te = eval[i]; eval[i] = eval[mx]; eval[mx] = te;
         for(int j = 0; j < n; ++j)
           {
            const double tv = evec[i][j]; evec[i][j] = evec[mx][j]; evec[mx][j] = tv;
           }
        }
     }

   // Fix sign convention deterministically: largest-magnitude component positive.
   for(int i = 0; i < n; ++i)
     {
      int am = 0;
      for(int j = 1; j < n; ++j)
         if(MathAbs(evec[i][j]) > MathAbs(evec[i][am]))
            am = j;
      if(evec[i][am] < 0.0)
         for(int j = 0; j < n; ++j)
            evec[i][j] = -evec[i][j];
     }
  }

// =============================================================================
// Per-closed-bar PCA s-score computation for the HOST residual.
// Reconstructs standardized return matrix over corr_window, runs PCA, OLS-regresses
// the host's standardized returns on the top-k factor returns over residual_window,
// cumulates residuals to an OU process, fits AR(1) closed-form, emits s-score.
// =============================================================================
void QM_AdvancePCA()
  {
   g_ready   = false;
   g_s_score = 0.0;
   g_kappa   = 0.0;

   if(g_host_idx < 0)
      return;

   int W = strategy_corr_window;
   if(W < 60)  W = 60;
   if(W > QM_MAXWIN) W = QM_MAXWIN;
   int RW = strategy_residual_window;
   if(RW < 20) RW = 20;
   if(RW > W - 2) RW = W - 2;

   // 1) Read W+1 daily closes for each universe member; derive W daily returns.
   //    ret[member][t], t=0..W-1 (t=W-1 = most recent closed-bar return).
   double ret[QM_UNIV][QM_RETBUF];
   bool   active[QM_UNIV];
   int    n_active = 0;

   for(int m = 0; m < QM_UNIV; ++m)
     {
      active[m] = false;
      const string sym = g_univ[m];
      if(Bars(sym, PERIOD_D1) < W + 4)
         continue;

      bool ok = true;
      double prev = 0.0;
      // shift (W+1) = oldest close ... shift 1 = newest closed bar.
      for(int t = 0; t < W + 1; ++t)
        {
         const int shift = (W + 1) - t;
         // perf-allowed: closed-bar foreign-symbol daily close reads (basket leg);
         // gated to once-per-new-D1-bar via QM_IsNewBar in OnTick.
         const double c = iClose(sym, PERIOD_D1, shift);
         if(c <= 0.0) { ok = false; break; }
         if(t > 0)
            ret[m][t - 1] = (c - prev) / prev;
         prev = c;
        }
      if(!ok)
         continue;
      active[m] = true;
      ++n_active;
     }

   if(!active[g_host_idx])
      return;
   if(n_active < strategy_min_members)
      return;

   // 2) Standardize each active member's return series over W (z-score).
   double mean[QM_UNIV];
   double sd[QM_UNIV];
   for(int m = 0; m < QM_UNIV; ++m)
     {
      mean[m] = 0.0; sd[m] = 0.0;
      if(!active[m]) continue;
      double s1 = 0.0;
      for(int t = 0; t < W; ++t) s1 += ret[m][t];
      mean[m] = s1 / W;
      double s2 = 0.0;
      for(int t = 0; t < W; ++t)
        { const double d = ret[m][t] - mean[m]; s2 += d * d; }
      sd[m] = MathSqrt(s2 / (W - 1));
      if(sd[m] <= 0.0)
        { active[m] = false; --n_active; }
     }

   if(!active[g_host_idx] || n_active < strategy_min_members)
      return;

   // Standardized matrix Z[m][t] for active members.
   double Z[QM_UNIV][QM_RETBUF];
   for(int m = 0; m < QM_UNIV; ++m)
     {
      if(!active[m]) continue;
      for(int t = 0; t < W; ++t)
         Z[m][t] = (ret[m][t] - mean[m]) / sd[m];
     }

   // 3) Correlation matrix C (n_active x n_active) on the active subset.
   //    Build a compact index map so PCA runs on a contiguous block.
   int idx[QM_UNIV];   // compact -> universe index
   int rmap[QM_UNIV];  // universe -> compact index (-1 if inactive)
   int n = 0;
   for(int m = 0; m < QM_UNIV; ++m)
     {
      rmap[m] = -1;
      if(active[m]) { idx[n] = m; rmap[m] = n; ++n; }
     }

   double C[QM_UNIV][QM_UNIV];
   for(int i = 0; i < n; ++i)
     {
      for(int j = i; j < n; ++j)
        {
         double acc = 0.0;
         const int mi = idx[i], mj = idx[j];
         for(int t = 0; t < W; ++t)
            acc += Z[mi][t] * Z[mj][t];
         acc /= (W - 1);   // since columns are unit-variance, this is correlation
         C[i][j] = acc;
         C[j][i] = acc;
        }
     }

   // 4) PCA via Jacobi. Top-k eigenvectors define the factor loadings.
   double eval[QM_UNIV];
   double evec[QM_UNIV][QM_UNIV];   // row = eigenvector
   QM_JacobiEigen(C, n, eval, evec);

   int k = strategy_num_factors;
   if(k < 1) k = 1;
   if(k > n - 1) k = n - 1;   // leave at least one residual dimension
   if(k < 1)
      return;

   // Ill-conditioning guard: leading eigenvalue must be meaningfully positive.
   if(eval[0] <= 1.0e-8)
      return;

   // 5) Factor return series F[f][t] = sum_i evec[f][i] * Z[idx[i]][t].
   double F[QM_UNIV][QM_RETBUF];
   for(int f = 0; f < k; ++f)
      for(int t = 0; t < W; ++t)
        {
         double acc = 0.0;
         for(int i = 0; i < n; ++i)
            acc += evec[f][i] * Z[idx[i]][t];
         F[f][t] = acc;
        }

   // 6) OLS: regress HOST standardized returns y[t] on the k factor returns over
   //    the most recent RW bars. Closed-form normal equations (k+1 unknowns incl.
   //    intercept). Then cumulate residuals into the OU process X.
   const int h = rmap[g_host_idx];           // compact host index
   const int t0 = W - RW;                     // residual window start

   // Design with intercept: columns [1, F0..F(k-1)]. p = k+1 params.
   const int P = k + 1;
   double XtX[QM_UNIV + 1][QM_UNIV + 1];
   double Xty[QM_UNIV + 1];
   for(int a = 0; a < P; ++a)
     {
      Xty[a] = 0.0;
      for(int b = 0; b < P; ++b)
         XtX[a][b] = 0.0;
     }

   for(int t = t0; t < W; ++t)
     {
      double xrow[QM_UNIV + 1];
      xrow[0] = 1.0;
      for(int f = 0; f < k; ++f) xrow[f + 1] = F[f][t];
      const double yt = Z[g_host_idx][t];
      for(int a = 0; a < P; ++a)
        {
         Xty[a] += xrow[a] * yt;
         for(int b = 0; b < P; ++b)
            XtX[a][b] += xrow[a] * xrow[b];
        }
     }

   // Solve XtX * beta = Xty via Gauss-Jordan (P<=4). Deterministic.
   double M[QM_UNIV + 1][QM_UNIV + 2];
   for(int a = 0; a < P; ++a)
     {
      for(int b = 0; b < P; ++b) M[a][b] = XtX[a][b];
      M[a][P] = Xty[a];
     }
   for(int col = 0; col < P; ++col)
     {
      // Partial pivot.
      int piv = col;
      for(int r = col + 1; r < P; ++r)
         if(MathAbs(M[r][col]) > MathAbs(M[piv][col]))
            piv = r;
      if(MathAbs(M[piv][col]) < 1.0e-12)
         return;   // ill-conditioned regression — skip
      if(piv != col)
         for(int c = 0; c <= P; ++c)
           { const double tmp = M[col][c]; M[col][c] = M[piv][c]; M[piv][c] = tmp; }
      const double d = M[col][col];
      for(int c = 0; c <= P; ++c) M[col][c] /= d;
      for(int r = 0; r < P; ++r)
        {
         if(r == col) continue;
         const double f2 = M[r][col];
         for(int c = 0; c <= P; ++c) M[r][c] -= f2 * M[col][c];
        }
     }
   double beta[QM_UNIV + 1];
   for(int a = 0; a < P; ++a) beta[a] = M[a][P];

   // 7) Residual series e[t] over the residual window, then cumulative OU X[t].
   double Xou[QM_RETBUF];
   int nx = 0;
   double cum = 0.0;
   for(int t = t0; t < W; ++t)
     {
      double fit = beta[0];
      for(int f = 0; f < k; ++f) fit += beta[f + 1] * F[f][t];
      const double e = Z[g_host_idx][t] - fit;
      cum += e;
      Xou[nx] = cum;
      ++nx;
     }
   if(nx < 10)
      return;

   // 8) AR(1) fit of X: X[t] = a + b*X[t-1] + eps. Closed-form OLS on (x_{t-1}, x_t).
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   const int npairs = nx - 1;
   for(int t = 1; t < nx; ++t)
     {
      const double xp = Xou[t - 1];
      const double xc = Xou[t];
      sx += xp; sy += xc; sxx += xp * xp; sxy += xp * xc;
     }
   const double denomB = npairs * sxx - sx * sx;
   if(MathAbs(denomB) < 1.0e-12)
      return;
   const double b = (npairs * sxy - sx * sy) / denomB;
   const double aa = (sy - b * sx) / npairs;

   // OU requires 0 < b < 1 (stationary mean reversion).
   if(b <= 0.0 || b >= 1.0)
      return;

   // kappa = -ln(b) * (252 / dt); dt=1 trading day, annualize by 252.
   const double kappa = -MathLog(b) * 252.0;
   g_kappa = kappa;

   // Residual variance of eps for sigma_eq.
   double sse = 0.0;
   for(int t = 1; t < nx; ++t)
     {
      const double pred = aa + b * Xou[t - 1];
      const double r = Xou[t] - pred;
      sse += r * r;
     }
   const double var_eps = (npairs > 2) ? sse / (npairs - 2) : 0.0;
   if(var_eps <= 0.0)
      return;

   const double m_eq = aa / (1.0 - b);                       // OU equilibrium mean
   const double denomEq = 1.0 - b * b;
   if(denomEq <= 0.0)
      return;
   const double sigma_eq = MathSqrt(var_eps / denomEq);
   if(sigma_eq <= 0.0)
      return;

   const double x_now = Xou[nx - 1];
   g_s_score = (x_now - m_eq) / sigma_eq;
   g_ready   = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick spread guard. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                             // no valid quote — defer, do not block

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double stop_distance = strategy_stop_atr_mult * atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;                              // genuinely wide spread — block
   return false;                                // zero/normal modeled spread — pass
  }

// D1 entry. Caller guarantees QM_IsNewBar()==true (one call per closed D1 bar).
// PCA s-score is advanced in OnTick before this call (g_s_score / g_ready / g_kappa).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(!g_ready)
      return false;

   // OU speed filter: require fast enough mean reversion.
   if(g_kappa < strategy_k_min)
      return false;

   int dir = 0;
   // Long the residual when it is depressed (s very negative); short when elevated.
   if(g_s_score < -strategy_sbo) dir = +1;
   if(g_s_score >  strategy_sso) dir = -1;
   if(dir == 0)
      return false;

   const QM_OrderType ot = (dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Emergency MT5 stop only (primary exit is the s-score close / protective level).
   const double sl = QM_StopATR(_Symbol, ot, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = ot;
   req.price  = 0.0;        // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;        // no fixed TP — exit on s-score reversion
   req.reason = (dir > 0) ? "pca_sscore_long" : "pca_sscore_short";

   g_bars_in_trade = 0;     // reset hold counter on fresh entry
   return true;
  }

// No active trade management beyond the static emergency ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// s-score mean-reversion close, protective extreme-s stop, time stop, OU-speed
// revalidation failure. Uses the s-score cached this D1 bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   int pos_dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      pos_dir = (ptype == POSITION_TYPE_BUY) ? +1 : -1;
      break;
     }
   if(pos_dir == 0)
      return false;

   // Time stop (advanced once per new D1 bar in OnTick).
   if(g_bars_in_trade >= strategy_time_stop_bars)
      return true;

   if(!g_ready)
      return false;

   // Protective stop on extreme s-score (residual diverging hard).
   if(MathAbs(g_s_score) >= strategy_s_protect)
      return true;

   // OU-speed revalidation: if mean reversion has decayed below floor, exit flat.
   if(g_kappa < strategy_k_min)
      return true;

   // Mean-reversion close thresholds.
   if(pos_dir > 0 && g_s_score >= -strategy_sbc) return true;   // long closes as s recovers
   if(pos_dir < 0 && g_s_score <=  strategy_ssc) return true;   // short closes as s recovers
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

   // Locate host within the fixed PCA universe.
   g_host_idx = -1;
   for(int i = 0; i < QM_UNIV; ++i)
      if(g_univ[i] == _Symbol)
        { g_host_idx = i; break; }

   // BASKET-warm the full universe's D1 history so foreign-symbol reads return
   // real tester data (else 0 trades). Warm corr_window + slack.
   string universe[];
   ArrayResize(universe, QM_UNIV);
   for(int i = 0; i < QM_UNIV; ++i) universe[i] = g_univ[i];
   QM_SymbolGuardInit(universe);
   int warm = strategy_corr_window + 8;
   if(warm > QM_MAXWIN + 8) warm = QM_MAXWIN + 8;
   QM_BasketWarmupHistory(universe, PERIOD_D1, warm);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"universe\":%d,\"host\":\"%s\",\"host_idx\":%d}",
                            QM_UNIV, _Symbol, g_host_idx));
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

   // Latch the closed-bar event ONCE (single-consume). On a fresh D1 bar, refresh
   // the PCA s-score BEFORE the rule-based exit so exit sees the current score,
   // and advance the in-trade bar counter.
   const bool nb = QM_IsNewBar();
   if(nb)
     {
      QM_AdvancePCA();
      const int magic = QM_FrameworkMagic();
      if(QM_TM_OpenPositionCount(magic) > 0)
         ++g_bars_in_trade;
      else
         g_bars_in_trade = 0;
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
