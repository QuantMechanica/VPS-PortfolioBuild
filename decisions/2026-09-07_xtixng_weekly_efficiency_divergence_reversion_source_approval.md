# XTI/XNG Weekly Efficiency-Divergence Reversion — Source Approval

- Date: 2026-09-07
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one market-neutral-style XTI/XNG card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced logical Q02 enqueue
  only below the hard CPU ceiling
- Proposed slug: `xtixng-weffdiv-rv`
- Strategy ID: `AI-CODEX-XTIXNG-WEFFDIV-RV-20260907_S01`
- Planned source packet:
  `strategy-seeds/sources/AI-CODEX-XTIXNG-WEFFDIV-RV-20260907/source.md`
- Dedup receipt:
  `artifacts/qm5_xtixng_weffdiv_rv_preallocation_dedup_20260907.json`

## Authority And Complete-Read Evidence

The current explicit OWNER mission directs one new reputable-source,
structural, low-frequency commodity/energy edge and expressly permits a
market-neutral basket. Before this decision, the complete governed
`VILLAR-RAMBERG-OILGAS-2026` and `FMR-MOMTS-2010` packets were read. They
retain complete-read evidence for a U.S. EIA report and peer-reviewed
*Energy Journal* and *Journal of Banking & Finance* papers, including adverse
evidence that the oil/gas linkage is weak, time varying, and dominated at
short horizons by gas-specific variation.

Those sources support testing a bounded relative commodity state on an
economically linked but unstable oil/gas carrier. They do not test the exact
weekly body-to-range efficiency-divergence fade below. Its efficacy, density,
neutrality, and portfolio correlation remain unproven.

## Locked Mechanic

1. Use exact synchronized `XTIUSD.DWX` and `XNGUSD.DWX` D1 bars.
2. On the first tradable bar of a new Monday-anchored broker week, aggregate
   each leg's immediately preceding completed week from three to five matched
   sessions.
3. For each leg compute
   `efficiency = abs(week_close-week_open)/(week_high-week_low)`.
4. Qualify only when exactly one leg is strictly above `2/3` and the other is
   strictly below `1/3`; equality or a zero weekly body/range is flat.
5. Fade the high-efficiency leg's completed-week body direction and take the
   opposite side in the low-efficiency companion. The low-efficiency leg's
   own body direction never changes the package side.
6. Open one opposed equal-notional package under one aggregate
   `RISK_FIXED=1000` budget with frozen `3.5*ATR(20,D1)` hard stops.
7. Consume one durable weekly attempt before fallible gates and flatten at the
   first later broker week, with ten calendar days as stale repair.

No optimizer, learned threshold, current-week observation, target, trail,
scale-in, grid, martingale, pyramid, retry, single-leg fallback, external
runtime feed, or portfolio-state input is permitted.

## R1-R4 Decision

- R1 `PASS_WITH_RULE_TRANSLATION_RISK`: reputable government and
  peer-reviewed evidence supports the carrier and commodity-relative research
  lineage; no source result transfers to the body/range rule.
- R2 `PASS`: synchronized week construction, exact arithmetic, strict
  thresholds, side, attempt, aggregate fixed risk, hard stops, atomic repair,
  and one-week lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 histories provide every runtime market input.
- R4 `PASS`: deterministic arithmetic and native execution state only; no ML,
  banned signal, external feed, grid, martingale, or pyramid.

## Duplicate Decision

The canonical checker covered 4,854 registry rows and 1,467 repository cards.
It found no exact identity and no fuzzy match above its threshold. Manual
search found outright weekly WTI/XNG body-dominance momentum siblings and a
completed-week close-location XTI/XNG pair, but no candidate combining
independent per-leg weekly absolute body/range efficiencies, strict opposite
outer-tercile efficiency states, the high-efficiency leg's body sign, and an
opposed contrarian XTI/XNG package.

The external Strategy Wiki `strategies` root was unavailable, so the checker
returned `INPUT_ERROR_FAIL_CLOSED`. The OWNER's direct mission authorizes this
bounded branch-only source decision despite that recorded external coverage
limit; the unavailable root is not represented as a clean scan.

Verdict:
`DISTINCT_XTIXNG_COMPLETED_WEEK_BODY_RANGE_EFFICIENCY_DIVERGENCE_HIGH_EFFICIENCY_LEG_FADE`.

## Authorization Boundary

This approval permits the named source extraction, one card and G0 decision,
deterministic identity/magic allocation, bounded V5 build, strict Q01, and one
paced logical Q02 enqueue only if a fresh CPU check is below the ceiling. It
excludes manual backtests, optimization, portfolio-gate changes, portfolio
admission, correlation waivers, deployment, live manifests, `T_Live`,
AutoTrading, and live use. Q02 must retire the edge on zero packages, fewer
than five completed packages in any full post-warm-up year, or nonpositive
governed economics; no parameter rescue is authorized.
