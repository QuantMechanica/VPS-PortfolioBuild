# WTI Skipped-Recent-Week Three-Week Momentum — Source Approval

- Date: 2026-09-07
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency WTI card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `wti-wmom42`
- Strategy ID: `KWON-KANG-YUN-WTI-WMOM42-2026_S01`
- Source packet: `strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM42-2026/source.md`
- Dedup receipt: `artifacts/qm5_wti_wmom42_preallocation_dedup_20260907.json`

## Authority And Complete-Read Evidence

The explicit OWNER mission directs one new reputable-source, structural,
low-frequency commodity/energy edge and permits direct XTIUSD trend logic. The
complete 20-page accepted manuscript of Kwon, Kang, and Yun, *Weekly Momentum
in the Commodity Futures Market*, was retrieved from the University of
Strathclyde repository and read before this decision.

The manuscript defines `CMOM4,2` from cumulative returns over weeks `t-4`
through `t-2`, deliberately excludes `t-1`, holds the ranked commodity
portfolio in week `t`, and explicitly includes light sweet crude oil. It also
reports that this monthly-horizon strategy is largely spanned by `CMOM1,1`.
This is cross-sectional futures evidence, not proof for a standalone WTI CFD.

## Locked Mechanic

1. Trade exact preset-bound `XTIUSD.DWX` on D1 only.
2. On the first tradable D1 bar of normalized broker week `t`, reconstruct four
   consecutive completed three-to-five-session broker weeks.
3. Exclude all OHLC from week `t-1`; form only from first open of `t-4` through
   final close of `t-2`.
4. Buy for strictly positive log return; sell for strictly negative; equality
   or invalid state is flat.
5. Consume one durable weekly attempt before fallible gates.
6. Use one `RISK_FIXED=1000` position with a frozen `3.5*ATR(20,D1)` hard stop,
   no target, and no signal-strength sizing.
7. Flatten at the first later broker-week boundary; ten days is stale repair.

No volatility, magnitude, body/range, parent-range, calendar, oscillator,
moving average, optimizer, external feed, target, trail, scale-in, grid,
martingale, pyramid, or retry is permitted.

## R1-R4 Decision

- R1 `PASS_WITH_TIME_SERIES_PORT_RISK`: one complete peer-reviewed source with
  exact `CMOM4,2` horizon and WTI membership; cross-sectional efficacy does not
  transfer and adverse spanning evidence is explicit.
- R2 `PASS`: clock, endpoints, skipped week, sign, side, attempt, fixed risk,
  hard stop, and next-week lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XTIUSD.DWX D1
  history supplies every runtime market input.
- R4 `PASS`: deterministic timestamp/OHLC arithmetic only; no ML, banned
  signal, external feed, grid, martingale, or pyramid.

## Duplicate Decision

Canonical checking found only expected same-source sibling `QM5_41375`; its
signal is solely week `t-1`, whereas this identity must exclude `t-1` and use
the cumulative `t-4..t-2` return. `QM5_20284` skips a month inside a twelve-
month monthly trend rule. Other weekly WTI cards require different sign
sequences or OHLC geometry. The unavailable external wiki root remains visible
in the receipt rather than being silently treated as scanned.

Verdict:
`DISTINCT_WTI_CMOM42_EXACT_T_MINUS_4_TO_T_MINUS_2_SKIP_T_MINUS_1_WEEKLY_CONTINUATION`.

## Authorization Boundary

This approval permits one APPROVED card and G0 decision, deterministic identity
and magic allocation, bounded V5 build, mandatory PACER input-pin audit before
compile enqueue, strict Q01, and one paced logical Q02 enqueue only below the
hard CPU ceiling. It excludes manual backtests, optimization, portfolio
admission, correlation waivers, deployment, live manifests, `T_Live`,
AutoTrading, and live use.
