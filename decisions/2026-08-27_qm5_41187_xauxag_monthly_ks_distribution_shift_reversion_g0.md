# QM5_41187 XAU/XAG Monthly Signed-KS Distribution-Shift Reversion — G0 Decision

Date: 2026-08-27

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live logical-basket
Q02 enqueue. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch, durably bound before extraction in
`decisions/2026-08-27_xauxag_monthly_ks_distribution_shift_reversion_source_approval.md`
at commit `673be5a44`.

## Candidate

- EA: `QM5_41187_xauxag-mks-rv`
- strategy ID: `SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026_S01`
- source ID: `SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026`
- host/traded symbol/slot/magic: `XAUUSD.DWX` / 0 / `411870000`
- companion/traded symbol/slot/magic: `XAGUSD.DWX` / 1 / `411870001`
- logical basket: `QM5_41187_XAU_XAG_MKS_RV_D1`
- driver: dominant signed empirical-distribution gap between fixed older and
  newer six-month blocks of synchronized gold-minus-silver log ratios
- lifecycle: monthly consumed attempt, inclusive count-gap-three contrarian
  package, equal-target-notional fixed-risk construction, frozen ATR stops,
  atomic rollback, next-month exit, and forty-day stale repair

## Source Decision

The approved composite packet is
`strategy-seeds/sources/SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026/source.md`,
SHA-256 `EFA401D3916AEBAE3403C9CD0C9D141FAB5492678EF52DA458D2F86BFAF7A396`.
It combines complete peer-reviewed gold/silver relationship evidence with
binding adverse findings, official exchange carrier evidence, and the
complete official NIST two-sample ECDF method record.

The sources do not prescribe the synchronized sample, log ratio, fixed split,
integer boundary, contrarian direction, continuous CFDs, equal-notional
construction, risk, stops, or lifecycle. Those are transparent QM
falsification choices. No source efficacy, density, significance, cost,
neutrality, CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Rule

1. At the first eligible synchronized D1 tick of a genuine broker month,
   persist `yyyymm` before every fallible gate and never retry that month.
2. Exclude the current month and reconstruct exactly twelve consecutive
   synchronized completed month-end XAU/XAG pairs in chronological order.
   Require positive finite closes, exact common timestamps, distinct months,
   and an endpoint no more than ten days stale.
3. Form `L[i]=ln(XAU[i])-ln(XAG[i])`; require twelve pairwise-distinct finite
   values and retain fixed older `L[0..5]` and newer `L[6..11]` labels.
4. Scan the combined ratios in strict ascending order. Track
   `Dplus=max(old_seen-new_seen)` and
   `Dminus=max(new_seen-old_seen)`. Prove twelve observations, six/six labels,
   and maxima in `0..6`.
5. A dominant `Dplus>=3` opens SELL XAU / BUY XAG. A dominant `Dminus>=3`
   opens BUY XAU / SELL XAG. Weak or tied maxima consume flat.
6. Split one aggregate `RISK_FIXED=1000` stop budget equally, target equal
   absolute USD notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and
   enforce 1,500/500-point spread and 20% mismatch ceilings.
7. Open XAU then XAG and immediately flatten every owned leg after any order
   failure or invalid final package.
8. Close at the next broker-month transition, after forty calendar days, or
   on malformed owned state. Friday close and all news modes are OFF.

Every numeric and lifecycle rule is singleton-locked for Q02. No rescue sweep
or alternate split, statistic, direction, or threshold is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete peer-reviewed
  gold/silver evidence with adverse findings, official exchange carrier
  research, and a complete official NIST method page; exact conjunction
  untested.
- R2 `PASS`: exact months, synchronization, ratio orientation, fixed blocks,
  ties, count path, maxima, boundary, sides, attempt, risk, atomicity, and
  lifecycle are reproducible.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`:
  registered XAU/XAG D1 routes supply every runtime input.
- R4 `PASS`: deterministic native arithmetic and state only, without trained
  output, prohibited signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker found no exact identity across 4,686 registry rows,
1,337 cards, and the actual 45-node Strategy Wiki. It conservatively returned
`FUZZY_MATCH` for the shared XAU/XAG carrier; evidence is
`artifacts/qm5_xauxag_mks_rv_preallocation_dedup_20260827.json`.

Manual fixtures separate the closest neighbor. Rank path
`[1,2,3,5,11,12,4,6,7,8,9,10]` qualifies the signed-ECDF rule at maxima
`(3,2)` while XAU/XAG Mann-Whitney stays flat at `U_new=23`. Path
`[1,2,4,6,8,10,3,5,7,9,11,12]` stays flat here at `(2,0)` while
Mann-Whitney qualifies at `U_new=26`. This rule also differs from the outright
WTI signed-ECDF continuation build by carrier, contrarian side, two-leg
atomicity, aggregate risk, and package lifecycle. Ratio z-score, OLS, MAD,
channel, fractional-difference, rank-association, change-point, paired-sign,
calendar, flow, and endpoint systems use different state functions.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_FIXED_SIX_BY_SIX_SIGNED_KS_GAP3_DISTRIBUTION_SHIFT_REVERSION_BASKET`.

## Allocation And Kill Boundary

The canonical `farmctl reserve-ea-ids` command allocated `QM5_41187`; no ID
was inferred or hand-appended. Exact enumeration gives a pre-result
qualification rate of `436/924=109/231`, about 5.662 monthly opportunities per
year. Q02 must retire below five completed packages in any full post-warm-up
year, at zero trades, with nonpositive governed economics, or on a load-
bearing implementation defect. Unchanged Q09 alone may establish realized
book correlation.

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
