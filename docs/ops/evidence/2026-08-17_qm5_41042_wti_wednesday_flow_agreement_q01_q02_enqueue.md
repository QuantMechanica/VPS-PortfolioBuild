# QM5_41042 WTI Wednesday Flow Agreement — Q01 PASS / Q02 Enqueued

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 ENQUEUED`

## Candidate And Claim Boundary

`QM5_41042_wti-wed-flow-agree` is a new low-frequency single-symbol energy
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

The candidate trades only when `overnight_flow * session_flow > 0` and total
flow reconciles to the completed day return within `1e-10`. It follows the
completed displacement: positive total buys WTI and negative total sells WTI.
Opposition, exact zero, broken calendar identity, invalid endpoints, failed
reconciliation, late attachment, or an already consumed Thursday remains
flat.

Each Thursday is persisted as attempted before any fallible history, signal,
spread, quote, ATR, sizing, news, or order gate. The only preset is
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, with one frozen
`3.0 * ATR(20,D1)` stop and no target. The ordinary exit is the first later D1
boundary, normally Friday open; three elapsed days and framework Friday hour
21 are fail-safes.

The approved local source packet combines the official EIA Wednesday
petroleum-information clock, the OWNER-supplied complete Williams
close-to-open/open-to-close decomposition, and peer-reviewed broad
commodity-continuation lineage from Moskowitz, Ooi, and Pedersen. None of
those sources tests this exact conjunction, short holding horizon, Darwinex
continuous-CFD implementation, economics, or portfolio correlation. This is
a build and paced queue handoff, not certification, profitability, realized
decorrelation, or portfolio admission.

## Governance And Non-Duplicate Boundary

- Source approval commit: `65df03e03`.
- Deterministic EA-ID reservation commit: `7141ab818`.
- Strategy Card and OWNER G0 commit: `c10cb1e1f`.
- Pre-magic directory identity commit: `74d914039`.
- Magic registration/resolver commit: `475192d59`.
- Q01 build commit: `887962e3f`.
- Q02 preflight seal commit: `4748590b4`.
- Registered route: slot 0 `XTIUSD.DWX`, magic `410420000`.
- The canonical checker found no exact identity. Its fuzzy family hits were
  manually separated: `QM5_41029` forms over a full week, `QM5_41034` over a
  full month, and `QM5_41041` requires Wednesday opposition plus session
  dominance and fades the total. This identity uses one exact Wednesday,
  strict same-sign agreement, continuation direction, Thursday entry, and a
  one-D1 hold.
- Manual verdict:
  `CLEAN_WTI_STANDARD_WEDNESDAY_STRICT_FLOW_AGREEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 14 tests PASS, covering same-day and uniform
  `+1` labels, exact dates and gaps, both continuation sides, strict
  agreement/zero/opposition states, reconciliation, invalid endpoints,
  Thursday grace/attempt identity, and first-later-D1 exit.
- Both Strategy Card copies are byte-identical and pass schema/ML and G0 lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_095944/QM5_41042_wti-wed-flow-agree.compile.log`.
- Target build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_095944.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41042/P1/P1_QM5_41042_result.json`.
- Factory symbol-scope validation: `SINGLE_SYMBOL_OK` after all tester-loading
  calls were bound to `_Symbol`; the exact XTI/D1 host guard remains locked.
- The setfile serializes the numeric `1e-10` tolerance as
  `0.0000000001`, avoiding MT5's deterministic exponent-notation input
  rejection. Post-repair preset validation passed with no failures/warnings:
  `D:/QM/reports/framework/21/build_check_20260817_100356.json`.
- The backtest setfile is marked `-text` so checkout line-ending conversion
  cannot invalidate its later evidence binding.

## Early Automated Pickup And Repair

The scheduled fleet detected the new `.ex5` before the manual handoff and
created Q02 row `b07a5699-7675-4aba-8ae7-96a70bc3555c` at
`2026-08-17T09:52:58+00:00`. It failed before a tester run with
`compile_gate:SYMBOL_SCOPE_LEAK`; no market result was produced. The source
was repaired to use `_Symbol`, the factory validator then returned
`SINGLE_SYMBOL_OK`, and the setfile's exponent serialization was repaired
before retry. The canonical target-only dry run selected exactly one bounded
`stranded_infra_fail` recovery row sourced from that failed item.

## Paced Q02 Handoff

The target-only canonical apply created exactly one Q02 retry:

- work item: `0af71887-c879-463e-9bad-4a6b5451a4ad`
- source item: `b07a5699-7675-4aba-8ae7-96a70bc3555c`
- phase: `Q02`
- created: `2026-08-17T10:06:31+00:00`
- symbol/host: exact `XTIUSD.DWX`, D1
- setfile:
  `framework/EAs/QM5_41042_wti-wed-flow-agree/sets/QM5_41042_wti-wed-flow-agree_XTIUSD.DWX_D1_backtest.set`
- attempt count at verification: 0
- priority track: true
- initial status: `pending`; the scheduled fleet subsequently claimed it
  `active` on T4 without any manual dispatcher or terminal action
- custom-history archive admission on the source claim: `ACTIVE` for
  `XTIUSD.DWX`

The target-only post-apply dry run selected zero new rows, so no duplicate
pending/active work item exists.

Exact-path capacity samples counted only resolved
`D:/QM/mt5/T1..T10/terminal64.exe` paths and explicitly excluded `T_Live`.
The count was 3/7 at `2026-08-17T10:05:12.4428743Z` (instantaneous host CPU
96%) and 4/7 immediately before apply. The governed seven-root ceiling was
not reached. The operator stopped at queue handoff and did not start, stop,
kill, attach to, or otherwise control a terminal, worker, tester, or
backtest process.

## Safety And Handoff

No manual MT5 run, dispatcher tick, terminal/worker mutation, AutoTrading
action, `T_Live` access, live/demo/shadow/stress/optimization preset, deploy
manifest, T_Live manifest, portfolio-gate edit, portfolio admission,
decorrelation claim, or correlation waiver occurred.

The paced factory owns the Q02 item. Q02 must retire the identity on zero
trades, fewer than five completed positions per full post-warm-up year,
nonpositive governed economics, wrong dates/endpoints, leakage, invalid
agreement/reconciliation, wrong continuation side, late/repeated entry,
wrong next-D1 lifecycle, nondeterminism, or invalid risk mode. Q09 alone may
establish realized correlation against the certified book.
