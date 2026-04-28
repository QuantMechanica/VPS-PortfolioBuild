# Strategy Card — Chan AT Kalman-Filter Pair-Spread Mean-Reversion (daily, dynamic state-space hedge ratio + dynamic ±1√Q band)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 3887-4006 (Ex 3.3 verbatim) + lines 3700-3886 (Kalman filter equations 3.5-3.13 framing).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC05_S02
ea_id: TBD
slug: chan-at-kf-pair
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - kalman-filter-mr                          # NEW VOCAB GAP — entry mechanism: state-space estimator (Kalman filter) updates dynamic hedge ratio + dynamic mean + dynamic forecast-error variance; entries triggered by standardized prediction error e(t) crossing ±√Q(t) one-stdev band
  - mean-reach-exit                           # exit when e(t) crosses back to within ±√Q(t) — i.e., spread returns inside its (dynamic) one-σ band around the predicted mean
  - symmetric-long-short                      # both long-spread and short-spread directions deployable
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 3 'Implementing Mean Reversion Strategies', § 'Kalman Filter as Dynamic Linear Regression' + § 'Example 3.3: Kalman Filter Mean Reversion Strategy' (PDF pp. 75-82 / printed pp. 75-82). Box 3.1 documents the Kalman filter equations 3.5-3.13."
    quality_tier: A
    role: primary
  - type: paper
    citation: "Sinclair, Euan (2010). Volatility Trading. Wiley. (Cited by Chan p. 83 for the alternative single-instrument Kalman MR market-maker formulation; outside scope of this card.)"
    location: "Cited via Chan p. 83 — referenced for the single-instrument Kalman application (NOT the pair-spread application of Ex 3.3, which is this card)."
    quality_tier: A
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/ch2_3_pp39-90.txt` + `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 3700-4006. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **Kalman-filter-based mean-reversion strategy on a two-leg pair**, where the linear regression slope between the two instruments is treated as a hidden state and re-estimated each day via Kalman recursion. Unlike S01 chan-at-bb-pair (which uses a rolling-window OLS regression to recompute the hedge ratio for *signal generation* but freezes it at entry for the *position*), this card uses the Kalman filter to provide a *continuously-updated* state-space estimate of (i) the slope β₁(t), (ii) the intercept β₂(t), (iii) the predicted spread mean ŷ(t), and (iv) the forecast-error variance Q(t). The trading signal is then the standardized prediction error e(t)/√Q(t) — when it falls below -1, go long the spread; when above +1, go short; exit when |e(t)|/√Q(t) returns inside the band.

The thesis is that the relationship between two cointegrating instruments evolves slowly over time (Chan's Figure 3.6 shows the Kalman-updated intercept β₂(t) increasing monotonically with time on the EWA-EWC pair), and a fixed-window or rolling-window OLS regression cannot capture this evolution as smoothly as a Bayesian state-space estimator with a small state-transition variance δ.

Chan's verbatim summary, p. 81:

> "It has a reasonable APR of 26.2 percent and a Sharpe ratio of 2.4."

The δ parameter controls the responsiveness: δ=0 collapses the Kalman filter to ordinary OLS (no state evolution); δ=1 makes β fluctuate wildly with each observation. Chan picks δ=0.0001 (very slow drift, "with the benefit of hindsight"). This is the load-bearing parameter — choosing δ too high turns the strategy into noise; too low and it cannot adapt to actual structural changes.

The instrument pair Chan demonstrates is **EWA (iShares MSCI Australia) vs EWC (iShares MSCI Canada)** — both commodity-economy ETFs that Chan in Chapter 2 (Ex 2.6) showed to be cointegrating per the cadf test. The cointegration premise is independent of the Kalman estimator (Kalman just provides dynamic vs static hedge ratio); the strategy is the Kalman MR signal layered atop that cointegrating pair.

## 3. Markets & Timeframes

```yaml
markets:
  - etf_pair                                  # Chan's deployment: EWA-EWC commodity-economy ETF pair
  - equity_pair                               # generalizable to any cointegrating equity pair (Chan Ch 4)
  - commodities_pair                          # generalizable to any cointegrating cross-asset pair
  # V5 Darwinex re-mapping at CTO sanity-check: EWA-EWC has no direct Darwinex CFD; closest commodity-currency proxy is AUDUSD.DWX/USDCAD.DWX (commodity-currency cousins)
timeframes:
  - D1                                        # Chan deploys on daily closes
session_window: end-of-day                    # signals computed on daily close; entries/exits on next-day open
primary_target_symbols:
  - "EWA-EWC (Chan's primary case, p. 78) — V5 candidate proxy: AUDUSD.DWX/USDCAD.DWX commodity-currency pair"
  - "Generic cointegrating pair (Chan p. 76 generalization): any pair where rolling Kalman-state-space regression produces a stationary residual"
```

## 4. Entry Rules

Pseudocode — verbatim from Chan's Ch 3 Ex 3.3 MATLAB code (PDF p. 78-79) and the surrounding Kalman-filter equations 3.5-3.13 (PDF pp. 75-77).

```text
PARAMETERS (Chan-defaults from Ex 3.3 MATLAB code, with δ "picked with the benefit of hindsight"):
- DELTA       = 0.0001     // state-transition variance scale; Chan: "With the benefit of
                          //   hindsight, we pick δ = 0.0001."
- V_E         = 0.001      // measurement-error variance; Chan: "we also pick Vε = 0.001."
- ENTRY_K     = 1.0        // entry threshold in units of √Q(t) (predicted forecast-error stdev);
                          //   Chan: longsEntry = e < -sqrt(Q); shortsEntry = e > sqrt(Q)
- EXIT_K      = 1.0        // exit when |e| crosses back inside ±√Q(t); Chan code uses
                          //   longsExit = e > -sqrt(Q); shortsExit = e < sqrt(Q)
                          //   (note: ENTRY_K = EXIT_K = 1 in Chan's code — fully symmetric)
- BAR         = D1         // Chan deploys on daily closes
- INIT_BETA   = [0, 0]'    // initial slope + intercept; Chan: "Initialize beta(:, 1) to zero"
- INIT_P      = zeros(2,2) // initial state covariance; Chan: "P=zeros(2);"

PER-DAY (at daily close, generating signals for next session):
- // x_aug = [price[EWA][t]  1]   (regressor + intercept column)
- // y     = price[EWC][t]
- // V_w = (DELTA / (1 - DELTA)) * I_2x2     (state-transition covariance)
- //
- // KALMAN PREDICTION STEP:
- if t > 1:
-     beta(:, t) = beta(:, t-1)                  // state prediction (Eq 3.7)
-     R = P + V_w                                // state covariance prediction (Eq 3.8)
- // KALMAN MEASUREMENT-PREDICTION STEP:
- yhat(t)  = x_aug(t, :) * beta(:, t)            // measurement prediction (Eq 3.9)
- Q(t)     = x_aug(t, :) * R * x_aug(t, :)' + V_E // measurement variance prediction (Eq 3.10)
- // KALMAN UPDATE STEP:
- e(t)     = y(t) - yhat(t)                      // measurement prediction error
- K        = R * x_aug(t, :)' / Q(t)             // Kalman gain
- beta(:, t) = beta(:, t) + K * e(t)             // state update (Eq 3.11)
- P        = R - K * x_aug(t, :) * R             // state covariance update (Eq 3.12)
- // SIGNAL: e(t) is the deviation of EWC-from-predicted-mean (the spread Z-score's numerator)
- // Q(t)  is the predicted variance of e(t) (the spread Z-score's denominator squared)

ENTRY (only when not already in position; one position max per direction):
- if e(t) < -ENTRY_K * sqrt(Q(t))  then OPEN_LONG_SPREAD  at next bar's open
                                  // long_spread = LONG EWC, SHORT (beta1(t) units of EWA)
- if e(t) > +ENTRY_K * sqrt(Q(t))  then OPEN_SHORT_SPREAD at next bar's open
                                  // short_spread = SHORT EWC, LONG (beta1(t) units of EWA)

NOTE on hedge-ratio retiming when in position: Chan's Ex 3.3 code (per "the rest of the code is
the same as bollinger.m — just substitute beta(1, :) in place of hedgeRatio") REPLACES the
static hedgeRatio of the Bollinger card with the dynamic beta(1, :). This means the Kalman
filter continues to update beta even while a position is open. Two readings are possible:
(a) freeze hedge ratio at entry (as in S01); (b) rebalance daily to the latest beta(1, t).
Chan's prose is ambiguous — the code suggests (b) per the substitution. CARD ADOPTS (b) as
the load-bearing reading: the dynamic hedge ratio is THE distinguishing feature of this
strategy vs S01. CTO confirms at G0.
```

## 5. Exit Rules

```text
EXIT (when in position):
- if e(t) >= -EXIT_K * sqrt(Q(t)) then CLOSE_LONG_SPREAD  at next bar's open  // Chan: longsExit = e > -sqrt(Q)
- if e(t) <=  EXIT_K * sqrt(Q(t)) then CLOSE_SHORT_SPREAD at next bar's open  // Chan: shortsExit = e < sqrt(Q)

NO STOP-LOSS:
- Chan, Ch 6 p. 153: "stop losses are not consistent with mean-reverting strategies, because
  they contradict mean reversion strategies' entry signals." Applies here.
- V5 framework's QM_KillSwitch + account MAX_DD trip is the catastrophic backstop.

NO TIME-STOP / NO TRAILING / NO PARTIAL CLOSE.
- Chan's Ex 3.3 MATLAB code holds the position until e returns inside ±√Q. If the spread
  expands further (e grows in magnitude), the position is held — Q also tends to grow with
  uncertainty, but the standardized e/√Q can persist outside ±1 for a meaningful number of
  days.
- Friday Close: standard V5 default applies (force-flat at Friday 21:00 broker time);
  multi-day spread holds will sometimes straddle weekends.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- Friday Close: ENABLED (V5 default; flag friday_close at risk per § 12 — multi-day spread holds may straddle weekends)
- pyramiding: NOT allowed (one open spread position per direction at a time)
- Optional Kalman initialization warm-up period (P3 sweep axis):
    skip entries for the first WARMUP days (default ≈100) — Chan's Figure 3.5 shows beta(1,t)
    converging to ≈1 only after the first 100-200 days; pre-convergence signals are noisy.
- Optional cointegration self-test filter (P3 sweep axis):
    skip entries when the cadf p-value over the trailing 250 days > THRESHOLD
    // Rationale: Chan establishes EWA-EWC as cointegrating in Ch 2 Ex 2.6; if the pair stops
    // cointegrating mid-deployment, the Kalman MR thesis breaks. CEO/CTO call at G0.
```

## 7. Trade Management Rules

```text
- one open spread position per direction at any time (no pyramiding)
- position sizing: spread = 1 unit EWC + (-beta1(t)) units EWA. Chan's "numUnits" is in
  {-1, 0, +1} per Ex 3.3 (no scaling-in / scaling-out).
- gridding: NOT allowed
- hedge ratio TRACKED dynamically (per Chan's "beta(1, :) in place of hedgeRatio" note —
  the load-bearing distinction from S01 chan-at-bb-pair); P3 sweep includes
  "freeze_hedge_at_entry" as alternative axis.
- position size in dollar terms: maps to V5 risk-mode framework at sizing-time;
  catastrophic risk handled by kill-switch since strategy has no native stop
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: delta
  default: 0.0001
  sweep_range: [0.00001, 0.0001, 0.001, 0.01]   # Chan reports 0.0001 with hindsight; sweep brackets 4 orders of magnitude.
                                                # δ=0 (= OLS) is excluded — that's the sibling S01 strategy.
- name: v_e
  default: 0.001
  sweep_range: [0.0001, 0.001, 0.01, 0.1]       # Chan reports 0.001 with hindsight; observation-noise scale
- name: entry_k
  default: 1.0
  sweep_range: [0.5, 0.75, 1.0, 1.5, 2.0]       # Chan reports 1.0; tighter = more trades, smaller per-trade edge
- name: exit_k
  default: 1.0
  sweep_range: [0.0, 0.5, 0.75, 1.0]            # Chan reports 1.0 (symmetric-with-entry); 0 = full reversion to predicted mean
- name: bar
  default: D1
  sweep_range: [H4, D1, W1]                     # Chan deploys on D1; H4 amplifies trade frequency, W1 dampens
- name: warmup_days
  default: 0                                    # disabled by default
  sweep_range: [0, 50, 100, 200, 250]           # Kalman convergence period; 0 disables filter
- name: hedge_retime
  default: dynamic
  sweep_range: ["dynamic", "freeze_at_entry"]   # the load-bearing Kalman vs OLS distinction;
                                                # "freeze_at_entry" recovers S01-style behavior with Kalman-derived signals only
- name: cointegration_filter_p
  default: 0                                    # disabled by default
  sweep_range: [0, 0.05, 0.10, 0.20]            # cadf p-value threshold; 0 disables filter
```

P3.5 (CSR) axis: re-run on alternative cointegrating pairs to test the Kalman construction's generalization. Candidates per Chan Ch 4: GDX-GLD (gold-mining vs gold ETF; Ch 4 cross-reference), KO-PEP (Coca-Cola/Pepsi). V5 Darwinex-native candidates: AUDUSD.DWX/USDCAD.DWX (commodity-currency proxy for EWA-EWC), GOLD.DWX/SILVER.DWX (precious-metal pair).

## 9. Author Claims (verbatim, with quote marks)

EWA-EWC pair, daily bars, default Kalman parameters (δ=0.0001, Vε=0.001, ENTRY_K=EXIT_K=1):

> "It has a reasonable APR of 26.2 percent and a Sharpe ratio of 2.4." (p. 81)

Theoretical framing for the Kalman approach vs ordinary regression:

> "If δ = 0, this means β(t) = β(t - 1), which reduces the Kalman filter to ordinary least square regression with a fixed offset and slope. If δ = 1, this means the estimated β will fluctuate wildly based on the latest observation. The optimal δ, just like the optimal lookback in a moving linear regression, can be obtained using training data. With the benefit of hindsight, we pick δ = 0.0001. With the same hindsight, we also pick Vε = 0.001." (p. 78)

Trading-rule derivation from Kalman state quantities:

> "The measurement prediction error e(t) (previously called the forecast error for y(t) given observation at t - 1) is none other than the deviation of the spread EWC-EWA from its predicted mean value, and we will buy this spread when the deviation is very negative, and vice versa if it is very positive. How negative or positive? That depends on the predicted standard deviation of e(t), which is none other than √Q(t)." (p. 80)

Chan's MATLAB entry/exit signal definitions:

> "longsEntry=e < -sqrt(Q); % a long position means we should buy EWC
> longsExit=e > -sqrt(Q);
> shortsEntry=e > sqrt(Q);
> shortsExit=e < sqrt(Q);" (p. 80)

Anti-stop-loss disposition (Ch 6 p. 153, applied to this strategy via § 5):

> "stop losses are not consistent with mean-reverting strategies, because they contradict mean reversion strategies' entry signals."

## 10. Initial Risk Profile

```yaml
expected_pf: 1.8                              # Chan's reported APR 26.2% / Sharpe 2.4 implies ~PF in the 1.6-2.0 range pre-cost.
                                              # Realistic Darwinex spreads on a synthetic AUDUSD/USDCAD pair (or whatever
                                              # CFD pair stands in for EWA-EWC) will compress this; P9b confirms.
expected_dd_pct: 12                           # rough estimate; Chan's Sharpe 2.4 + zero-stop strategy implies modest interim drawdown
expected_trade_frequency: 30-80/year/pair     # at D1 with ±1√Q trigger and dynamic Kalman state, expect ~30-80 round-trips/year
risk_class: medium                            # daily-bar pair-MR with no native stop; Kalman δ=0.0001 = slow-drift ⇒ stable behavior
gridding: false
scalping: false                               # D1 hold; not scalping
ml_required: false                            # KALMAN FILTER WITH δ FIXED IS NOT ML.
                                              # Per strategy_type_flags.md § E ml-required disambiguation: "HMM with EM is a maximum-
                                              # likelihood statistical fit, *not* machine learning in the V5 sense — no gradient descent
                                              # on a parameterised function approximator, no held-out validation set; per
                                              # specs/two-regime-trend-following.md §9 EM is acceptable as native MQL5". Kalman filter
                                              # with FIXED δ and Vε is identical pedigree: Bayesian state-space recursion, no fitted
                                              # function approximator, no held-out validation set. Hyperparameters δ and Vε are tunable
                                              # like ANY OTHER strategy parameter (lookback, threshold, etc.) — they're tuned via P3
                                              # sweep on training data and held fixed thereafter. Chan p. 78 confirms: "The optimal δ,
                                              # just like the optimal lookback in a moving linear regression, can be obtained using
                                              # training data." Estimated to be ~150-250 LOC native MQL5 (matching the Kalman precedent
                                              # set in two-regime-trend-following spec).
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (Kalman filter recursion + threshold-crossing on standardized prediction error is fully deterministic given fixed δ, Vε)
- [x] No Machine Learning required — see § 10 `ml_required: false` rationale; Kalman with fixed δ and Vε is Bayesian state-space recursion, equivalent pedigree to HMM-with-EM (which is V5-allowed per `strategy_type_flags.md` § E disambiguation)
- [x] If gridding: not applicable (one open position per direction)
- [x] If scalping: not applicable (D1 timeframe)
- [ ] **Friday Close compatibility:** spread-MR holds may straddle weekends (multi-day average hold); flag `friday_close` at risk (§ 12). Net effect on backtest TBD at P3.
- [x] Source citation is precise enough to reproduce (chapter + section + Example number + verbatim Kalman equations + verbatim MATLAB code + verbatim performance quotes)
- [ ] **No near-duplicate of existing approved card** — distinct from S01 chan-at-bb-pair (rolling OLS hedge frozen at entry, Bollinger ±1σ on price-spread; NOT Kalman) AND distinct from SRC02_S01 chan-pairs-stat-arb (cadf-static cointegration, NOT Kalman). DISAMBIGUATION confirmed at extraction. The Kalman state-space estimator is the load-bearing novelty.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); optional Kalman warm-up + cointegration self-test as sweep axes."
  trade_entry:
    used: true
    notes: "Kalman-state-space prediction error e(t) crossing ±√Q(t) (one-stdev band on the dynamic forecast-error variance) on D1 close; one signal per direction at a time"
  trade_management:
    used: true
    notes: "hedge ratio dynamically updated (per Chan's beta(1,t) substitution for static hedgeRatio); no trailing, no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "e(t) returns inside ±√Q(t) — natural reversion to dynamic predicted mean; no time-stop, no native stop-loss"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # multi-day spread holds straddle weekends
  - dwx_suffix_discipline                     # Chan's universe is iShares MSCI ETFs (EWA, EWC); V5 deploys on Darwinex .DWX symbols. Best mapping is commodity-currency cousin AUDUSD.DWX/USDCAD.DWX. CTO confirms at G0; CSR P3.5 tests on Darwinex-native pairs.
  - kill_switch_coverage                      # no native stop-loss (Chan's anti-stop-loss disposition Ch 6 p. 153). Catastrophic backstop relies entirely on V5's QM_KillSwitch and account-level MAX_DD trip.
  - enhancement_doctrine                      # δ=0.0001 and Vε=0.001 are Chan-stated-with-hindsight; entry_k=exit_k=1 are also reported with hindsight. Any post-PASS retune counts as enhancement_doctrine event.

at_risk_explanation: |
  friday_close — D1 pair-MR with dynamic Kalman bands produces multi-day average holds (Chan
  doesn't publish hold-time stats for Ex 3.3 but the implied trade frequency from APR 26.2% /
  Sharpe 2.4 is in the 30-80/year range, implying 5-10 day average holds). Forced flat at
  Friday 21:00 truncates a fraction of those holds.

  dwx_suffix_discipline — EWA-EWC has no direct Darwinex CFD. Best proxy is the
  commodity-currency cousin AUDUSD.DWX/USDCAD.DWX. CTO confirms tick-size + spread profile at
  G0; CSR P3.5 tests on alternative Darwinex-native cointegrating pairs.

  kill_switch_coverage — no native stop-loss. V5 account-level kill-switch is the catastrophic
  backstop. CTO sanity-checks at P5 that kill-switch sizing covers the worst-case "Kalman
  forecast variance Q(t) inflates without spread reverting" scenario, which on a Bayesian
  state-space model can persist longer than on a static-window OLS model.

  enhancement_doctrine — Chan: "With the benefit of hindsight, we pick δ = 0.0001" (p. 78).
  Both δ and Vε were tuned in-sample. Any P3 sweep result is the strategy's first proper
  out-of-sample tuning; any post-PASS retune is an enhancement_doctrine event.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default; optional Kalman warm-up + cointegration filter
  entry: TBD                                  # Kalman filter recursion (eqs 3.7-3.12, ~80-100 LOC native MQL5 per the two-regime-trend-following.md §9 precedent for state-space estimators) + threshold-crossing on e(t) vs ±√Q(t)
  management: TBD                             # hedge ratio dynamically updated each bar (Kalman beta(1,t)); no trailing / BE / partial
  close: TBD                                  # e(t) returns inside ±√Q(t)
estimated_complexity: medium                  # Kalman filter recursion + 2x2 state covariance + dynamic spread synthesis ≈ 150-250 LOC in MQL5
estimated_test_runtime: 4-6h                  # P3 sweep (4×4×5×4×3×5×2×4 ≈ 19,200 cells but most axes are independent ⇒ effective ~5,000) over 5+ years of D1 data per pair
data_requirements: standard                   # D1 OHLC on two .DWX symbols simultaneously
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-28 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-28 | DRAFT (awaiting CEO + Quality-Business review) | this card |
| P1 Build Validation | TBD | TBD | TBD |
| P2 Baseline Screening | TBD | TBD | TBD |
| P3 Parameter Sweep | TBD | TBD | TBD |
| P3.5 CSR | TBD | TBD | TBD |
| P4 Walk-Forward | TBD | TBD | TBD |
| P5 Stress | TBD | TBD | TBD |
| P5b Calibrated Noise | TBD | TBD | TBD |
| P5c Crisis Slices | TBD | TBD | TBD |
| P6 Multi-Seed | TBD | TBD | TBD |
| P7 Statistical Validation | TBD | TBD | TBD |
| P8 News Impact | TBD | TBD | TBD |
| P9 Portfolio Construction | TBD | TBD | TBD |
| P9b Operational Readiness | TBD | TBD | TBD |
| P10 Shadow Deploy | TBD | TBD | TBD |
| Live Promotion | TBD | TBD | TBD |

## 16. Lessons Captured

```text
- 2026-04-28: SRC05_S02 surfaces a NEW `strategy_type_flags` controlled-vocabulary GAP (entry
  side): `kalman-filter-mr` — entry mechanism: Kalman state-space estimator updates dynamic
  hedge ratio + dynamic mean + dynamic forecast-error variance; entries triggered by
  standardized prediction error e(t) crossing ±√Q(t) one-stdev band. Distinct from:
  - `cointegration-pair-trade` (static hedge from regression / Johansen, fixed at entry or
    refit on a rolling window) — Kalman is dynamic Bayesian state-space, not static linear.
  - `zscore-band-reversion` (single-leg own moving statistics) — Kalman uses pair-spread
    forecast error vs forecast variance, not single-leg z-score.
  - `hmm-regime-blend` (HMM with EM, posterior-blend) — Kalman is single-state continuous
    estimation, not discrete-state regime switching.
  V4 had no Kalman-filter SM_XXX EAs per `strategy_type_flags.md` Mining-provenance table.
  Chan citation: Ch 3 Ex 3.3 pp. 78-82. Will batch-propose to CEO + CTO via the addition-
  process documented at the bottom of `strategy_type_flags.md` once SRC05 extraction
  stabilizes.

- 2026-04-28: ml_required disambiguation. Per `strategy_type_flags.md` § E `ml-required`
  Disambiguation entry: "HMM with EM is a maximum-likelihood statistical fit, *not* machine
  learning in the V5 sense — no gradient descent on a parameterised function approximator,
  no held-out validation set; per `specs/two-regime-trend-following.md` §9 EM is acceptable
  as native MQL5". Kalman filter with FIXED δ and Vε is identical pedigree: Bayesian state-
  space recursion, no fitted function approximator, no held-out validation set. δ and Vε are
  tunable like ANY OTHER strategy parameter (lookback, threshold, etc.). Chan confirms this
  framing on p. 78: "The optimal δ, just like the optimal lookback in a moving linear
  regression, can be obtained using training data." Card is V5-ML-compatible. CTO sanity-
  checks at G0 → IN_BUILD.

- 2026-04-28: The load-bearing distinction from S01 chan-at-bb-pair is the DYNAMIC HEDGE
  RATIO. S01 freezes hedgeRatio at entry; this card (per Chan's "beta(1, :) in place of
  hedgeRatio" note, Ex 3.3 p. 81) tracks beta(1, t) every bar. Both readings are ambiguously
  defensible from Chan's prose; this card adopts the dynamic reading because (a) it makes
  the strategy genuinely distinct from S01 and (b) the substitution-into-bollinger.m comment
  implies the wholesale beta(1, :) array is used. Sweep axis `hedge_retime` includes
  `freeze_at_entry` for ablation.

- 2026-04-28: Sinclair (2010) reference at p. 83 on the alternative single-instrument Kalman
  market-maker formulation is OUT OF SCOPE for this card. That construction (mean price m(t)
  as the hidden state, single instrument, market-maker latency-aware Vε) is a distinct
  strategy class — execution-side rather than directional-spread MR. If V5 ever lands an
  HFT/market-making strategy class, the Sinclair single-instrument Kalman would be its own
  card. Tracked here for cross-reference; no SRC05 sub-issue.
```
