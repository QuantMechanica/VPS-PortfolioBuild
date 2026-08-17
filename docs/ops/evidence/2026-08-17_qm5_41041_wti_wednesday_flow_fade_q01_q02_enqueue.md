# QM5_41041 WTI Wednesday Flow Fade — Q01 PASS / Q02 Enqueued

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 ENQUEUED`

## Candidate And Claim Boundary

`QM5_41041_wti-wed-flow-fade` is a new low-frequency single-symbol energy
candidate on exact `XTIUSD.DWX`, D1. On the first executable broker-Thursday
D1 tick, it requires exact completed Monday, Tuesday, and Wednesday sessions
under the native or uniform `+1` energy-label convention. It decomposes the
completed Wednesday move into:

```text
overnight_flow = ln(WednesdayOpen / TuesdayClose)
session_flow   = ln(WednesdayClose / WednesdayOpen)
day_return     = ln(WednesdayClose / TuesdayClose)
total_flow     = overnight_flow + session_flow
```

The candidate trades only when the two components strictly oppose, absolute
session flow strictly dominates absolute overnight flow, and total flow
reconciles to the completed day return within `1e-10`. It fades that completed
move: positive total sells WTI and negative total buys WTI. Agreement, exact
zero, equal magnitude, overnight dominance, broken calendar identity, invalid
endpoints, failed reconciliation, late attachment, or an already consumed
Thursday remains flat.

Each Thursday is persisted as attempted before any fallible history, signal,
spread, quote, ATR, sizing, news, or order gate. The only preset is
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, with one frozen
`3.0 * ATR(20,D1)` stop and no target. The ordinary exit is the first later D1
boundary, normally Friday open; three elapsed days and framework Friday hour
21 are fail-safes.

The approved local source packet combines the official EIA Wednesday
petroleum-information clock, the OWNER-supplied complete Williams
close-to-open/open-to-close decomposition, and peer-reviewed broad commodity
reversal lineage from Yang, Goncu, and Pantelous. None of those sources tests
this exact conjunction, Darwinex continuous-CFD implementation, economics, or
portfolio correlation. This receipt records a build and paced queue handoff,
not certification, profitability, neutrality, realized decorrelation, or
portfolio admission.

## Governance And Non-Duplicate Boundary

- Source approval commit: `4d5611a10`.
- Deterministic EA-ID reservation commit: `99c3dc896`.
- Strategy Card and OWNER G0 commit: `8bd7fbc6f`.
- Pre-magic directory identity commit: `06e56bfa6`.
- Magic registration/resolver commit: `b2057dab9`.
- Q01 build commit: `45016d7c4`.
- Registered route: slot 0 `XTIUSD.DWX`, magic `410410000`.
- The canonical dedup checker scanned 4,528 registry rows and 625 cards and
  returned no exact or fuzzy match.
- `QM5_12590_eia-wti-wpsr-fade` requires a large range/body, tail placement,
  and SMA stretch and may hold four days. This identity uses only internal
  Wednesday overnight/session opposition plus dominance and exits next D1.
- `QM5_12579_eia-wti-wpsr-aftershock` and the M30 WPSR sequence family are
  event aftermath/continuation or intraday sequence identities; this is a
  completed D1 contrarian decomposition.
- `QM5_41029`, `QM5_41032`, and `QM5_41033` form over a full Monday-Friday
  week and enter the following Monday. This identity forms from one exact
  Wednesday, enters Thursday, fades the move, and owns one D1 interval.
- Manual verdict:
  `CLEAN_WTI_STANDARD_WEDNESDAY_SESSION_DOMINANT_FLOW_FADE_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 14 tests PASS, covering same-day and uniform
  `+1` labels, exact dates and gaps, both fade sides, strict opposition and
  dominance, equality/zero/flat states, reconciliation, invalid endpoints,
  Thursday grace/attempt identity, and first-later-D1 exit.
- Both Strategy Card copies are byte-identical and pass schema/ML and G0 lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_085806/QM5_41041_wti-wed-flow-fade.compile.log`.
- Target build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_085805.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41041/P1/P1_QM5_41041_result.json`.
- The backtest setfile is marked `-text` so checkout line-ending conversion
  cannot invalidate its later queue evidence binding.
- No manual tester, smoke test, phase runner, dispatcher tick, or backtest was
  invoked.

## Paced Q02 Handoff

The target-only canonical sweep first dry-ran one eligible fresh row, then
created exactly one Q02 work item:

- work item: `ffc71d7e-7b55-46d6-8694-9286aa3276f6`
- phase/status at verification: `Q02` / `pending`
- created: `2026-08-17T09:07:08+00:00`
- symbol/host: `XTIUSD.DWX`, D1
- setfile:
  `framework/EAs/QM5_41041_wti-wed-flow-fade/sets/QM5_41041_wti-wed-flow-fade_XTIUSD.DWX_D1_backtest.set`
- attempt count: 0
- priority track: true
- custom-history archive admission: `ACTIVE` for `XTIUSD.DWX`

The post-apply target-only dry run selected zero fresh rows, and
`farmctl work-items --ea QM5_41041` confirmed exactly one row.

At `2026-08-17T09:09:04.8283029Z`, the exact-path capacity sample counted only
resolved `D:/QM/mt5/T1..T10/terminal64.exe` paths and explicitly excluded
`T_Live`: four of the governed seven-root ceiling were active (`T3`, `T4`,
`T8`, and `T9`). Instantaneous host CPU load was 100%. The operator therefore
stopped at the pending queue handoff and did not start, stop, kill, attach to,
or otherwise control any terminal, worker, tester, or backtest process.

## Safety And Handoff

No manual MT5 run, terminal/worker mutation, AutoTrading action, `T_Live`
access, live/demo/shadow/stress/optimization preset, deploy manifest, T_Live
manifest, portfolio-gate edit, portfolio admission, neutrality claim, or
correlation waiver occurred.

The paced factory owns the pending Q02 item. Q02 must retire the identity on
zero trades, fewer than five completed positions per full post-warm-up year,
nonpositive governed economics, wrong dates/endpoints, leakage, invalid
opposition/dominance/reconciliation, wrong fade side, late/repeated entry,
wrong next-D1 lifecycle, nondeterminism, or invalid risk mode. Q09 alone may
establish realized decorrelation against the certified book.
