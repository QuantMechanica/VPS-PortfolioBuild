#property strict
#property version   "5.0"
#property description "QM5_11256 ht-pearson-div — Pearson return-divergence cross-sectional rank basket (D1, monthly proxy)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11256 ht-pearson-div
// -----------------------------------------------------------------------------
// Source: Hudson & Thames, "Pearson Distance Approach", Arbitrage Research
// notebook (source_id af021dd0-e07d-5f72-9933-de7a3533934e); primary reference
// Chen et al., "Empirical Investigation of an Equity Pairs Trading Strategy".
// Card: artifacts/cards_approved/QM5_11256_ht-pearson-div.md (g0 APPROVED).
//
// PEARSON RETURN-DIVERGENCE CROSS-SECTIONAL RANK BASKET (BASKET EA). The strategy
// ranks a fixed cohort of correlated .DWX symbols by a return-divergence score and
// then goes LONG the top bucket / SHORT the bottom bucket, rebalancing once per
// "month". The source is a MONTHLY rebalance strategy; the .DWX tester yields 0
// bars on MN1, so this EA is D1-NATIVE with a deterministic 21-D1-bar/month proxy
// (HR / DWX-invariant #10). All math is closed-bar, bounded, deterministic — no ML,
// no external feed, no library.
//
// ONE INSTANCE PER SYMBOL. Each registered symbol runs as its own framework host
// on _Symbol at its own magic slot (one position per magic/symbol). The cohort is
// shared: every instance warms + reads ALL cohort symbols' D1 closes to compute the
// SAME cross-sectional ranking, then acts only on whether _Symbol sits in the long
// or short bucket. This is the "basket" — a long/short cohort portfolio assembled
// from independent single-symbol hosts, exactly as one position-per-magic requires.
// No QM_BasketOpenPosition foreign leg is needed because each host trades only its
// own symbol; the cross-symbol dependency is in the SIGNAL (the cohort ranking),
// which is why the full cohort is warmed in OnInit.
//
// PER-"MONTH" MECHANICS (computed on the closed D1 bar that opens a new month proxy
// block, i.e. once every `bars_per_month` D1 bars):
//   1. Build the monthly-return series for each cohort symbol from D1 closes,
//      sampling one return every `bars_per_month` bars over `formation_months`
//      blocks (baseline 24 months => 24*21 D1 bars of history).
//   2. For the TARGET (=_Symbol): pick the `partner_count` cohort symbols with the
//      highest Pearson correlation of monthly returns to the target, requiring
//      corr > 0 and corr >= min_partner_corr. Equal-weight them into a partner
//      portfolio monthly-return series.
//   3. OLS-regress target monthly return on partner-portfolio monthly return to get
//      beta (no intercept term in the divergence; Rf = 0 for FX/CFD per card).
//   4. Divergence of the LAST completed month:
//         D_target = beta*(R_target_last - Rf) - (R_partner_portfolio_last - Rf).
//   5. Compute the SAME divergence for EVERY cohort symbol (each vs its own best
//      partners), then cross-sectionally RANK. Long if _Symbol is in the top
//      `long_pct`; short if in the bottom `short_pct`; flat otherwise.
//
// EXIT. Hold until the next monthly rebalance. At each rebalance, if _Symbol leaves
// its long/short bucket (or the cohort is too thin), the position is closed. A
// safety time stop closes after `time_stop_months` month-proxy blocks. Reversal
// only after the old position is flat (one position per magic — the framework path
// enforces this; we close-then-reopen across rebalances, never pyramid).
//
// FILTERS (card). Require >= min_months monthly observations; require >= 4 eligible
// cohort symbols at the rebalance, else skip the month; require selected partner
// correlations positive and >= min_partner_corr; Rf = 0; recompute only at a month
// boundary. Spread guard is FAIL-OPEN (.DWX quotes ask==bid => never block on 0).
//
// COHORT (all REAL .DWX symbols in dwx_symbol_matrix.csv — no port needed), to be
// registered in magic_numbers.csv by the central step:
//   slot 0 EURUSD.DWX  slot 1 GBPUSD.DWX  slot 2 AUDUSD.DWX
//   slot 3 NZDUSD.DWX  slot 4 NDX.DWX     slot 5 WS30.DWX
// A setfile binds qm_magic_slot_offset = the slot of the symbol the instance runs
// on (must match _Symbol). The cohort list below is fixed across all instances.
//
// Only the five Strategy_* hooks + OnInit cohort warmup are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11256;
input int    qm_magic_slot_offset       = 0;     // slot of THIS instance's _Symbol
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
// Cross-sectional return-divergence rank parameters (card "Parameters To Test").
input int    strategy_formation_months  = 24;    // formation window in month-proxy blocks (P3 {12,24,36})
input int    strategy_partner_count     = 3;     // # most-correlated partners (P3 {2,3,4})
input double strategy_long_pct          = 0.25;  // top fraction of cohort to long (P3 {0.20,0.25,0.33})
input double strategy_short_pct         = 0.25;  // bottom fraction of cohort to short (P3 {0.20,0.25,0.33})
input double strategy_min_partner_corr  = 0.25;  // min positive Pearson corr to qualify a partner (P3 {0.15,0.25,0.35})
input int    strategy_bars_per_month    = 21;    // D1 bars per month proxy (252/yr) — DWX-invariant #10
input int    strategy_min_months        = 12;    // min monthly observations required (card filter)
input int    strategy_min_cohort        = 4;     // skip rebalance if fewer eligible cohort symbols
input int    strategy_time_stop_months  = 1;     // safety time stop in month blocks (source = monthly)

// -----------------------------------------------------------------------------
// Fixed cohort. Index = magic symbol_slot. All REAL .DWX matrix symbols.
// -----------------------------------------------------------------------------
#define QM_COHORT_N 6
string g_cohort[QM_COHORT_N];

// -----------------------------------------------------------------------------
// File-scope cached state, advanced once per month-proxy boundary.
// -----------------------------------------------------------------------------
int    g_self_idx          = -1;    // index of _Symbol inside g_cohort
int    g_last_month_block  = -1;    // month-proxy block index of last rebalance compute
int    g_target_dir        = 0;     // +1 long bucket, -1 short bucket, 0 flat (this _Symbol)
bool   g_signal_ready      = false; // cohort/divergence computed cleanly this rebalance
int    g_pos_entry_block   = -1;    // month-block index when current position opened

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Current month-proxy block index, derived deterministically from the bar-open time
// of the last CLOSED D1 bar. block = floor(barsSinceEpoch / bars_per_month). We key
// off the closed-bar count from a fixed anchor so the boundary is bar-aligned, not
// wall-clock. Uses Bars() from a fixed early anchor date on _Symbol.
int QM_MonthBlockIndex()
  {
   const int total = Bars(_Symbol, PERIOD_D1);   // perf-allowed: bar-count for month-block index
   if(total <= 1)
      return -1;
   // Index of the last CLOSED bar within the available history (shift 1 = newest closed).
   // (total-1) closed bars exist; block boundaries every bars_per_month closed bars.
   const int closed_count = total - 1;
   if(strategy_bars_per_month <= 0)
      return -1;
   return closed_count / strategy_bars_per_month;
  }

// Fill `ret[]` with `months` monthly returns for `sym`, newest first (ret[0] = most
// recent completed month). Monthly return = close[k*bpm+1]/close[(k+1)*bpm+1]-1 on
// closed D1 bars (shift>=1). Returns false on any missing/degenerate bar.
bool QM_MonthlyReturns(const string sym, const int months, const int bpm, double &ret[])
  {
   ArrayResize(ret, months);
   const int need_bars = (months + 1) * bpm + 2;
   if(Bars(sym, PERIOD_D1) < need_bars)              // perf-allowed: history-availability check
      return false;
   for(int k = 0; k < months; ++k)
     {
      // perf-allowed: closed-bar monthly-sample closes; computed once per month boundary.
      const double c_new = iClose(sym, PERIOD_D1, k * bpm + 1);        // perf-allowed: month-sample close (newer)
      const double c_old = iClose(sym, PERIOD_D1, (k + 1) * bpm + 1);  // perf-allowed: month-sample close (older)
      if(c_new <= 0.0 || c_old <= 0.0)
         return false;
      ret[k] = c_new / c_old - 1.0;
     }
   return true;
  }

// Pearson correlation of two equal-length series. Returns 0 on degenerate variance.
double QM_Pearson(const double &a[], const double &b[], const int n)
  {
   if(n < 2)
      return 0.0;
   double sa = 0.0, sb = 0.0;
   for(int i = 0; i < n; ++i) { sa += a[i]; sb += b[i]; }
   const double ma = sa / n, mb = sb / n;
   double sab = 0.0, saa = 0.0, sbb = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double da = a[i] - ma, db = b[i] - mb;
      sab += da * db; saa += da * da; sbb += db * db;
     }
   const double den = MathSqrt(saa * sbb);
   if(den <= 1e-15)
      return 0.0;
   return sab / den;
  }

// Divergence score for cohort target `ti` over the cohort monthly-return matrix
// `mret` (rows = cohort symbol, cols = months, newest first). Selects up to
// partner_count partners with the highest positive Pearson corr (>= min_corr),
// equal-weights them, OLS-regresses target on the partner portfolio for beta, and
// returns D = beta*R_target_last - R_partner_last (Rf=0). `ok` is false if fewer
// than one qualifying partner exists.
double QM_DivergenceScore(const double &mret[], const int rows, const int cols,
                          const int ti, const int partner_count,
                          const double min_corr, bool &ok)
  {
   ok = false;
   if(cols < 2 || ti < 0 || ti >= rows)
      return 0.0;

   double tgt[];   ArrayResize(tgt, cols);
   for(int c = 0; c < cols; ++c)
      tgt[c] = mret[ti * cols + c];

   // Correlation of every other cohort symbol vs target.
   double  corr[QM_COHORT_N];
   for(int r = 0; r < rows; ++r)
     {
      if(r == ti) { corr[r] = -2.0; continue; }
      double cand[];  ArrayResize(cand, cols);
      for(int c = 0; c < cols; ++c)
         cand[c] = mret[r * cols + c];
      corr[r] = QM_Pearson(tgt, cand, cols);
     }

   // Select up to partner_count partners with highest corr, gated by >0 and min_corr.
   int    sel[QM_COHORT_N];
   int    nsel = 0;
   bool   used[QM_COHORT_N];
   for(int r = 0; r < rows; ++r) used[r] = false;
   for(int p = 0; p < partner_count; ++p)
     {
      int    best = -1;
      double bestc = -2.0;
      for(int r = 0; r < rows; ++r)
        {
         if(used[r] || r == ti) continue;
         if(corr[r] > bestc) { bestc = corr[r]; best = r; }
        }
      if(best < 0) break;
      if(bestc <= 0.0 || bestc < min_corr) break;   // partners must be positive + >= min_corr
      used[best] = true;
      sel[nsel++] = best;
     }
   if(nsel < 1)
      return 0.0;   // ok stays false -> target not eligible this month

   // Equal-weight partner-portfolio monthly returns.
   double pp[];  ArrayResize(pp, cols);
   for(int c = 0; c < cols; ++c)
     {
      double s = 0.0;
      for(int j = 0; j < nsel; ++j)
         s += mret[sel[j] * cols + c];
      pp[c] = s / nsel;
     }

   // OLS beta of target on partner-portfolio (slope through covariance/variance).
   double sx = 0.0, sy = 0.0;
   for(int c = 0; c < cols; ++c) { sx += pp[c]; sy += tgt[c]; }
   const double mx = sx / cols, my = sy / cols;
   double cov = 0.0, varx = 0.0;
   for(int c = 0; c < cols; ++c)
     {
      const double dx = pp[c] - mx;
      cov  += dx * (tgt[c] - my);
      varx += dx * dx;
     }
   if(varx <= 1e-15)
      return 0.0;   // degenerate regressor -> not eligible
   const double beta = cov / varx;

   // Divergence of the most recent completed month (index 0 = newest), Rf = 0.
   const double d = beta * tgt[0] - pp[0];
   ok = true;
   return d;
  }

// Recompute the cross-sectional divergence ranking for the whole cohort and set the
// cached long/short bucket flag for THIS _Symbol. Called once per month boundary.
void QM_AdvanceRankState()
  {
   g_signal_ready = false;
   g_target_dir   = 0;

   if(g_self_idx < 0)
      return;
   if(strategy_formation_months < strategy_min_months)
      return;

   const int cols = strategy_formation_months;

   // Build the cohort monthly-return matrix; track which symbols have full data.
   double mret[];  ArrayResize(mret, QM_COHORT_N * cols);
   bool   have[QM_COHORT_N];
   int    eligible = 0;
   for(int r = 0; r < QM_COHORT_N; ++r)
     {
      double rr[];
      have[r] = QM_MonthlyReturns(g_cohort[r], cols, strategy_bars_per_month, rr);
      if(have[r])
        {
         for(int c = 0; c < cols; ++c)
            mret[r * cols + c] = rr[c];
         ++eligible;
        }
      else
        {
         for(int c = 0; c < cols; ++c)
            mret[r * cols + c] = 0.0;
        }
     }

   // Card filter: skip the month if fewer than min_cohort eligible symbols, or this
   // symbol itself lacks data.
   if(eligible < strategy_min_cohort || !have[g_self_idx])
      return;

   // Divergence score for each eligible cohort symbol.
   double score[QM_COHORT_N];
   bool   scored[QM_COHORT_N];
   int    nscored = 0;
   for(int r = 0; r < QM_COHORT_N; ++r)
     {
      scored[r] = false;
      score[r]  = 0.0;
      if(!have[r]) continue;
      bool ok = false;
      const double d = QM_DivergenceScore(mret, QM_COHORT_N, cols, r,
                                          strategy_partner_count,
                                          strategy_min_partner_corr, ok);
      if(ok) { score[r] = d; scored[r] = true; ++nscored; }
     }

   if(nscored < strategy_min_cohort || !scored[g_self_idx])
      return;

   // Cross-sectional rank: how many scored symbols have a STRICTLY higher score than
   // this _Symbol (rank 0 = highest divergence). Long the top long_pct, short the
   // bottom short_pct of the scored set.
   const double self_score = score[g_self_idx];
   int higher = 0;     // strictly greater
   int equal_before = 0; // ties with lower cohort index (stable ordering)
   for(int r = 0; r < QM_COHORT_N; ++r)
     {
      if(!scored[r] || r == g_self_idx) continue;
      if(score[r] > self_score) ++higher;
      else if(score[r] == self_score && r < g_self_idx) ++equal_before;
     }
   const int rank = higher + equal_before;   // 0-based rank among scored set

   int long_cut = (int)MathFloor((double)nscored * strategy_long_pct + 1e-9);
   if(long_cut < 1) long_cut = 1;
   int short_cut = (int)MathFloor((double)nscored * strategy_short_pct + 1e-9);
   if(short_cut < 1) short_cut = 1;
   if(long_cut + short_cut > nscored)         // avoid overlap on tiny cohorts
     {
      long_cut  = nscored / 2;
      short_cut = nscored - long_cut - (nscored % 2 == 0 ? 0 : 0);
      if(long_cut < 1) long_cut = 1;
      if(short_cut < 1) short_cut = 1;
     }

   // High divergence => target over-performed its partners => expected to REVERT down
   // next month (source hypothesis) => SHORT the top divergence, LONG the bottom.
   if(rank < short_cut)
      g_target_dir = -1;                       // top divergence bucket -> short
   else if(rank >= nscored - long_cut)
      g_target_dir = +1;                       // bottom divergence bucket -> long
   else
      g_target_dir = 0;

   g_signal_ready = true;
  }

// Open count + direction for THIS instance's host leg (one position per magic/symbol).
int QM_HostDir()
  {
   const int magic = QM_FrameworkMagic();
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

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick filter. FAIL-OPEN spread guard (.DWX quotes ask==bid => 0
// spread must never block). Only a genuinely pathological wide spread blocks.
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

// Entry on a fresh month-proxy boundary: open the host leg if _Symbol is in the
// long or short bucket and no position is currently held. Caller guarantees
// QM_IsNewBar()==true; the month-boundary gate is applied in OnTick before this.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_HostDir() != 0)                 // one position per magic/symbol
      return false;
   if(!g_signal_ready || g_target_dir == 0)
      return false;

   req.type        = (g_target_dir > 0) ? QM_BUY : QM_SELL;
   req.price       = 0.0;                // framework fills market price at send
   req.sl          = 0.0;                // basket-level rule exits manage the position
   req.tp          = 0.0;
   req.reason      = (g_target_dir > 0) ? "pdiv_long_bucket" : "pdiv_short_bucket";
   req.symbol_slot = qm_magic_slot_offset;
   g_pos_entry_block = g_last_month_block;
   return true;
  }

// No active per-position trade management; rebalance exits are rule-based.
void Strategy_ManageOpenPosition()
  {
  }

// Rebalance exit: close when _Symbol leaves its long/short bucket, when the cohort
// is too thin to score this month, or after the time-stop month budget. Returning
// true triggers the framework host-leg close loop in OnTick.
bool Strategy_ExitSignal()
  {
   const int dir = QM_HostDir();
   if(dir == 0)
      return false;

   // Time stop in month-proxy blocks (source strategy is monthly).
   if(g_pos_entry_block >= 0 && strategy_time_stop_months > 0)
     {
      const int held_blocks = g_last_month_block - g_pos_entry_block;
      if(held_blocks >= strategy_time_stop_months)
         return true;
     }

   // Bucket exit: only re-evaluate on a clean rebalance. If the signal could not be
   // computed this month, hold (do not churn on transient data gaps).
   if(g_signal_ready)
     {
      if(g_target_dir == 0)              // left both buckets
         return true;
      if(g_target_dir != dir)            // flipped bucket -> close first (no pyramiding)
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

   // Fixed cohort, index = magic symbol_slot.
   g_cohort[0] = "EURUSD.DWX";
   g_cohort[1] = "GBPUSD.DWX";
   g_cohort[2] = "AUDUSD.DWX";
   g_cohort[3] = "NZDUSD.DWX";
   g_cohort[4] = "NDX.DWX";
   g_cohort[5] = "WS30.DWX";

   // Locate _Symbol inside the cohort (the instance trades only its own symbol).
   g_self_idx = -1;
   for(int i = 0; i < QM_COHORT_N; ++i)
      if(g_cohort[i] == _Symbol)
        { g_self_idx = i; break; }

   // BASKET wiring: warm the FULL cohort's D1 history so cross-symbol monthly-return
   // reads return real data in the .DWX tester (else foreign reads return 0 -> 0
   // trades). Guard the cohort universe for foreign-symbol access.
   string universe[];
   ArrayResize(universe, QM_COHORT_N);
   for(int i = 0; i < QM_COHORT_N; ++i)
      universe[i] = g_cohort[i];
   QM_SymbolGuardInit(universe);
   const int warm_bars = (strategy_formation_months + 2) * strategy_bars_per_month + 60;
   QM_BasketWarmupHistory(universe, PERIOD_D1, warm_bars);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"symbol\":\"%s\",\"self_idx\":%d,\"slot\":%d,\"formation_months\":%d,\"bpm\":%d,\"partners\":%d}",
                            _Symbol, g_self_idx, qm_magic_slot_offset,
                            strategy_formation_months, strategy_bars_per_month,
                            strategy_partner_count));
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

   // Single-consume the closed-bar event ONCE and reuse it. On a fresh D1 bar that
   // CROSSES a month-proxy boundary, recompute the cross-sectional rank BEFORE the
   // rule-based exit so the exit sees the current bucket assignment.
   const bool nb = QM_IsNewBar();
   bool month_boundary = false;
   if(nb)
     {
      const int blk = QM_MonthBlockIndex();
      if(blk >= 0 && blk != g_last_month_block)
        {
         g_last_month_block = blk;
         month_boundary = true;
         QM_AdvanceRankState();
        }
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
      g_pos_entry_block = -1;
     }

   if(!nb)
      return;

   QM_EquityStreamOnNewBar();

   // Entries only on a month-proxy boundary (monthly rebalance cadence).
   if(!month_boundary)
      return;

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
