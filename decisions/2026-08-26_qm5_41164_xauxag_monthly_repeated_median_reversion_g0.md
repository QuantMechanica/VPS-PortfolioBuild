# QM5_41164 XAU/XAG Monthly Repeated-Median Reversion — G0 Decision

Date: 2026-08-26

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on branch `agents/board-advisor`.

## Decision

Set `g0_status: APPROVED` for one bounded Strategy Card and non-live V5 build:
`QM5_41164_xauxag-mrepmedian-rv`. At the first synchronized executable tick of
each broker month, the candidate selects thirteen consecutive synchronized
completed month-end gold/silver close pairs, calculates the exact repeated
median of pivot-specific slopes of the gold-minus-silver log-ratio path, and
fades its sign with an equal-target-notional XAU/XAG package for one broker
month.

The candidate may proceed through card lint, governed magic allocation,
resolver regeneration, source build, deterministic reference tests, strict
compile/Q01, build review, and one logical `RISK_FIXED` Q02 enqueue if the
fresh host/tester CPU guard permits. Approval does not pre-judge economics,
neutrality, decorrelation, certification, or portfolio admission.

## Gate Findings

- R1: `PASS_WITH_ESTIMATOR_TRANSLATION_RISK`. The approved packet preserves
  Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
  `10.1016/j.jbankfin.2017.11.010`, official CME gold/silver spread lineage,
  and Siegel (1982), *Biometrika* 69(1), 242-244, DOI
  `10.1093/biomet/69.1.242`. The paired repeated-median carrier and contrarian
  next-month direction are explicitly untested QM translations.
- R2: `PASS`. Symbols, clock, synchronization, thirteen consecutive month
  keys, latest pair selection, chronological ratios, thirteen pivot groups,
  twelve forward slopes per pivot, inner indexes 5/6, outer index 6, sides,
  one-attempt state, equal-notional aggregate risk, stops, atomicity, and exit
  are fully mechanical.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply all
  runtime inputs. Q02 owns actual history sufficiency, fills, and costs.
- R4: `PASS`. The signal uses deterministic timestamps, logarithms,
  arithmetic, sorting, and comparisons only. ATR is risk-only. No trained
  logic, banned signal indicator, external feed, grid, martingale, scale-in,
  or pyramid exists.

## Source And Claim Boundary

Approved source packet:
`strategy-seeds/sources/SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026/source.md`,
SHA-256
`C96F58F707CA0D622ACF955ABE82E973B60B06F7F872729701C15D3E03B43462`.
Its durable approval is
`decisions/2026-08-26_xauxag_monthly_repeated_median_reversion_source_approval.md`,
SHA-256
`DEE9AC74FCEE6C782752BFDA9332996A181A9F246BB3B66D940ECD01111731E6`,
committed at `12d432f58`.

No source return, alpha, probability, trade density, risk, cost, hedge ratio,
neutrality, continuous-CFD equivalence, robustness improvement, or portfolio
correlation transfers. The paired repeated-median slope, contrarian direction,
CFD mapping, fixed-dollar risk, stops, spread caps, and lifecycle are
falsifiable implementation hypotheses.

## Locked Statistical Contract

For thirteen synchronized consecutive completed broker-month-end pairs,
oldest to newest:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..12

for each pivot i=0..12:
  slopes = []
  for each j=0..12, j != i:
    lo = min(i,j)
    hi = max(i,j)
    slopes.append((s[hi] - s[lo]) / (hi - lo))
  require len(slopes) == 12
  ordered = ascending(slopes)
  pivot_median[i] = (ordered[5] + ordered[6]) / 2

require thirteen finite pivot medians
repeated_median = ascending(pivot_median)[6]

repeated_median > 0 => SELL XAU / BUY XAG
repeated_median < 0 => BUY XAU / SELL XAG
repeated_median = 0 or invalid => FLAT
```

Require the latest exactly timestamp-matched close pair in each required
month, strict chronological order, positive finite closes, finite ratios,
slopes, sums, and medians, exact per-pivot count 12, and exact pivot count 13.
The pooled Theil-Sen median, LAD slope, and raw endpoint displacement are
diagnostic/reference values only and never gate the signal.

Consume the current `yyyymm` attempt before every fallible gate. Open one
opposite-side package under aggregate `RISK_FIXED=1000`, equal target absolute
USD notionals, maximum 20% realized mismatch, frozen per-leg
`3.5*ATR(20,D1)` stops, and no targets. Close at the first later broker month;
forty days is stale repair only. Both news axes and Friday close remain OFF.

## Non-Duplicate Decision

The canonical checker scanned 4,663 registry rows, 1,314 cards, and 45 current
Wiki nodes and returned no exact or fuzzy match. Evidence:
`artifacts/qm5_xauxag_mrepmedian_rv_preallocation_dedup_20260826.json`,
SHA-256
`D831A578286D639AFD34C8BC6AA02A9D6FEF93E3B5AD14E1DBC346691D8CB28F`.

Manual review distinguishes the card from the closest implementations:

- `QM5_41157_xauxag-mtheilsen-rv` pools 78 unique slopes and takes one global
  median. This card takes thirteen pivot-specific medians and their outer
  median.
- `QM5_41160_xauxag-mlad-rv` profiles intercepts and minimizes vertical
  absolute loss. This card has no intercept or objective.
- On valid log-ratio levels
  `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, Theil-Sen is
  `+0.00155555555555556`, LAD is `+0.00375`, and repeated median is `-0.0045`;
  the new rule opens the opposite package from both existing baskets.
- `QM5_41158_wti-repmedian-tr` applies the estimator to outright WTI, follows
  its sign, and owns one energy leg. This card applies it to a synchronized
  metal-relative path, fades it, and owns an atomic equal-notional basket.
- Conditional regression, fixed ratio z-score, OLS, CADF, MAD, daily-return
  pseudomedian, path, sign, flow, and calendar systems use other state objects
  or aggregation rules.

Verdict: `CLEAN_EXACT_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Allocation And Kill Boundary

- allocated EA ID: `QM5_41164`;
- slug: `xauxag-mrepmedian-rv`;
- strategy ID:
  `SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026_S01`;
- intended slot 0: `XAUUSD.DWX`, magic `411640000`;
- intended slot 1: `XAGUSD.DWX`, magic `411640001`;
- expected cadence: approximately ten to twelve packages per full post-
  warm-up year; Q02 must prove at least five per scored full year;
- retire on zero trades, below-floor density, nonpositive governed economics,
  or later portfolio-correlation rejection; and
- fail on current-month leakage, missing/duplicate month, nonlatest pair,
  wrong ratio orientation, pivot omission/duplication, wrong slope direction,
  count, inner or outer median, side, attempt, basket, risk, stop, exit, or
  determinism.

No post-result change to sample, estimator, direction, carrier, risk, stop,
hold, or retry contract is authorized.

## Safety Boundary

This decision excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 must
use the logical basket preset with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. If the governed queue or fresh CPU guard refuses work,
record the stop and do not bypass it.
