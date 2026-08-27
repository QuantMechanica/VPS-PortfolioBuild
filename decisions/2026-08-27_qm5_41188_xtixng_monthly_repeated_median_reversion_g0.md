# QM5_41188 XTI/XNG Monthly Repeated-Median Ratio Reversion — G0 Decision

Date: 2026-08-27

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live logical-basket
Q02 enqueue. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch, durably bound before extraction in
`decisions/2026-08-27_xtixng_monthly_repeated_median_reversion_source_approval.md`
at commit `6c221e724`.

## Candidate

- EA: `QM5_41188_xtixng-mrepmedian-rv`
- strategy ID: `VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026_S01`
- source ID: `VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026`
- host/traded symbol/slot/intended magic: `XTIUSD.DWX` / 0 / `411880000`
- companion/traded symbol/slot/intended magic: `XNGUSD.DWX` / 1 / `411880001`
- logical basket: `QM5_41188_XTI_XNG_MREPMEDIAN_RV_D1`
- driver: strict repeated-median slope sign of thirteen synchronized
  completed monthly oil-minus-gas log ratios
- lifecycle: monthly consumed attempt, contrarian opposite-side package,
  equal-target-notional aggregate fixed risk, frozen ATR stops, atomic
  rollback, next-month exit, and forty-day stale repair

## Source Decision

The approved composite packet is
`strategy-seeds/sources/VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026/source.md`,
SHA-256 `BC85645551B176DC372326985AC783071F6E8AAF958F2ACB73A4D8894404B5DD`.
It combines complete government and peer-reviewed oil/gas relationship
research, including adverse regime evidence, with the official peer-reviewed
repeated-median method record and a governed two-leg lifecycle precedent.

The sources do not prescribe the synchronized sample, ratio orientation,
nested-median sign fade, continuous CFDs, equal-notional construction, risk,
stops, or lifecycle. Those are transparent QM falsification choices. No
source efficacy, density, significance, cost, neutrality, CFD equivalence,
decorrelation, or portfolio result transfers.

## Locked Rule

1. At the first eligible synchronized D1 tick of a genuine broker month,
   persist `yyyymm` before every fallible gate and never retry that month.
2. Exclude the current month and reconstruct exactly thirteen consecutive
   synchronized completed month-end XTI/XNG pairs in chronological order.
   Require positive finite closes, exact common timestamps, distinct months,
   and an endpoint no more than ten days stale.
3. Form `L[i]=ln(XTI[i])-ln(XNG[i])`, oldest to newest.
4. For each of thirteen pivots, compute the twelve forward-oriented slopes to
   every other endpoint, sort them, and average indexes five and six. Sort the
   thirteen finite pivot medians and take outer index six.
5. A positive repeated median opens SELL XTI / BUY XNG. A negative value
   opens BUY XTI / SELL XNG. Exact zero or invalid state consumes flat.
6. Split one aggregate `RISK_FIXED=1000` stop budget equally, target equal
   absolute USD notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and
   enforce 1,500/3,000-point spread and 20% mismatch ceilings.
7. Open XTI then XNG and immediately flatten every owned leg after any order
   failure or invalid final package.
8. Close at the next broker-month transition, after forty calendar days, or
   on malformed owned state. Friday close and all news modes are OFF.

Every numeric and lifecycle rule is singleton-locked for Q02. No rescue sweep,
pooled-slope fallback, fitted intercept, threshold, alternate direction, or
additional gate is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_ESTIMATOR_AND_CARRIER_TRANSLATION_RISK`: complete government
  and peer-reviewed oil/gas research with adverse findings plus an official
  peer-reviewed repeated-median record; exact conjunction untested.
- R2 `PASS`: exact months, synchronization, ratio orientation, pivot groups,
  slope direction, both median stages, sides, attempt, risk, atomicity, and
  lifecycle are reproducible.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  XTI/XNG D1 routes supply every runtime input.
- R4 `PASS`: deterministic native arithmetic and state only, without trained
  output, prohibited signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker returned `CLEAN` with no exact or fuzzy identity across
4,687 registry rows, 1,338 cards, and the actual 45-node Strategy Wiki.
Evidence is
`artifacts/qm5_xtixng_mrepmedian_rv_preallocation_dedup_20260827.json`.

Manual review separates the same-estimator siblings: `QM5_41164` owns a
precious-metal ratio path, while `QM5_41158` follows one outright WTI path.
This rule fades a synchronized oil/gas ratio with two atomic energy legs.
Existing XTI/XNG Pettitt, Mann–Whitney, Spearman, median-runs, ECM, and fixed-
ratio systems use different state functions, aggregation, and exits.

Verdict:
`CLEAN_XTIXNG_MONTHLY_SIEGEL_REPEATED_MEDIAN_RATIO_SLOPE_REVERSION_BASKET`.

## Allocation And Kill Boundary

The canonical `farmctl reserve-ea-ids` command allocated `QM5_41188`; no ID
was inferred or hand-appended. The design allows at most one package per
month after thirteen completed endpoints. Q02 must retire below five
completed packages in any full post-warm-up year, at zero trades, with
nonpositive governed economics, or on a load-bearing implementation defect.
Unchanged Q09 alone may establish realized book correlation.

Both `skill_card_schema_lint.py` and `skill_g0_card_lint.py` must return PASS
before build. The canonical and EA-local card copies must remain byte-
identical.

## Safety Boundary

Create three backtest-only setfiles with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; only the logical basket is a Q02
work item. This decision excludes manual backtests; live, demo, shadow,
stress, and optimization setfiles; `T_Live`; AutoTrading; deploy or live
manifests; portfolio-gate edits; portfolio admission; correlation waivers;
terminal control; and component-leg Q02 rows. Compile/Q01 and the single Q02
enqueue may proceed only below the active factory CPU ceiling.
