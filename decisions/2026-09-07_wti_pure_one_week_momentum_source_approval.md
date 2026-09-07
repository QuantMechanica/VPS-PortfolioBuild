# WTI Pure One-Week Momentum — Source Approval

- Date: 2026-09-07
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency WTI card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `wti-wmom1`
- Strategy ID: `KWON-KANG-YUN-WTI-WMOM1-2026_S01`
- Source packet: `strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM1-2026/source.md`
- Dedup receipt: `artifacts/qm5_wti_wmom1_preallocation_dedup_20260907.json`

## Authority And Complete-Read Evidence

The current explicit OWNER mission directs one new reputable-source,
structural, low-frequency commodity/energy edge and specifically permits an
XTIUSD trend edge. The complete 20-page accepted manuscript of Kwon, Kang, and
Yun, *Weekly Momentum in the Commodity Futures Market*, was retrieved from the
University of Strathclyde repository and read before this decision.

The manuscript identifies its exact weekly signal as the return in week
`t-1`, trades the resulting commodity winner-minus-loser portfolio in week
`t`, includes light sweet crude oil in the energy universe, and reports weekly
momentum as the strongest and most robust tested horizon. It is cross-sectional
futures evidence, not proof for a standalone WTI continuous CFD.

## Locked Mechanic

1. Trade exact `XTIUSD.DWX` on D1 only.
2. On the first tradable D1 bar of a new Monday-anchored broker week,
   reconstruct the immediately preceding completed three-to-five-session week.
3. Define the completed-week return as
   `ln(final_session_close / first_session_open)`.
4. Buy when the return is strictly positive; sell when it is strictly negative;
   zero or invalid return is flat.
5. Consume one durable weekly attempt before fallible gates.
6. Use one `RISK_FIXED=1000` position with a frozen `3.5*ATR(20,D1)` hard stop,
   no target, and no signal-strength sizing.
7. Flatten at the first later broker-week boundary; ten calendar days is stale
   repair only.

No volatility gate, body/range gate, parent range, calendar-month filter,
oscillator, moving average, optimizer, external runtime feed, target, trail,
scale-in, grid, martingale, pyramid, or retry is permitted.

## R1-R4 Decision

- R1 `PASS_WITH_TIME_SERIES_PORT_RISK`: peer-reviewed Finance Research Letters
  evidence and a complete accepted manuscript directly define the one-week
  formation/one-week holding horizon and include WTI; cross-sectional efficacy
  does not transfer to this standalone continuous-CFD port.
- R2 `PASS`: clock, exact endpoints, log-return sign, side, attempt, fixed risk,
  hard stop, and next-week lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XTIUSD.DWX D1
  history supplies every runtime market input.
- R4 `PASS`: deterministic timestamp and OHLC arithmetic only; no ML, banned
  signal, external feed, grid, martingale, or pyramid.

## Duplicate Decision

The canonical checker covered 4,855 registry rows, 1,468 repository cards, and
45 Strategy Wiki nodes. It found no exact identity and no fuzzy match above its
threshold. Manual review distinguishes the closest families:

- `QM5_13049_xti-1w-mom-vol` adds a load-bearing low-volatility regime gate;
  this card admits every valid nonzero completed-week return.
- `QM5_41092_wti-wbody-dominance-mom` requires a strict two-thirds aggregate
  body/range condition; this card has no weekly geometry threshold.
- `QM5_41065` through `QM5_41074` require sign flips, acceleration,
  deceleration, pullbacks, streaks, or other multi-week states.
- WTI calendar, inventory, intraday, monthly trend, and certified XNG RSI
  systems use different clocks or state variables.

Verdict: `DISTINCT_WTI_PURE_IMMEDIATELY_COMPLETED_WEEK_RETURN_SIGN_CONTINUATION`.

## Authorization Boundary

This approval permits the named extraction, one APPROVED card and G0 decision,
deterministic identity/magic allocation, bounded V5 build, mandatory PACER
input-pin audit before compile enqueue, strict Q01, and one paced logical Q02
enqueue only if a fresh CPU check is below the ceiling. It excludes manual
backtests, optimization, portfolio admission, correlation waivers, deployment,
live manifests, `T_Live`, AutoTrading, and live use. Q02 must retire on zero
trades, fewer than five completed positions in any full post-warm-up year, or
nonpositive governed economics; no parameter rescue is authorized.

