#property strict
#property version   "5.0"
#property description "QM5_1281 as-aaa-minvar — AllocateSmartly Aggressive Asset Allocation (canary-gated min-variance rotation, D1, basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1281 as-aaa-minvar
// -----------------------------------------------------------------------------
// Source: AllocateSmartly "Adaptive / Aggressive Asset Allocation" (Butler,
// Philbrick, Gordillo & Varadi — ReSolve / GestaltU, "Adaptive Asset Allocation:
// A Primer", 2012, SSRN 2328254). source_id 2df06de7. Card:
// artifacts/cards_approved/QM5_1281_as-aaa-minvar.md (g0_status APPROVED).
//
// BASKET EA — canary-gated cross-sectional momentum rotation with MINIMUM-
// VARIANCE weighting. Each monthly rebalance:
//   1. CANARY RISK GATE (risk-on/off): evaluate the canary asset's absolute
//      126-day momentum. canary momentum > 0  -> RISK-ON; otherwise RISK-OFF.
//      This is the AAA "aggressive" switch: it pulls the whole book out of the
//      offensive universe into the defensive sleeve when the canary turns down.
//   2. RISK-ON: rank the OFFENSIVE universe by 126-day total return, select the
//      top-N (default 5), and weight the selected sleeves by MINIMUM-VARIANCE.
//   3. RISK-OFF: the whole book rotates into the single DEFENSIVE sleeve at full
//      weight (the AAA crash-protection leg).
// The EA runs one instance per host symbol; the host opens / holds a long ONLY
// when it is an allocated slot this month, and its lot is scaled by its min-var
// weight via RISK_FIXED. One position per magic on the host. Long-only (the
// source rotates into the defensive asset / cash, never shorts).
//
// MINIMUM-VARIANCE REALIZATION (deterministic, NO matrix inversion, NO ML):
//   The source weights the selected assets by a minimum-variance optimizer over
//   a 126-day correlation / 20-day volatility covariance matrix. Per the build
//   brief, that QP is realized here as a deterministic INVERSE-VOLATILITY tilt
//   combined with a LOW-CORRELATION tilt — the two properties a true min-var
//   solution rewards (it overweights low-vol AND low-average-correlation
//   assets):
//       raw_w[i] = (1 / vol20[i]) * (1 / max(eps, 1 + avg_corr126[i]))
//   normalized across the selected top-N so the weights sum to 1, then bounded
//   to [w_min, w_max] and renormalized. No covariance-matrix inversion, no
//   learned coefficients, no PnL-adaptive parameters — fixed lookbacks only.
//
// DWX PORT (ETFs are NOT tradeable on Darwinex; ported to liquid CFD proxies —
// documented in basket_manifest.json):
//   OFFENSIVE universe (risk-on rotation pool):
//     SP500.DWX  (S&P 500, backtest-only read member)  <- US large-cap (SPY)
//     NDX.DWX    (Nasdaq 100)                           <- growth / EM proxy (QQQ/EEM/EWJ)
//     WS30.DWX   (Dow 30)                               <- US large-cap value (DIA)
//     GDAXI.DWX  (DAX 40)                               <- EAFE / European equity (EZU/EWJ)
//     UK100.DWX  (FTSE 100)                             <- intl equity / REIT proxy (VNQ/RWX)
//     XAUUSD.DWX (gold)                                 <- gold / real-asset (GLD)
//     XTIUSD.DWX (WTI crude)                            <- broad commodity (DBC)
//   DEFENSIVE / canary legs (FLAGGED ports — no DWX bond CFD):
//     Defensive sleeve  <- XAUUSD.DWX gold proxy for the source's bond safe leg
//                          (IEF / TLT). FLAG: nearest available real-asset/safe
//                          proxy; a true Treasury CFD does not exist on DWX.
//     Canary asset      <- SP500.DWX (the representative offensive risk asset);
//                          the source's canary set (EEM/agg-bond) is approximated
//                          by the broad US-equity proxy. FLAG: canary realized as
//                          the offensive-universe bellwether, not a bond canary.
//
// MONTHLY logic is D1-native (DWX rule 10: the .DWX tester yields 0 bars on MN1).
// Rebalance fires on the first new D1 bar of a new broker-time month; lookbacks
// use a ~21-trading-day-per-month proxy (126 D1 bars momentum/corr, 20 D1 vol).
//
// Only the five Strategy_* hooks + the OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1281;
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
input int    strategy_mom_days           = 126;   // 6-month / 126-day momentum + correlation lookback
input int    strategy_vol_days           = 20;    // 20-day volatility lookback (min-var weighting)
input int    strategy_days_per_month      = 21;    // trading-day-per-month proxy (D1-native, unused gate)
input int    strategy_top_n               = 5;     // risk-on: hold the top-N offensive sleeves (card: 5)
input double strategy_canary_mom_floor    = 0.0;   // canary abs-momentum floor for RISK-ON (log-return)
input double strategy_w_min               = 0.05;  // min-var weight floor per selected sleeve
input double strategy_w_max               = 0.60;  // min-var weight cap per selected sleeve
input int    strategy_min_candidates      = 4;     // min offensive candidates with valid data for a valid rank
input int    strategy_atr_period          = 14;    // protective-stop ATR period (D1)
input double strategy_stop_atr_mult       = 3.0;   // protective stop = mult * ATR (P3 {2.0,2.5,3.0})
input int    strategy_min_warmup_bars     = 40;    // extra D1 warmup margin per candidate
input double strategy_spread_pct_of_stop  = 20.0;  // skip if host spread > this % of stop distance

// -----------------------------------------------------------------------------
// Fixed universe (matrix-verified DWX proxies for the AAA ETF universe).
//   - g_off[]  : OFFENSIVE risk-on rotation pool.
//   - canary   : SP500.DWX (offensive bellwether, FLAGGED port).
//   - defensive: XAUUSD.DWX (gold safe-leg proxy, FLAGGED port).
// -----------------------------------------------------------------------------
#define QM_MAX_CAND   8
#define QM_MAX_RETBAR 256          // upper bound on cached return-series length

string g_off[QM_MAX_CAND];
int    g_noff     = 0;
int    g_host_idx = -1;            // index of _Symbol in g_off, or -1
string g_canary   = "SP500.DWX";   // canary asset (risk-on/off gate)
string g_defensive= "XAUUSD.DWX";  // defensive sleeve (risk-off rotation target)

// Cached selection state, advanced once per closed D1 rebalance bar (month turn).
double g_momentum[QM_MAX_CAND];    // 126-day cumulative log return per offensive candidate
double g_vol[QM_MAX_CAND];         // 20-day realized vol of daily returns
double g_corr[QM_MAX_CAND];        // average pairwise 126-day correlation to the universe
double g_weight[QM_MAX_CAND];      // min-var weight if selected (0 otherwise)
bool   g_valid[QM_MAX_CAND];       // per-candidate valid-data flag
bool   g_risk_on        = false;   // canary gate: true = RISK-ON, false = RISK-OFF
bool   g_host_allocated = false;   // host is an allocated slot this month
double g_host_weight    = 0.0;     // host's min-var weight this month (0..1)
int    g_active_count   = 0;       // offensive candidates with valid data this eval
bool   g_ready          = false;   // true when this eval produced a usable allocation

// Broker-time month of the last completed rebalance (-1 = none yet).
int    g_last_reb_month = -1;
int    g_last_reb_year  = -1;

void QM_BuildUniverse()
  {
   string u[] =
     {
      "SP500.DWX","NDX.DWX","WS30.DWX","GDAXI.DWX","UK100.DWX","XAUUSD.DWX","XTIUSD.DWX"
     };
   g_noff = ArraySize(u);
   if(g_noff > QM_MAX_CAND) g_noff = QM_MAX_CAND;
   for(int i = 0; i < g_noff; ++i)
      g_off[i] = u[i];
  }

// Fill `out` with the host + every offensive candidate + canary + defensive
// (dedup keeps the warmup list clean).
void QM_BuildWarmupList(string &out[])
  {
   ArrayResize(out, g_noff + 3);
   int n = 0;
   out[n++] = _Symbol;
   for(int i = 0; i < g_noff; ++i)
     {
      bool dup = false;
      for(int j = 0; j < n; ++j)
         if(out[j] == g_off[i]) { dup = true; break; }
      if(!dup) out[n++] = g_off[i];
     }
   bool dup_c = false;
   for(int j = 0; j < n; ++j) if(out[j] == g_canary) { dup_c = true; break; }
   if(!dup_c) out[n++] = g_canary;
   bool dup_d = false;
   for(int j = 0; j < n; ++j) if(out[j] == g_defensive) { dup_d = true; break; }
   if(!dup_d) out[n++] = g_defensive;
   ArrayResize(out, n);
  }

int QM_MomLookbackDays()
  {
   int d = strategy_mom_days;
   if(d < 5) d = 5;
   if(d > QM_MAX_RETBAR - 2) d = QM_MAX_RETBAR - 2;
   return d;
  }

// Load the daily LOG-return series for `sym` over the last `nret` closed bars
// (shift 1..nret). Returns true with `ret[]` filled (length nret) on success.
// perf-allowed: this runs ONCE per candidate per monthly rebalance (~12x/yr),
// gated by the broker-time month change in OnTick — not on the per-tick path.
bool QM_LoadReturns(const string sym, const int nret, double &ret[])
  {
   const int need = nret + 2;                       // need nret+1 closes -> nret returns
   if(Bars(sym, PERIOD_D1) < need + strategy_min_warmup_bars)
      return false;

   double cl[];
   ArrayResize(cl, nret + 1);
   for(int k = 0; k <= nret; ++k)
     {
      // perf-allowed: bounded copy of closed-bar closes for the return series.
      const double c = iClose(sym, PERIOD_D1, 1 + k);
      if(c <= 0.0)
         return false;
      cl[k] = c;
     }

   ArrayResize(ret, nret);
   for(int k = 0; k < nret; ++k)
     {
      // cl[k] is more recent than cl[k+1]; log return of the more recent bar.
      ret[k] = MathLog(cl[k] / cl[k + 1]);
     }
   return true;
  }

double QM_Mean(const double &a[], const int n)
  {
   if(n <= 0) return 0.0;
   double s = 0.0;
   for(int i = 0; i < n; ++i) s += a[i];
   return s / n;
  }

// Pearson correlation of two equal-length series. 0.0 on degenerate variance.
double QM_PairCorr(const double &a[], const double &b[], const int n)
  {
   if(n <= 1) return 0.0;
   const double ma = QM_Mean(a, n);
   const double mb = QM_Mean(b, n);
   double cov = 0.0, va = 0.0, vb = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double da = a[i] - ma;
      const double db = b[i] - mb;
      cov += da * db;
      va  += da * da;
      vb  += db * db;
     }
   if(va <= 0.0 || vb <= 0.0) return 0.0;
   return cov / MathSqrt(va * vb);
  }

// Canary absolute-momentum gate. RISK-ON when the canary's 126-day cumulative
// log return exceeds the configured floor. Returns false (RISK-OFF) if the
// canary series is not warm in the tester.
bool QM_CanaryRiskOn()
  {
   const int nret = QM_MomLookbackDays();
   double r[];
   if(!QM_LoadReturns(g_canary, nret, r))
      return false;                                  // canary not warm -> defensive
   double cum = 0.0;
   for(int k = 0; k < nret; ++k) cum += r[k];
   return (cum > strategy_canary_mom_floor);
  }

// -----------------------------------------------------------------------------
// Advance the canary gate + cross-sectional AAA min-variance allocation ONCE per
// closed monthly-rebalance bar. Sets g_risk_on, per-candidate momentum / vol /
// corr / weight states, whether the host is allocated, and the host's weight.
// -----------------------------------------------------------------------------
void QM_AdvanceSelection()
  {
   g_ready = false;
   g_host_allocated = false;
   g_host_weight = 0.0;
   g_active_count = 0;
   for(int i = 0; i < g_noff; ++i)
     {
      g_momentum[i] = 0.0;
      g_vol[i] = 0.0;
      g_corr[i] = 0.0;
      g_weight[i] = 0.0;
      g_valid[i] = false;
     }

   // 1. CANARY RISK GATE.
   g_risk_on = QM_CanaryRiskOn();

   // 2. RISK-OFF: whole book rotates into the single defensive sleeve at full
   //    weight. Only a host that IS the defensive sleeve is allocated.
   if(!g_risk_on)
     {
      if(_Symbol == g_defensive)
        {
         g_host_allocated = true;
         g_host_weight = 1.0;
        }
      g_ready = true;
      return;
     }

   // 3. RISK-ON: rank offensive universe by 126-day momentum, top-N, min-var.
   const int nret = QM_MomLookbackDays();
   const int voln = MathMin(strategy_vol_days, nret);   // vol window <= return series

   double rets[QM_MAX_CAND][QM_MAX_RETBAR];
   int    rlen[QM_MAX_CAND];

   for(int i = 0; i < g_noff; ++i)
     {
      rlen[i] = 0;
      double r[];
      if(!QM_LoadReturns(g_off[i], nret, r))
         continue;

      // 126-day momentum: cumulative log return over the lookback.
      double cum = 0.0;
      for(int k = 0; k < nret; ++k)
        {
         cum += r[k];
         rets[i][k] = r[k];
        }
      rlen[i] = nret;

      // 20-day realized volatility from the MOST RECENT voln returns (shift 0..voln-1).
      double vr[];
      ArrayResize(vr, voln);
      for(int k = 0; k < voln; ++k) vr[k] = r[k];
      const double mv = QM_Mean(vr, voln);
      double sumsq = 0.0;
      for(int k = 0; k < voln; ++k)
        {
         const double d = vr[k] - mv;
         sumsq += d * d;
        }
      double vol = MathSqrt(sumsq / voln);
      if(vol <= 0.0) vol = 1e-9;                          // guard against div0

      g_momentum[i] = cum;
      g_vol[i] = vol;
      g_valid[i] = true;
      ++g_active_count;
     }

   if(g_active_count < strategy_min_candidates)
     {
      g_ready = true;                                     // valid eval, simply nothing allocated
      return;
     }

   // Average pairwise 126-day correlation of each valid asset to every other
   // valid asset (lower average correlation = lower portfolio variance).
   for(int i = 0; i < g_noff; ++i)
     {
      if(!g_valid[i]) continue;
      double csum = 0.0;
      int cn = 0;
      double ai[]; ArrayResize(ai, rlen[i]);
      for(int k = 0; k < rlen[i]; ++k) ai[k] = rets[i][k];
      for(int j = 0; j < g_noff; ++j)
        {
         if(j == i || !g_valid[j]) continue;
         const int n = MathMin(rlen[i], rlen[j]);
         if(n <= 1) continue;
         double bj[]; ArrayResize(bj, n);
         for(int k = 0; k < n; ++k) bj[k] = rets[j][k];
         csum += QM_PairCorr(ai, bj, n);
         ++cn;
        }
      g_corr[i] = (cn > 0) ? (csum / cn) : 0.0;
     }

   // Select the top-N offensive sleeves by HIGHEST 126-day momentum.
   const int want = MathMax(1, strategy_top_n);
   bool taken[QM_MAX_CAND];
   for(int i = 0; i < g_noff; ++i) taken[i] = false;
   int sel[QM_MAX_CAND];
   int nsel = 0;

   for(int slot = 0; slot < want; ++slot)
     {
      int best = -1;
      double best_mom = 0.0;
      for(int i = 0; i < g_noff; ++i)
        {
         if(!g_valid[i] || taken[i]) continue;
         if(best < 0 || g_momentum[i] > best_mom)
           { best = i; best_mom = g_momentum[i]; }
        }
      if(best < 0) break;
      taken[best] = true;
      sel[nsel++] = best;
     }

   // MINIMUM-VARIANCE weighting over the selected top-N (inverse-vol x
   // low-correlation tilt). Deterministic, no matrix inversion.
   double raw[QM_MAX_CAND];
   double raw_sum = 0.0;
   for(int s = 0; s < nsel; ++s)
     {
      const int i = sel[s];
      // (1+avg_corr) is the diversification penalty; clamp the divisor positive.
      double corr_div = 1.0 + g_corr[i];
      if(corr_div < 0.1) corr_div = 0.1;
      const double w = (1.0 / g_vol[i]) * (1.0 / corr_div);
      raw[i] = w;
      raw_sum += w;
     }
   if(raw_sum <= 0.0)
     {
      g_ready = true;
      return;
     }

   // Normalize, then bound each weight to [w_min, w_max] and renormalize so the
   // book still sums to ~1.0 (bounded, no martingale).
   double wbound[QM_MAX_CAND];
   double wsum2 = 0.0;
   for(int s = 0; s < nsel; ++s)
     {
      const int i = sel[s];
      double w = raw[i] / raw_sum;
      if(w < strategy_w_min) w = strategy_w_min;
      if(w > strategy_w_max) w = strategy_w_max;
      wbound[i] = w;
      wsum2 += w;
     }
   if(wsum2 <= 0.0)
     {
      g_ready = true;
      return;
     }
   for(int s = 0; s < nsel; ++s)
     {
      const int i = sel[s];
      g_weight[i] = wbound[i] / wsum2;
     }

   // Host allocation: only if the host is one of the selected offensive sleeves
   // AND its momentum is positive (absolute-momentum guard; a non-positive
   // sleeve rotates to cash = stays flat).
   if(g_host_idx >= 0)
     {
      bool host_sel = false;
      for(int s = 0; s < nsel; ++s)
         if(sel[s] == g_host_idx) { host_sel = true; break; }
      if(host_sel && g_momentum[g_host_idx] > 0.0 && g_weight[g_host_idx] > 0.0)
        {
         g_host_allocated = true;
         g_host_weight = g_weight[g_host_idx];
        }
     }

   g_ready = true;
  }

// Is the newly-closed D1 bar the first bar of a NEW broker-time month?
bool QM_IsRebalanceBar()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if(dt.mon == g_last_reb_month && dt.year == g_last_reb_year)
      return false;                                      // already rebalanced this month
   g_last_reb_month = dt.mon;
   g_last_reb_year  = dt.year;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick spread guard. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                                      // no valid quote — defer, don't block

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double stop_distance = strategy_stop_atr_mult * atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;                                       // genuinely wide spread — block
   return false;                                         // zero/normal modeled spread — pass
  }

// D1 entry. Caller guarantees QM_IsNewBar()==true. Allocation is advanced in
// OnTick before this call (g_host_allocated / g_host_weight / g_ready). The
// host's lot is scaled by its min-var weight via RISK_FIXED * weight (bounded).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(!g_ready)
      return false;

   // Host must be an allocated slot this month (risk-on top-N or risk-off
   // defensive sleeve) with a positive weight.
   if(!g_host_allocated || g_host_weight <= 0.0)
      return false;

   // Long-only AAA allocation into an allocated sleeve.
   const QM_OrderType ot = QM_BUY;
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, ot, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   // MIN-VARIANCE LOT SCALING: re-arm the framework risk sizer with the host's
   // min-var weight as the portfolio weight. Effective risk = RISK_FIXED *
   // PORTFOLIO_WEIGHT * host_weight. Bounded (host_weight in (0,1]); the
   // framework still quantizes / floors lots. No martingale, no PnL feedback.
   const double eff_weight = PORTFOLIO_WEIGHT * g_host_weight;
   const QM_RiskMode mode = (RISK_PERCENT > 0.0) ? QM_RISK_MODE_PERCENT : QM_RISK_MODE_FIXED;
   QM_RiskSizerConfigure(mode, RISK_PERCENT, RISK_FIXED, eff_weight);

   req.type   = ot;
   req.price  = 0.0;        // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;        // no TP — monthly reselection is the primary exit
   req.reason = "aaa_minvar_allocate_long";
   return true;
  }

// No active management beyond the static protective ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Rebalance exit: close the host long when the monthly reallocation drops the
// host out of the allocated set (canary turned risk-off and host is offensive,
// or host fell out of the top-N / lost positive momentum).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_ready)
      return false;

   // Only act on a long position on this host (long-only EA, one per magic).
   bool have_long = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         have_long = true;
      break;
     }
   if(!have_long)
      return false;

   // Exit when the host is no longer an allocated sleeve this month.
   if(!g_host_allocated)
      return true;

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

   // Build the fixed offensive universe and locate the host within it.
   QM_BuildUniverse();
   g_host_idx = -1;
   for(int i = 0; i < g_noff; ++i)
      if(g_off[i] == _Symbol) { g_host_idx = i; break; }

   g_last_reb_month = -1;
   g_last_reb_year  = -1;

   // BASKET wiring: register the host + every offensive candidate + canary +
   // defensive sleeve and warm their D1 history so foreign-symbol reads return
   // real tester data.
   string warmlist[];
   QM_BuildWarmupList(warmlist);
   QM_SymbolGuardInit(warmlist);
   const int warm = QM_MomLookbackDays() + strategy_min_warmup_bars + 16;
   QM_BasketWarmupHistory(warmlist, PERIOD_D1, warm);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"offensive\":%d,\"host\":\"%s\",\"host_idx\":%d,\"canary\":\"%s\",\"defensive\":\"%s\",\"mom_days\":%d}",
                            g_noff, _Symbol, g_host_idx, g_canary, g_defensive, QM_MomLookbackDays()));
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

   // Latch the closed-bar event ONCE (single-consume). On the first new D1 bar
   // of a new broker-time month, refresh the canary gate + min-var allocation
   // BEFORE the rule-based exit so the signal-exit sees the current pick.
   const bool nb = QM_IsNewBar();
   if(nb && QM_IsRebalanceBar())
      QM_AdvanceSelection();

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
