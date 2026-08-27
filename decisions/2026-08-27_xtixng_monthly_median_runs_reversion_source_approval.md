# XTI/XNG Monthly Median-Runs Reversion — Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Enqueue does not authorize a
manual tester dispatch or work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. It requests one genuinely different,
structural, low-frequency commodity or energy edge, expressly permits a
market-neutral-style carrier, requires reputable-source criteria and
`RISK_FIXED` backtests, and excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xtixng-median-runs-rv`
- proposed strategy ID: `VILLAR-NIST-XTIXNG-MEDRUN-RV-2026_S01`
- proposed source ID: `VILLAR-NIST-XTIXNG-MEDRUN-RV-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- proposed companion/traded slot 1: `XNGUSD.DWX`, D1
- decision clock: first synchronized executable tick of each genuine new
  broker month
- signal: fade the newest high/low regime of thirteen synchronized completed
  monthly oil-minus-gas log ratios only when the NIST median-dichotomy run
  count is no greater than its exact six-versus-six expectation of seven

The canonical allocator owns the EA ID. This record neither predicts nor
reserves an ID.

## Approved Source Basis

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, SHA-256
   `4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604`.
   It records a complete read of Jose A. Villar and Frederick L. Joutz
   (2006), U.S. EIA, *The Relationship Between Crude Oil and Natural Gas
   Prices*, and David J. Ramberg and John E. Parsons (2012), *The Energy
   Journal* 33(2), 13-35, DOI `10.5547/01956574.33.2.2`. The sources document
   physical and economic oil/gas links, error correction, material residual
   gas variation, and regime instability. They reject a permanently tight or
   fixed oil/gas tie.
2. `strategy-seeds/sources/MOP-NIST-WTI-MEDRUN-TREND-2026/source.md`, SHA-256
   `E1954B72A7E9F45BEA151DC1C18DFDA64C40D543C37CB22CF02E95F268147429`.
   Its official statistical-method record is the complete NIST/SEMATECH
   e-Handbook section 1.3.5.13, "Runs Test for Detecting Non-randomness".
   The reproducible retrieval receipt is
   `strategy-seeds/sources/MOP-NIST-WTI-MEDRUN-TREND-2026/retrieval_route_20260827.json`,
   whose SHA-256 is
   `97C43BE2BE74B7027C437A5CAB4D70D070F0E4D659286E5B63EB437513620F25`.
   NIST defines chronological above/below-median coding, consecutive runs,
   and the expected-run formula. With six observations on each side, the
   expected count is exactly seven.

No new public URL is used. A proposed additional public method lead returned
`DEFERRED:SOURCE_POLICY` under the deterministic source reader and was
discarded; no blocked content or inferred claim enters this approval.

The sources do not publish this trading rule, the thirteen-month ratio
sample, the inclusive run boundary, the contrarian pair direction, continuous
CFDs, equal-notional construction, risk, stops, or lifecycle. Those are
transparent QM falsification choices. No source return, coefficient,
significance, density, cost, neutrality, CFD-equivalence, decorrelation, or
portfolio result transfers.

## Locked Mechanic

At the first synchronized executable D1 tick after a genuine broker-month
transition:

1. Persist the current broker `yyyymm` before every fallible gate. One month
   may produce at most one consumed attempt.
2. Exclude the current month. Reconstruct the latest synchronized D1 close
   pair from each of exactly thirteen immediately prior consecutive completed
   broker months. Require one common latest timestamp in each month, strict
   chronology, no missing/duplicate month, positive finite closes, and a
   newest endpoint no more than ten calendar days stale.
3. Form the thirteen chronological oil-minus-gas log ratios
   `L[i]=ln(XTI[i])-ln(XNG[i])`. Require all values finite and pairwise
   distinct. Assign strict ranks 1 through 13; rank seven is the unique
   sample median.
4. Omit the median observation. In chronological order, encode ranks below
   seven as `-1` and ranks above seven as `+1`. Prove exactly six observations
   on each side and exactly twelve encoded states.
5. Count `R=1+sum(B[k]!=B[k-1])` for `k=1..11`; require `2<=R<=12`.
   Continue only when `R<=7`, the exact expected count for six lows and six
   highs. This is an inclusive density boundary, not a significance claim.
6. If the newest ratio rank is above seven, SELL XTI and BUY XNG. If it is
   below seven, BUY XTI and SELL XNG. A newest median or `R>7` consumes the
   month flat. Signal magnitude never changes size.
7. Open at most one opposite-side equal-target-notional package under one
   aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split stop risk equally, attach frozen
   `3.5*ATR(20,D1)` hard stops, cap entry spreads at 1,500 XTI points and
   3,000 XNG points, and cap rounded notional mismatch at 20 percent.
8. Submit XTI first and XNG second. Retain exposure only when exactly one
   correctly directed, stopped position exists in each slot; otherwise close
   every owned leg immediately without retry.
9. Close the complete package on the first tick in a later broker month or
   after forty calendar days. Repair any orphaned, duplicated, same-side,
   wrong-symbol/magic, stopless, or notional-invalid package immediately.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 history, timestamps, logarithms, comparisons, ranks, counts,
ATR, quotes, contract metadata, position/deal state, and persistent terminal
state.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete government and
  peer-reviewed oil/gas relationship research, including adverse regime
  evidence, plus a complete official NIST method page; the trading
  conjunction is untested.
- R2 `PASS`: synchronization, months, ratio orientation, strict ranks, median
  omission, six/six balance, run count, inclusive boundary, contrarian sides,
  attempt state, risk, atomicity, and lifecycle are fixed before Q02.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories and MT5-native state
  supply every runtime input.
- R4 `PASS`: deterministic arithmetic, comparisons, ranks, counts, and state
  only; no trained output, ML, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Pre-Result Density Boundary

For thirteen no-tie ranks, removing the median leaves every six-low/six-high
binary order equally represented. Exact enumeration already bound in the
authenticated method packet gives 6,744 qualifying representations out of
12,012 at `R<=7` with a nonmedian newest point, split into 3,372 per side.
The qualification rate is `562/1001`, approximately `0.5614385614`, or about
6.737 opportunities over twelve monthly decisions under a random-order
reference. This is only a pre-market density calculation used to stay above
the unchanged five-trades/year Q02 floor; it is not a market probability.

## Non-Duplicate Decision

The fail-closed checker scanned 4,685 registry identities, 1,336 cards, and
the actual 45-node Company Reference Strategy Wiki. It returned no exact or
fuzzy match. Evidence is
`artifacts/qm5_xtixng_median_runs_rv_preallocation_dedup_20260827.json`,
SHA-256
`7B476FA894E6753006BF0C96AB05E14382DDD7904939506E2B193ACF44B14E0F`.

Manual semantic review fixes the boundary:

- `QM5_41182_wti-median-runs-tr` applies the run statistic to one WTI price
  path and continues the newest outright-price regime; this candidate applies
  it to synchronized oil/gas log ratios and fades the newest relative regime
  with two opposite legs.
- `QM5_41175_xtixng-mpettitt-rv` searches for one change point and ranks every
  possible split; this rule fixes no split and counts transitions after median
  dichotomization.
- `QM5_41178_xtixng-mwilcoxon-rv` sums all old/new cross-block ordinal wins;
  this rule has no old/new blocks or rank-sum magnitude.
- `QM5_41179_xtixng-mcoxstuart-rv` counts only six paired early/late signs;
  this rule uses twelve median-side states and every chronological transition.
- `QM5_41180_xtixng-mspearman-rv` measures squared displacement from time
  rank; this rule discards within-half rank distance and has no time-rank
  score.
- `QM5_20237_xtixng-ecm-rv` fits a rolling trend-augmented OLS residual and
  convergence exit; this rule fits no coefficient, center, drift, or half-life.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG oscillator
  pullback, not a symmetric monthly paired-energy state-reversion package.

Verdict:
`CLEAN_XTIXNG_MONTHLY_MEDIAN_DICHOTOMY_RUNCOUNT_LE7_NEWEST_RATIO_REGIME_REVERSION`.

## Kill And Safety Boundary

Q02 must retire below five completed paired packages in any full post-warm-up
year, at zero trades, with nonpositive governed economics, or on any month,
endpoint, synchronization, ratio, rank, median, balance, run-count, direction,
attempt, risk, atomicity, lifecycle, or determinism defect. No failed result
may be rescued by changing the sample, threshold, carrier, direction, risk,
hold, or by adding another gate.

Opposite equal-target-notional legs reduce outright energy direction but do
not prove dollar, beta, volatility, factor, market, or portfolio neutrality.
Unchanged Q09 alone owns realized overlap. This approval excludes manual
backtests; live, demo, shadow, stress, and optimization setfiles; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; correlation waivers; terminal control; and component-leg Q02 rows.
Q02 may be enqueued once only after a current strict compile/review PASS and
only below the factory CPU ceiling.
