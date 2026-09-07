# WTI Half-Year Weekly Momentum — Source Approval

- Date: 2026-09-07
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency WTI card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `wti-wmom265`
- Strategy ID: `KWON-KANG-YUN-WTI-WMOM265-2026_S01`
- Source packet: `strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM265-2026/source.md`
- Dedup receipt: `artifacts/qm5_wti_wmom265_preallocation_dedup_20260907.json`

## Authority And Complete-Read Evidence

The current explicit OWNER mission authorizes one new reputable-source,
structural, low-frequency commodity/energy card and build, including a direct
WTI trend edge. Kwon, Kang, and Yun, *Weekly Momentum in the Commodity Futures
Market*, Finance Research Letters 35 (2020), 101306, DOI
`10.1016/j.frl.2019.101306`, is a peer-reviewed primary source.

The 20-page accepted manuscript was read in full from the retained local copy
whose SHA-256 is
`D768279A0B0F601216FFFA5C48A534939822E7C29B039169ADF0CA817B222F2C`.
That hash matches the governed complete-read records for `QM5_41375` through
`QM5_41377`. Page 4 defines `CMOM26,5` from weeks `t-26..t-5`, page 14 lists
light sweet crude oil, and Tables 2-4 retain the adverse factor evidence.

## Locked Mechanic

1. Trade preset-bound `XTIUSD.DWX` on D1 only.
2. At the first tradable D1 bar of normalized broker week `t`, reconstruct
   exactly 26 consecutive completed two-to-five-session weeks.
3. Exclude weeks `t-4..t-1`; compute
   `ln(final_close[t-5] / first_open[t-26])` over `t-26..t-5` only.
4. Buy for a strictly positive return, sell for a strictly negative return,
   and remain flat for equality or invalid chronology.
5. Consume one durable weekly attempt before fallible gates.
6. Use one `RISK_FIXED=1000` position with a frozen `3.5*ATR(20,D1)` hard
   stop, no target, and no signal-strength sizing.
7. Flatten at the first later normalized broker-week boundary; ten days is
   stale repair only.

No current-week input, recent-four-week input, magnitude threshold, calendar
month, moving average, oscillator, volume, inventory, curve, external data,
target, trail, scale-in, grid, martingale, pyramid, optimizer, or retry is
permitted.

## R1-R4 Decision

- R1 `PASS_WITH_WEAK_RAW_AND_FACTOR_SPANNING_EVIDENCE`: the source defines the
  exact horizon and includes WTI, but its cross-sectional `CMOM26,5` raw return
  is only 0.14% weekly (t=1.76), factor-adjusted intercept 0.06% (t=0.83), and
  carry loading 0.42 (t=6.19). No efficacy transfers to standalone WTI.
- R2 `PASS`: clock, endpoints, excluded interval, side, attempt, risk, stop,
  and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XTIUSD.DWX D1
  history supplies every runtime market input.
- R4 `PASS`: deterministic native arithmetic without trained or banned logic.

## Duplicate Decision

The canonical checker found no exact slug or strategy-ID duplicate and only
the expected fuzzy same-paper siblings `QM5_41375`, `QM5_41376`, and
`QM5_41377`; the external Strategy Wiki root remained unavailable. Manual
review resolves the family match: those cards use `t-1`, `t-4..t-2`, or their
agreement. This card must exclude all four recent weeks and use the exact
22-week `t-26..t-5` source block. Older monthly 6/12-month WTI trend cards use
month-end clocks and monthly holds, not source-defined weekly endpoints and a
weekly lifecycle.

Verdict: `DISTINCT_WTI_CMOM265_EXACT_HALF_YEAR_WEEKLY_BLOCK_CONTINUATION`.

## Authorization Boundary

This approval permits one APPROVED card and G0 decision, deterministic identity
and magic allocation, bounded V5 build, mandatory PACER input-pin audit before
compile enqueue, strict Q01, and one paced logical Q02 enqueue only below the
hard CPU ceiling. It excludes manual backtests, optimization, portfolio
admission, correlation waivers, portfolio-gate edits, deployment, live
manifests, `T_Live`, AutoTrading, and live use.
