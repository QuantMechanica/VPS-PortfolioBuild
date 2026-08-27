# QM5_41185 XAU/XAG Fixed Fractional-Difference Reversion — G0 Decision

Date: 2026-08-27

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live logical-basket
Q02 enqueue. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch, durably bound before extraction in
`decisions/2026-08-27_xauxag_fractional_difference_reversion_source_approval.md`
at commit `17d4b7b12`.

## Candidate

- EA: `QM5_41185_xauxag-fracd-rv`
- strategy ID: `YAYA-CME-XAUXAG-FRACD-RV-2026_S01`
- source ID: `YAYA-CME-XAUXAG-FRACD-RV-2026`
- host/traded symbol/slot/magic: `XAUUSD.DWX` / 0 / `411850000`
- companion/traded symbol/slot/magic: `XAGUSD.DWX` / 1 / `411850001`
- logical basket: `QM5_41185_XAU_XAG_FRACD_RV_D1`
- driver: held-out z-score of a fixed `d=0.40`, 64-term fractional
  difference over exactly 316 synchronized completed daily log ratios
- lifecycle: monthly consumed attempt, inclusive `abs(z)>=0.50` contrarian
  pair, equal-target-notional fixed-risk construction, frozen ATR stops,
  atomic rollback, next-month exit, and forty-day stale repair

## Source Decision

The approved composite packet is
`strategy-seeds/sources/YAYA-CME-XAUXAG-FRACD-RV-2026/source.md`, SHA-256
`CEC08E0FB0C040227A52053A7051F64CF5D530B2D68C67B8DD87851970B7E4DE`.
It binds peer-reviewed state-dependent and fractional-cointegration evidence
for gold/silver prices to official CME ratio-carrier research.

The sources do not prescribe the fixed order, recurrence truncation,
standardization, monthly clock, threshold, CFDs, orders, risk, or lifecycle.
Those are transparent QM falsification choices. No source efficacy, memory
estimate, density, cost, coefficient, neutrality, CFD equivalence,
decorrelation, or portfolio result transfers.

## Locked Rule

1. At the first eligible synchronized D1 tick of a genuine broker month,
   persist `yyyymm` before every fallible gate and never retry that month.
2. Exact-join 316 completed XAU/XAG D1 close pairs in strict chronological
   order; require positive finite prices, exact latest endpoint agreement,
   and no more than ten days endpoint staleness.
3. Form `s[t]=ln(XAU[t])-ln(XAG[t])` and exactly 64 fixed coefficients with
   `w[0]=1`, `w[k]=w[k-1]*(k-1-0.40)/k`.
4. Produce exactly 253 finite filtered outputs. Use the first 252 as the
   baseline with sample denominator 251; hold the latest output out and
   standardize it against that baseline.
5. `z>=+0.50` opens SELL XAU / BUY XAG; `z<=-0.50` opens BUY XAU / SELL XAG;
   an interior or invalid state consumes flat.
6. Split one aggregate `RISK_FIXED=1000` stop budget equally, target equal
   absolute USD notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and
   enforce 1,500/500-point spread and 20% notional-mismatch ceilings.
7. Open XAU then XAG and immediately flatten all owned exposure after any
   order failure or invalid final package.
8. Close at the next broker-month transition, after forty calendar days, or
   on malformed owned state. Friday close and all news modes are OFF.

Every numeric and lifecycle rule is singleton-locked for Q02. No rescue sweep
or alternate state definition is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_FIXED_FRACDIFF_TRANSLATION_RISK`: named peer-reviewed
  relationship research includes fractional cointegration, and official CME
  research supports the carrier; the conjunction is untested.
- R2 `PASS`: exact history, recurrence, order/truncation, held-out baseline,
  threshold, sides, attempt, risk, atomicity, and lifecycle are reproducible.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered XAU/XAG D1
  routes supply every runtime input.
- R4 `PASS`: fixed native arithmetic only, without trained output, prohibited
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical preallocation checker returned CLEAN across 4,684 registry
identities, 1,335 cards, and the actual 45-node Strategy Wiki. Evidence is
`artifacts/qm5_xauxag_fracd_rv_preallocation_dedup_20260827.json`.

Manual review separates raw-ratio z-score (`QM5_20157`), rolling OLS
(`QM5_20161`), annual CADF/OU (`QM5_21526`), threshold cointegration
(`QM5_20012`), and the return-spread, quantile, stochastic, channel,
seasonal, rank, sign, robust-location, daily-path, and calendar families.
None uses the fixed D1 fractional filter plus held-out baseline and monthly
opposite package. Verdict:
`CLEAN_XAUXAG_FIXED_D040_K64_HELDOUT252_FRACTIONAL_DIFFERENCE_REVERSION`.

## Allocation And Kill Boundary

The canonical `farmctl reserve-ea-ids` command allocated `QM5_41185`; no ID
was inferred or hand-appended. Under a standard-normal reference only, the
threshold implies about 7.4 monthly opportunities/year. Q02 must retire below
five completed packages in any full post-warm-up year, at zero trades, with
nonpositive governed economics, or on a load-bearing implementation defect.
Unchanged Q09 alone may establish realized book correlation.

## Safety Boundary

Create three backtest-only setfiles with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; only the logical basket is a Q02
work item. This decision excludes manual backtests; live, demo, shadow,
stress, and optimization setfiles; `T_Live`; AutoTrading; deploy or live
manifests; portfolio-gate edits; portfolio admission; correlation waivers;
terminal control; and component-leg Q02 rows. Compile/Q01 and the single Q02
enqueue may proceed only below the active factory CPU ceiling.
