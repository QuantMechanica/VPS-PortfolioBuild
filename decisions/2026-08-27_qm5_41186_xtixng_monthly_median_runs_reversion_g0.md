# QM5_41186 XTI/XNG Monthly Median-Runs Reversion — G0 Decision

Date: 2026-08-27

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live logical-basket
Q02 enqueue. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch, durably bound before extraction in
`decisions/2026-08-27_xtixng_monthly_median_runs_reversion_source_approval.md`
at commit `4ddcc28dc`.

## Candidate

- EA: `QM5_41186_xtixng-median-runs-rv`
- strategy ID: `VILLAR-NIST-XTIXNG-MEDRUN-RV-2026_S01`
- source ID: `VILLAR-NIST-XTIXNG-MEDRUN-RV-2026`
- host/traded symbol/slot/magic: `XTIUSD.DWX` / 0 / `411860000`
- companion/traded symbol/slot/magic: `XNGUSD.DWX` / 1 / `411860001`
- logical basket: `QM5_41186_XTI_XNG_MEDRUN_RV_D1`
- driver: NIST median-dichotomy run count over thirteen synchronized
  completed monthly oil-minus-gas log-ratio endpoints
- lifecycle: monthly consumed attempt, inclusive `R<=7` newest-regime fade,
  equal-target-notional fixed-risk construction, frozen ATR stops, atomic
  rollback, next-month exit, and forty-day stale repair

## Source Decision

The approved composite packet is
`strategy-seeds/sources/VILLAR-NIST-XTIXNG-MEDRUN-RV-2026/source.md`, SHA-256
`477EBD53C6EE74BCD2986FA0469C3431BEBA750AA2EAA5609DCDF3506AB76FF3`.
It binds complete government and peer-reviewed oil/gas relationship evidence,
including adverse regime findings, to a complete official NIST runs-method
record.

The sources do not prescribe the ratio sample, run boundary, direction,
continuous CFDs, orders, risk, or lifecycle. Those are transparent QM
falsification choices. No source efficacy, density, significance, cost,
coefficient, neutrality, CFD equivalence, decorrelation, or portfolio result
transfers.

## Locked Rule

1. At the first eligible synchronized D1 tick of a genuine broker month,
   persist `yyyymm` before every fallible gate and never retry that month.
2. Exclude the current month and reconstruct exactly thirteen consecutive
   synchronized completed month-end XTI/XNG pairs in chronological order.
   Require positive finite closes, exact common timestamps, distinct months,
   and an endpoint no more than ten days stale.
3. Form `L[i]=ln(XTI[i])-ln(XNG[i])`, require thirteen pairwise-distinct finite
   values, and assign strict ranks one through thirteen.
4. Omit median rank seven; encode lower ranks `-1` and higher ranks `+1` in
   chronology; prove twelve states with a six/six balance.
5. Count all consecutive like-state runs. Require `2<=R<=12`; qualify at the
   inclusive NIST expectation boundary `R<=7`.
6. A qualifying newest high-ratio rank opens SELL XTI / BUY XNG. A qualifying
   newest low-ratio rank opens BUY XTI / SELL XNG. Median-newest or `R>7`
   consumes flat.
7. Split one aggregate `RISK_FIXED=1000` stop budget equally, target equal
   absolute USD notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and
   enforce 1,500/3,000-point spread and 20% notional-mismatch ceilings.
8. Open XTI then XNG and immediately flatten all owned exposure after any
   order failure or invalid final package.
9. Close at the next broker-month transition, after forty calendar days, or
   on malformed owned state. Friday close and all news modes are OFF.

Every numeric and lifecycle rule is singleton-locked for Q02. No rescue sweep
or alternate ratio-state definition is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete government and
  peer-reviewed oil/gas research plus a complete official NIST method page;
  the exact trading conjunction remains untested.
- R2 `PASS`: exact months, synchronization, ratio orientation, ranks, median
  omission, balance, run count, inclusive boundary, sides, attempt, risk,
  atomicity, and lifecycle are reproducible.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  XTI/XNG D1 routes supply every runtime input.
- R4 `PASS`: fixed native arithmetic and state only, without trained output,
  prohibited signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical preallocation checker returned CLEAN across 4,685 registry
identities, 1,336 cards, and the actual 45-node Strategy Wiki. Evidence is
`artifacts/qm5_xtixng_median_runs_rv_preallocation_dedup_20260827.json`.

Manual review separates outright WTI median-runs (`QM5_41182`), XTI/XNG
Pettitt (`QM5_41175`), Mann-Whitney (`QM5_41178`), Cox-Stuart (`QM5_41179`),
Spearman (`QM5_41180`), and rolling ECM (`QM5_20237`). None dichotomizes
thirteen synchronized monthly ratio endpoints around their unique median,
counts every resulting chronological run, and fades the newest ratio regime
at inclusive `R<=7`. Verdict:
`CLEAN_XTIXNG_MONTHLY_MEDIAN_DICHOTOMY_RUNCOUNT_LE7_NEWEST_RATIO_REGIME_REVERSION`.

## Allocation And Kill Boundary

The canonical `farmctl reserve-ea-ids` command allocated `QM5_41186`; no ID
was inferred or hand-appended. Exact random-rank enumeration gives a pre-
result qualification rate of `562/1001`, about 6.737 monthly opportunities per
year. Q02 must retire below five completed packages in any full post-warm-up
year, at zero trades, with nonpositive governed economics, or on a load-
bearing implementation defect. Unchanged Q09 alone may establish realized
book correlation.

## Safety Boundary

Create three backtest-only setfiles with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; only the logical basket is a Q02
work item. This decision excludes manual backtests; live, demo, shadow,
stress, and optimization setfiles; `T_Live`; AutoTrading; deploy or live
manifests; portfolio-gate edits; portfolio admission; correlation waivers;
terminal control; and component-leg Q02 rows. Compile/Q01 and the single Q02
enqueue may proceed only below the active factory CPU ceiling.
