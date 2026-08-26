# QM5_41165 WTI Monthly Robust-Three Consensus Trend — G0 Decision

Date: 2026-08-26

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on branch `agents/board-advisor`.

## Decision

Set `g0_status: APPROVED` for one bounded Strategy Card and non-live V5 build:
`QM5_41165_wti-mrobust3-agree-tr`. At the first executable tick of each broker
month, the candidate selects thirteen consecutive completed WTI month-end
closes, computes exact Theil-Sen, least-absolute-deviation, and Siegel
repeated-median slopes over their chronological log prices, and follows the
direction only when all three slopes have one unanimous strict sign.

The candidate may proceed through card lint, governed magic allocation,
resolver regeneration, source build, deterministic reference tests, strict
compile/Q01, build review, and one `RISK_FIXED` Q02 enqueue if the fresh
host/tester CPU guard permits. Approval does not pre-judge economics,
decorrelation, certification, or portfolio admission.

## Gate Findings

- R1: `PASS_WITH_ENSEMBLE_TRANSLATION_RISK`. The approved packet preserves
  Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
  104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, with complete-paper
  provenance and explicit WTI membership; Karsten Schweikert (2018),
  *Journal of Banking & Finance* 88, 44-51, DOI
  `10.1016/j.jbankfin.2017.11.010`, with complete author-preprint provenance
  for median-regression lineage; and Andrew F. Siegel (1982), *Biometrika*
  69(1), 242-244, DOI `10.1093/biomet/69.1.242`, through the official method
  record. Their unanimous trading conjunction is explicitly untested.
- R2: `PASS`. Symbol, clock, thirteen consecutive endpoints, 78 pair slopes,
  Theil-Sen median, LAD residual profiles/objectives/ties, thirteen repeated-
  median pivot groups, strict three-way signs, one-attempt state, fixed risk,
  stop, and exits are fully mechanical.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history plus native MT5 state supply every runtime input. Q02 owns actual
  history sufficiency, fills, density, and costs.
- R4: `PASS`. The signal uses deterministic timestamps, logarithms, finite
  arithmetic, sorting, absolute loss, and comparisons only. ATR is risk-only.
  No trained logic, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid exists.

## Source And Claim Boundary

Approved source packet:
`strategy-seeds/sources/MOP-THEILSEN-KOENKER-SIEGEL-WTI-MROBUST3-AGREE-2026/source.md`,
SHA-256
`65A2E315EADB52182C00BD6A86867F9321B48CF714D62361A99FCBC327344D69`.
Its durable approval is
`decisions/2026-08-26_wti_monthly_robust_three_consensus_trend_source_approval.md`,
SHA-256
`700352A32A951CAE27F3F1DDBFF5490BD0B317A74BB80B409D36887620EE5EBC`,
committed at `17565d58d`.

No source return, alpha, probability, density, cost, WTI-only result,
continuous-CFD equivalence, estimator superiority, decorrelation, or portfolio
correlation transfers. The three-way consensus, exact finite arithmetic, CFD
mapping, fixed-dollar risk, stop, spread cap, and lifecycle are falsifiable QM
implementation hypotheses.

## Locked Statistical Contract

For thirteen immediately prior completed broker-month WTI closes, oldest to
newest:

```text
y[i] = ln(C[i]), i=0..12

pair slopes: (y[j]-y[i])/(j-i), every 0 <= i < j <= 12, exactly 78
theilsen = average(sorted_pair_slopes[38], sorted_pair_slopes[39])

for every pair-slope candidate b:
  intercept = sorted(y[i]-b*i)[6]
  loss = chronological sum(abs(y[i]-intercept-b*i)), i=0..12
lad = ordinary median of every candidate within 1e-12 of minimum loss

for every pivot i=0..12:
  form twelve forward-oriented slopes joining i to every j != i
  pivot_median[i] = average(sorted_pivot[5], sorted_pivot[6])
repeated_median = sorted(pivot_median)[6]

all three > 0 => BUY WTI
all three < 0 => SELL WTI
otherwise     => FLAT
```

Require positive finite closes, strict chronological order, exactly thirteen
consecutive month keys, exactly 78 pair slopes, exactly 78 LAD profiles and
objectives, at least one LAD minimizer, exactly twelve slopes in each of
thirteen pivot groups, and finite final statistics. Current-month price is
excluded. There is no fallback, majority vote, weight, threshold, fitted
scale, OLS gate, or direction flip.

Consume the current broker `yyyymm` before every fallible gate. Open one WTI
position under `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen `3.5*ATR(20,D1)` hard stop and no target.
Close at the first later broker month; forty days is stale repair only. Both
news axes and Friday close remain OFF.

## Non-Duplicate Decision

The canonical checker scanned 4,664 registry rows, 1,315 cards, and 45 current
Wiki nodes. It found no exact match and one fuzzy match to the single-
estimator Theil-Sen card at score `0.5833333333333334`. Evidence:
`artifacts/qm5_wti_mrobust3_agree_tr_preallocation_dedup_20260826.json`,
SHA-256
`469540A81B2615A7EAA97A071763BF72713D1B51B0934CEC02028F17D32F61F6`.

Manual review distinguishes the card from the closest implementations:

- `QM5_20271_wti-theilsen-tr`, `QM5_41159_wti-lad-tr`, and
  `QM5_41158_wti-repmedian-tr` each trade one slope. This card must compute
  all three complete estimators and trades only their strict intersection.
- On `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, Theil-Sen is
  `+0.00155555555555556`, LAD is `+0.00375`, and repeated median is `-0.0045`.
  Every constituent takes a position while this card is flat.
- On `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, LAD is
  `-0.002` while the other two are positive, so this card is again flat.
- On the strict line `y[i]=0.01*i`, all three slopes equal `0.01` and the card
  buys. The conjunction is executable and is not a renamed constituent.
- Return-sign votes and endpoint, OLS, adjacent-return, range, flow,
  volatility, or calendar rules estimate different state objects. Certified
  `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG oscillator
  pullback, not a monthly direct-WTI robust consensus.

Verdict: `CLEAN_AFTER_EXPECTED_THEILSEN_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Deterministic Identity

The atomic governed reservation assigned:

- EA ID: `41165`
- slug: `wti-mrobust3-agree-tr`
- strategy ID:
  `MOP-THEILSEN-KOENKER-SIEGEL-WTI-MROBUST3-AGREE-2026_S01`
- intended symbol/slot/magic: `XTIUSD.DWX` / 0 / `411650000`

The active identity row is in `framework/registry/ea_id_registry.csv`. Magic
allocation remains a separate governed step after the EA directory exists.

## Authorized Build And Test Boundary

Create exactly one `XTIUSD.DWX` D1 backtest setfile with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
Friday close OFF, and all strategy parameters locked. Compile/Q01 must be
strict and reference tests must independently reproduce all three estimators,
both disagreement vectors, the unanimous linear vector, consecutive-month
selection, consumed-attempt ordering, and lifecycle.

WTI supplies a crude-oil carrier absent from the certified XAU/SP500/NDX/XNG
book. That is a design fact, not a realized-correlation claim. Q09 alone owns
the first overlap verdict. No portfolio gate, threshold, incumbent, or
manifest changes under this decision.

This G0 does not authorize manual backtests, live/demo/shadow/stress/
optimization setfiles, `T_Live`, AutoTrading, terminal control, deploy or
live manifests, portfolio admission, or a correlation waiver. If the fresh
CPU ceiling is binding, stop after preserving the source build and evidence;
do not dispatch or control a tester.
