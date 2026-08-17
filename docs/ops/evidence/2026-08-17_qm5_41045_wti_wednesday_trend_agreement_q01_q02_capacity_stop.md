# QM5_41045 WTI Wednesday Trend Agreement — Q01 PASS / Q02 Capacity Stop

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED — FACTORY CEILING REACHED`

## Candidate And Claim Boundary

`QM5_41045_wti-wed-trend-agree` is a new low-frequency single-symbol energy
candidate on exact `XTIUSD.DWX`, D1. At the first executable Thursday after an
exact completed Monday, Tuesday, and standard Wednesday, it computes:

```text
event_return = ln(WednesdayClose / TuesdayClose)
slow_trend   = ln(TuesdayClose / Close252SessionsBeforeTuesday)
```

The slow state ends before Wednesday, so the completed event move cannot vote
twice. The candidate trades only when both finite, nonzero returns have the
same sign, follows that sign, and exits on the first later D1 boundary. Each
Thursday is durably consumed before fallible history, spread, ATR, sizing,
news, or order gates. A frozen `3.0 * ATR(20,D1)` stop, no target, a three-day
stale guard, and the framework Friday-hour-21 fail-safe bound the lifecycle.

The only preset is backtest-only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. This build does not establish profitability,
certification, or realized decorrelation; Q09 alone may measure overlap with
the certified XAU/SP500/NDX/XNG book.

## Governance And Non-Duplicate Boundary

- Source approval commit: `ebe884e63`.
- Deterministic EA-ID reservation commit: `4690bd83e`.
- Strategy Card and OWNER G0 commit: `1e61e1ae7`.
- Pre-magic directory identity commit: `6baf3214c`.
- Magic registration/resolver commit: `ab41c56fd`.
- Q01 build commit: `c085ebf74`.
- Registered route: slot 0 `XTIUSD.DWX`, magic `410450000`.
- Canonical pre-allocation dedup scanned 4,532 registry rows and 625 cards and
  returned no exact identity for the slug, strategy ID, or mechanic.
- Manual family review separated the mechanic from Wednesday intraday-flow
  agreement/fade, pre-event Wednesday trend entry, WPSR range aftershock,
  M30 WPSR pullback/failure, and commodity RSI systems. This identity requires
  agreement between one completed Wednesday event return and a separate
  pre-event 252-session trend, followed on Thursday for one D1 interval.
- Manual verdict:
  `CLEAN_WTI_STANDARD_WEDNESDAY_EVENT_PRE_EVENT_TREND_AGREEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 14 tests PASS. Coverage includes native and
  uniform `+1` energy labels, exact calendar/gap identity, both agreement
  directions, disagreement/zero/invalid rejection, the exact 252-session
  endpoint and off-by-one guard, exclusion of Wednesday from the slow state,
  Thursday grace/attempt identity, and first-later-D1 exit.
- Both Strategy Card copies are byte-identical and pass schema/ML and G0 lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_130817/QM5_41045_wti-wed-trend-agree.compile.log`.
- Targeted build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_130817.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41045/P1/P1_QM5_41045_result.json`.
- Factory symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- The exact fixed-risk setfile is marked `-text` to preserve its evidence
  bytes across checkout line-ending settings.

## Q02 Dry Run And Mandatory Capacity Stop

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded/recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41045 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The exact-path capacity sample at `2026-08-17T13:13:08.2444099Z` counted only
resolved `D:/QM/mt5/T1..T10/terminal64.exe` processes and excluded every other
terminal path from the ceiling calculation. It found 7/7 factory terminals
running (`T1`, `T3`, `T6`, `T7`, `T8`, `T9`, `T10`) and sampled host CPU at
100%. The governed ceiling was therefore reached.

Per the mission's explicit stop condition, the apply command was not run. A
read-only work-item query immediately afterward returned count 0 for
`QM5_41045`; no Q02 row was created by this handoff.

## Safety And Handoff

No backtest, dispatcher tick, terminal start/stop/kill/attach, worker mutation,
reservation change, AutoTrading action, live/demo/shadow/stress/optimization
preset, deploy or T_Live manifest, portfolio-gate edit, portfolio admission,
decorrelation claim, or correlation waiver occurred. The capacity sample did
not count or control `T_Live`.

The candidate is committed and Q01-clean but remains unqueued. A later paced
operator may repeat the exact target-only dry run and apply once the governed
factory count is below 7. Q02 must then retire the identity on zero trades,
fewer than five completed positions per full post-warm-up year, nonpositive
governed economics, wrong calendar/endpoints, slow-state leakage, invalid
agreement or side, late/repeated entry, wrong next-D1 lifecycle,
nondeterminism, or invalid risk mode.
