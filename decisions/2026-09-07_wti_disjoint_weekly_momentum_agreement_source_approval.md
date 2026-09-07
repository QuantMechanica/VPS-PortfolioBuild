# WTI Disjoint Weekly Momentum Agreement — Source Approval

- Date: 2026-09-07
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency WTI card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `wti-wmom142-agree`
- Strategy ID: `KWON-KANG-YUN-WTI-WMOM142-AGREE-2026_S01`
- Source packet: `strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM142-AGREE-2026/source.md`
- Dedup receipt: `artifacts/qm5_wti_wmom142_agree_preallocation_dedup_20260907.json`
- Source-router receipt: `artifacts/wti_wmom142_source_router_receipt_20260907.json`

## Authority And Evidence

The current explicit OWNER mission authorizes one new reputable-source,
structural, low-frequency commodity/energy card and build, specifically
permitting direct WTI trend logic. The governed parent packets preserve a
complete read of the peer-reviewed Kwon, Kang, and Yun accepted manuscript,
its DOI, retrieval URL, 20-page extent, and SHA-256. A fresh router attempt was
policy-deferred and was not bypassed.

The paper explicitly defines both `CMOM1,1` (week `t-1`) and `CMOM4,2` (weeks
`t-4..t-2`, excluding `t-1`), holds each source portfolio in week `t`, and
includes light sweet crude oil. The new conjunction is a disclosed QM
hypothesis. Cross-sectional futures efficacy does not transfer to standalone
WTI CFD execution.

## Locked Mechanic

1. Trade exact preset-bound `XTIUSD.DWX` on D1 only.
2. On the first tradable D1 bar of normalized broker week `t`, reconstruct
   exactly four consecutive completed three-to-five-session weeks.
3. Compute strict log-return signs independently for week `t-1` and cumulative
   weeks `t-4..t-2`; current-week prices enter neither state.
4. Buy only when both signs are positive; sell only when both are negative;
   disagreement, equality, or invalid state is flat.
5. Consume one durable weekly attempt before fallible gates.
6. Use one `RISK_FIXED=1000` position with frozen `3.5*ATR(20,D1)` hard stop,
   no target, and no signal-strength sizing.
7. Flatten at the first later broker-week boundary; ten days is stale repair.

No magnitude, volatility, range, weekday-direction, calendar-month, moving
average, oscillator, volume, inventory, curve, external-data, target, trail,
scale-in, grid, martingale, pyramid, optimizer, or retry is permitted.

## R1-R4 Decision

- R1 `PASS_WITH_COMPOSITE_AND_TIME_SERIES_PORT_RISK`: one complete peer-
  reviewed source defines both exact horizons and WTI membership; the
  conjunction is untested and adverse spanning evidence is explicit.
- R2 `PASS`: endpoints, agreement, side, timing, attempt, risk, stop, and
  lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XTIUSD.DWX D1
  history supplies every runtime market input.
- R4 `PASS`: deterministic native arithmetic without ML, banned signals, or
  an external runtime feed.

## Duplicate Decision

Canonical checking found only expected fuzzy parent cards `QM5_41375` and
`QM5_41376`; the external Strategy Wiki root remained unavailable. Manual
review finds the conjunction distinct: each parent trades one state alone,
whereas this candidate trades only their strict agreement. The closest older
dual-week system splits one calendar week internally and uses Friday-close
lifecycle; adjacent-week systems require sign paths or magnitude comparisons.

Verdict:
`DISTINCT_WTI_CMOM11_CMOM42_DISJOINT_SIGN_AGREEMENT_WEEKLY_CONTINUATION`.

## Authorization Boundary

This approval permits one APPROVED card and G0 decision, deterministic identity
and magic allocation, bounded V5 build, mandatory PACER input-pin audit before
compile enqueue, strict Q01, and one paced logical Q02 enqueue only below the
hard CPU ceiling. It excludes manual backtests, optimization, portfolio
admission, correlation waivers, portfolio-gate edits, deployment, live
manifests, `T_Live`, AutoTrading, and live use.
