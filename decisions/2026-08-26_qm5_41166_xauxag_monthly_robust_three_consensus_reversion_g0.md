# QM5_41166 XAU/XAG Monthly Robust-Three Consensus Reversion — G0 Decision

Date: 2026-08-26

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on branch `agents/board-advisor`.

## Decision

Set `g0_status: APPROVED` for one bounded Strategy Card and non-live V5 build:
`QM5_41166_xauxag-mrobust3-agree-rv`. At the first synchronized executable
tick of each broker month, the candidate selects thirteen consecutive
completed XAU/XAG month-end close pairs, computes exact Theil-Sen, least-
absolute-deviation, and Siegel repeated-median slopes over the chronological
gold-minus-silver log-ratio path, and fades the direction only when all three
slopes have one unanimous strict sign.

The candidate may proceed through card lint, governed magic allocation,
resolver regeneration, source build, deterministic reference tests, strict
compile/Q01, build review, and one `RISK_FIXED` logical-basket Q02 enqueue if
the fresh host/tester CPU guard permits. Approval does not pre-judge
economics, neutrality, decorrelation, certification, or portfolio admission.

## Gate Findings

- R1: `PASS_WITH_ENSEMBLE_TRANSLATION_RISK`. The approved packet preserves
  Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
  `10.1016/j.jbankfin.2017.11.010`, with complete author-preprint provenance;
  official CME ratio-spread carrier lineage; complete-read peer-reviewed
  median-regression lineage; and Andrew F. Siegel (1982), *Biometrika* 69(1),
  242-244, DOI `10.1093/biomet/69.1.242`, through the official method record.
  Their unanimous trading conjunction is explicitly untested.
- R2: `PASS`. Symbols, clock, synchronization, thirteen consecutive
  endpoints, 78 pair slopes, Theil-Sen median, LAD residual profiles,
  objectives and ties, thirteen repeated-median pivot groups, strict
  three-way signs, contrarian sides, one-attempt state, aggregate fixed risk,
  atomicity, stops, and exits are fully mechanical.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply
  every runtime input. Q02 owns actual history sufficiency, fills, density,
  and costs.
- R4: `PASS`. The signal uses deterministic timestamps, logarithms, finite
  arithmetic, sorting, absolute loss, and comparisons only. ATR is risk-only.
  No trained logic, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid exists.

## Source And Claim Boundary

Approved source packet:
`strategy-seeds/sources/SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026/source.md`,
SHA-256
`3CB443F1A19E89E39F755B5A94C5E1BE65509E0184FC5F59A9A1EA0DAA5468FD`.
Its durable approval is
`decisions/2026-08-26_xauxag_monthly_robust_three_consensus_reversion_source_approval.md`,
SHA-256
`AF8FF991445B7CF0DF5CBBBA42EC09AF074979278F53BA4347AEB7DFA6320E19`,
committed at `8978302cb`.

No source return, alpha, probability, density, cost, hedge ratio, neutrality,
continuous-CFD equivalence, estimator superiority, decorrelation, or
portfolio-correlation statistic transfers. The three-way consensus, exact
finite arithmetic, CFD mapping, contrarian sides, fixed-dollar risk, stops,
spread caps, and lifecycle are falsifiable QM implementation hypotheses.

## Locked Statistical Contract

For thirteen immediately prior completed synchronized broker-month XAU/XAG
closes, oldest to newest:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..12

pair slopes: (s[j]-s[i])/(j-i), every 0 <= i < j <= 12, exactly 78
theilsen = average(sorted_pair_slopes[38], sorted_pair_slopes[39])

for every pair-slope candidate b:
  intercept = sorted(s[i]-b*i)[6]
  loss = chronological sum(abs(s[i]-intercept-b*i)), i=0..12
lad = ordinary median of every candidate within 1e-12 of minimum loss

for every pivot i=0..12:
  form twelve forward-oriented slopes joining i to every j != i
  pivot_median[i] = average(sorted_pivot[5], sorted_pivot[6])
repeated_median = sorted(pivot_median)[6]

all three > 0 => SELL XAU / BUY XAG
all three < 0 => BUY XAU / SELL XAG
otherwise     => FLAT
```

Require positive finite closes, exact timestamp matches, strict chronological
order, exactly thirteen consecutive month keys, exactly 78 pair slopes,
exactly 78 LAD profiles/objectives, at least one LAD minimizer, exactly twelve
slopes in each of thirteen pivot groups, and finite final statistics. Current-
month prices are excluded. There is no fallback, majority vote, weight,
threshold, fitted scale, OLS gate, or direction flip.

Consume current broker `yyyymm` before every fallible gate. Open one opposite-
side equal-target-absolute-USD-notional package under aggregate
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, with frozen
`3.5*ATR(20,D1)` hard stops and no targets. Close at the first later broker
month; forty days is stale repair only. Both news axes and Friday close remain
OFF.

## Non-Duplicate Decision

The canonical checker scanned 4,665 registry rows, 1,316 cards, and 45
current Wiki nodes. It found no exact match and one fuzzy match to the
outright-WTI robust-three consensus card at score `0.7142857142857143`.
Evidence:
`artifacts/qm5_xauxag_mrobust3_agree_rv_preallocation_dedup_20260826.json`,
SHA-256
`2B9557DF89DA97C26E08BFF67DDAAD42A93C7D8E931CF6BEFBC3DDCAC7C5C6BB`.

Manual review distinguishes the candidate:

- `QM5_41157`, `QM5_41160`, and `QM5_41164` each trade one slope. This card
  must compute all three complete estimators and trade only their strict
  intersection.
- On `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, Theil-Sen and
  LAD are positive while repeated median is negative; the candidate is flat.
- On `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, LAD is
  negative while the other estimators are positive; the candidate is flat.
- Exact positive and negative linear paths make all three signs agree and
  produce the two locked contrarian basket directions.
- `QM5_41165` applies the concept to outright WTI, follows the sign, and owns
  one energy leg. This candidate applies it to a synchronized relative-metal
  path, fades the sign, and owns an atomic equal-notional package.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback, not a monthly paired-metal robust consensus.

Verdict: `CLEAN_AFTER_EXPECTED_WTI_CONSENSUS_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Deterministic Identity

The atomic governed reservation assigned:

- EA ID: `41166`
- slug: `xauxag-mrobust3-agree-rv`
- strategy ID:
  `SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026_S01`
- intended XAU symbol/slot/magic: `XAUUSD.DWX` / 0 / `411660000`
- intended XAG symbol/slot/magic: `XAGUSD.DWX` / 1 / `411660001`

The active identity row is in `framework/registry/ea_id_registry.csv`. Magic
allocation remains a separate governed step after the EA directory exists.

## Authorized Build And Test Boundary

Create exactly three D1 backtest setfiles: one registered-leg preset for each
of `XAUUSD.DWX` and `XAGUSD.DWX`, plus one logical-basket preset for
`QM5_41166_XAU_XAG_MROBUST3_AGREE_RV_D1`. Every preset must lock
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
Friday close OFF, and all strategy parameters.

Compile/Q01 must be strict and reference tests must independently reproduce
all three estimators, both disagreement vectors, positive and negative linear
paths, synchronized consecutive-month selection, consumed-attempt ordering,
equal-notional sizing, atomic repair, and lifecycle.

The paired XAU/XAG carrier is intended to reduce common metal direction
relative to the certified directional XAU/SP500/NDX/XNG book. That is a design
fact, not a realized-neutrality or correlation claim. Q09 alone owns the first
overlap verdict. No portfolio gate, threshold, incumbent, or manifest changes
under this decision.

This G0 does not authorize manual backtests; live/demo/shadow/stress/
optimization setfiles; `T_Live`; AutoTrading; terminal control; deploy or
live manifests; portfolio admission; or a correlation waiver. If the fresh
CPU ceiling is binding, stop after preserving the source build and evidence;
do not dispatch or control a tester.
