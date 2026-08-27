---
source_id: VILLAR-NIST-XTIXNG-MEDRUN-RV-2026
title: XTI/XNG monthly median-runs ratio reversion extraction
publisher: QuantMechanica governed extraction of government, peer-reviewed, and official statistical-method research
source_type: government_peer_reviewed_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_xtixng_monthly_median_runs_reversion_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - MOP-NIST-WTI-MEDRUN-TREND-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
  MOP-NIST-WTI-MEDRUN-TREND-2026: E1954B72A7E9F45BEA151DC1C18DFDA64C40D543C37CB22CF02E95F268147429
method_source_id: NIST-RUNS-TEST-EDA35D
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - xtixng-median-runs-rv
---

# XTI/XNG Monthly Median-Runs Ratio Reversion Source Packet

## Approved Sources Of Record

The energy-carrier packet is
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`. It records
complete reads of:

- Jose A. Villar and Frederick L. Joutz (2006), *The Relationship Between
  Crude Oil and Natural Gas Prices*, U.S. Energy Information Administration,
  43 pages; and
- David J. Ramberg and John E. Parsons (2012), "The Weak Tie Between Natural
  Gas and Oil Prices," *The Energy Journal* 33(2), 13-35, DOI
  `10.5547/01956574.33.2.2`.

The reports document fuel substitution, co-production, drilling, financing,
and LNG links between crude oil and natural gas. They also document material
unexplained gas variation, time-varying coefficients, instability, and
temporary decoupling. The source record therefore supports testing a
state-dependent relationship while explicitly rejecting a permanently fixed
or tight ratio.

The statistical-method record is the official NIST/SEMATECH e-Handbook of
Statistical Methods, section 1.3.5.13, "Runs Test for Detecting
Non-randomness," preserved through the complete-read packet
`strategy-seeds/sources/MOP-NIST-WTI-MEDRUN-TREND-2026/source.md`. Its
reproducible retrieval receipt is
`strategy-seeds/sources/MOP-NIST-WTI-MEDRUN-TREND-2026/retrieval_route_20260827.json`.
The official page defines chronological above/below-median coding, a run as a
consecutive sequence of like signs, the observed run count, and the expected
count `2*n1*n2/(n1+n2)+1`. With six observations above and six below the
median, the expectation is exactly seven.

Both parent packets were read completely before source approval. Their exact
hashes, the current OWNER authority, the source-reader policy boundary, and
the clean preallocation receipt are bound in
`decisions/2026-08-27_xtixng_monthly_median_runs_reversion_source_approval.md`,
committed before this extraction at `4ddcc28dc`.

## Claim Boundary

The energy sources support a weak, state-dependent oil/gas linkage and warn
against an immutable ratio. NIST supplies a transparent nonparametric way to
describe chronological persistence around a sample median. Neither source
tests a median-runs signal on an oil/gas ratio or prescribes a trading rule.

The thirteen monthly endpoints, synchronized continuous-CFD mapping,
oil-minus-gas log-ratio orientation, median omission, inclusive seven-run
boundary, newest-regime fade, monthly cadence, equal-target-notional
construction, ATR stops, spread caps, atomic ordering, and lifecycle are
pre-result QM translations. No source alpha, return, coefficient, p-value,
significance, density, drawdown, cost, CFD equivalence, neutrality,
decorrelation, or portfolio statistic transfers.

## Exact Statistical Contract

For thirteen positive, finite, pairwise-distinct synchronized completed
oil/gas monthly endpoint pairs, oldest to newest:

```text
L[i] = ln(XTI_close[i]) - ln(XNG_close[i]), i=0..12

rank[i] = strict ascending rank of L[i] in 1..13
median rank = 7

B = empty chronological sequence
for i = 0..12:
    if rank[i] < 7: append -1 to B
    if rank[i] > 7: append +1 to B
    if rank[i] = 7: omit it

require len(B) = 12
require count(B=-1) = 6 and count(B=+1) = 6

R = 1 + sum(B[k] != B[k-1]) for k=1..11
require 2 <= R <= 12

SELL XTI / BUY XNG iff R <= 7 and rank[12] > 7
BUY XTI / SELL XNG iff R <= 7 and rank[12] < 7
FLAT                    iff R > 7 or rank[12] = 7
```

The median observation is omitted and does not receive a synthetic side. Its
neighbors become adjacent in the twelve-state sequence. The direction is the
contrarian side of the newest completed ratio regime; it is not the sign of
the newest return, a fitted residual, a slope, or a forecast. Exact equality
at seven runs qualifies. Signal magnitude does not affect risk.

No p-value, normal approximation, small-sample critical table, fitted center,
regression, seasonal direction, moving average, oscillator, external series,
or prior-result gate exists.

## Pre-Result Density Boundary

For thirteen no-tie ranks, remove the unique median. Each of the
`C(12,6)=924` six-low/six-high binary orders occurs equally often, and the
median can occupy any of thirteen chronological positions. Exact enumeration
bound in the authenticated method packet gives:

- 6,744 qualifying representations at `R<=7` with a nonmedian newest point;
- 3,372 high-regime fades and 3,372 low-regime fades;
- 5,268 flat representations; and
- qualification rate `6744/12012 = 562/1001`, approximately
  `0.5614385614385614`.

At twelve monthly decisions this is about 6.737 opportunities per random-rank
year. This is only a transparent pre-market density prior above the unchanged
five-trades/year Q02 floor. It is not a market probability, independence
claim, or statistical rejection level.

## Locked Trading Translation

On the first eligible synchronized D1 tick of a genuine new broker month:

1. Persist the current decision `yyyymm` before history, news, spread, quote,
   ATR, sizing, margin, or order gates. A rejection, stop, restart, or partial
   package failure may not retry that month.
2. Exclude the current month. In a bounded D1 copy, identify exactly thirteen
   immediately prior consecutive broker months and select the latest exact-
   timestamp-matched completed XTI/XNG close pair in each month. Require
   strict chronological timestamps, unique consecutive months, positive
   finite prices, and a newest endpoint no more than ten calendar days stale.
3. Apply the exact ratio, rank, median-omission, balance, and run-count
   contract above. A weak, median-newest, tied, or invalid state consumes the
   month flat.
4. Fade a qualifying regime with opposite equal-target-notional legs. Use one
   aggregate `RISK_FIXED=1000`, split stop risk equally, attach frozen
   `3.5*ATR(20,D1)` hard stops, reject XTI/XNG entry spreads above
   1,500/3,000 points, and reject more than 20 percent rounded target-notional
   mismatch.
5. Submit XTI first and XNG second. Retain only one valid stopped position per
   registered slot in the required opposite directions. Close all owned legs
   immediately after any submission or final-composition failure.
6. Close the package at the first tick in the next broker month or after
   forty calendar days. Immediately repair an orphan, duplicate, same-side,
   wrong-symbol/magic, stopless, or notional-invalid package.

Both news axes, legacy news mode, and Friday close are OFF. Runtime reads no
external file, futures chain, API, paper estimate, optimizer output, trained
artifact, prior backtest result, portfolio state, or live manifest.

## Non-Duplicate Functional Boundary

The canonical checker returned CLEAN across 4,685 registry identities, 1,336
cards, and 45 Strategy Wiki nodes. The receipt is
`artifacts/qm5_xtixng_median_runs_rv_preallocation_dedup_20260827.json`.

- outright WTI median-runs (`QM5_41182`) continues a single price regime;
  this candidate fades a synchronized oil/gas relative regime with two legs;
- Pettitt (`QM5_41175`) searches possible change points;
- Mann-Whitney (`QM5_41178`) sums fixed-block ordinal wins;
- Cox-Stuart (`QM5_41179`) counts six paired early/late comparisons;
- Spearman (`QM5_41180`) measures displacement from calendar rank;
- the oil/gas ECM (`QM5_20237`) fits a rolling trend-augmented regression;
- the fixed-ratio, return-spread, channel, momentum, carry, calendar,
  volatility, and factor-rank baskets transform different state; and
- certified `QM5_12567` is a long-only short-horizon XNG cumulative-RSI2
  pullback rather than a symmetric monthly relative-value basket.

The exact carrier, thirteen synchronized endpoints, log-ratio orientation,
strict ranks, unique median omission, six/six balance, full chronological run
count, inclusive `R<=7` gate, newest-regime fade, equal-notional package,
fixed aggregate risk, and next-month lifecycle are jointly load bearing.
Verdict:
`CLEAN_XTIXNG_MONTHLY_MEDIAN_DICHOTOMY_RUNCOUNT_LE7_NEWEST_RATIO_REGIME_REVERSION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete government and
  peer-reviewed oil/gas research including adverse regime evidence plus a
  complete official NIST method page; the exact conjunction is untested.
- R2 `PASS`: clock, synchronization, endpoint count, ratio orientation,
  ranks, median omission, balance, run count, boundary, sides, attempt, risk,
  atomicity, and lifecycle are fixed.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI and XNG D1 histories and MT5-native state supply every input.
- R4 `PASS`: fixed deterministic arithmetic, comparisons, ranks, counts, and
  state only, without trained output, banned signal, external runtime feed,
  grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire at Q02 on zero trades, fewer than five completed packages in any full
post-warm-up year, nonpositive governed economics, downstream gate failure,
or any month, endpoint, synchronization, ratio, rank, median, balance,
run-count, direction, attempt, risk, package, lifecycle, or determinism
defect. No failure may be rescued by changing a load-bearing rule.

Opposite equal-target-notional legs do not prove dollar, beta, volatility,
factor, market, or portfolio neutrality. Unchanged Q09 alone owns realized
correlation. This packet supports one approved card, one branch-only build,
strict Q01, and one paced non-live logical Q02 enqueue only. It excludes a
manual backtest; live/demo/shadow/stress/optimization preset; `T_Live`;
AutoTrading; deployment; live manifests; portfolio-gate mutation; portfolio
admission; correlation waiver; terminal control; and component-leg Q02 rows.
