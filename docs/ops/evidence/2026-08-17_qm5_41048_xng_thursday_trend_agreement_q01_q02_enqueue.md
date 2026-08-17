# QM5_41048 XNG Thursday Trend Agreement — Q01 And Q02 Handoff

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; ONE PACED Q02 ITEM ENQUEUED`

## Candidate And Claim Boundary

`QM5_41048_xng-thu-trend-agree` is a low-frequency single-symbol natural-gas
candidate on exact `XNGUSD.DWX`, D1. At the first executable broker Friday
after exact completed Tuesday, Wednesday, and standard-Thursday sessions, it
computes:

```text
event_return = ln(ThursdayClose / WednesdayClose)
slow_trend   = ln(WednesdayClose / Close252SessionsBeforeWednesday)
```

The slow state ends before Thursday. The candidate trades only when both
finite, nonzero returns have strictly the same sign, follows that common sign
on Friday, freezes a `3.5 * ATR(20,D1)` hard stop, uses no target, and exits at
the first later D1 boundary. A durable Friday attempt is consumed before every
fallible gate. Friday close is disabled because the ordinary one-D1 lifecycle
spans the weekend; a four-day stale guard bounds malformed lifecycle state.

The only preset is backtest-only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. This handoff does not establish profitability,
certification, or realized decorrelation. Q09 alone may measure overlap with
the certified XAU/SP500/NDX/XNG book.

## Governance And Non-Duplicate Boundary

- Source approval commit:
  `91bf3d7d4251f58b6202f4681c1d8663eb130f3e`.
- EA-ID reservation commit:
  `7da2ce5bf2bd1e06c576a95688375cd7f615c357`.
- Strategy Card and OWNER G0 commit:
  `2f80ee09a7541fa6ef22fecc60065f3ad46edffb`.
- Pre-magic directory identity commit:
  `a30a189d02509c9f76cf8c9ad4a5780d568ddf7d`.
- Magic registration/resolver commit:
  `3d428a550638cb4613973a910ba4b2a38bdeb8c6`.
- Q01 build commit:
  `e65e15f261f201f0aca857c499386004a9d6d7a5`.
- Registered route: slot 0 `XNGUSD.DWX`, magic `410480000`.
- The reputable-source packet combines the official EIA Weekly Natural Gas
  Storage Report release clock with the peer-reviewed Moskowitz-Ooi-Pedersen
  time-series-momentum paper, whose tested futures universe includes natural
  gas. The exact cross-horizon agreement conjunction and continuous-CFD
  translation are disclosed QM hypotheses, not source-proven performance.
- Canonical pre-allocation dedup scanned 4,535 EA rows and 625 approved cards
  and found no exact slug, strategy-ID, or mechanic identity. Manual review
  separated this completed-Thursday event/slow-trend agreement identity from
  existing XNG storage-window, flow-component, reaction-magnitude, pre-event
  trend, and event/trend-opposition systems.
- It is structurally distinct from certified `QM5_12567`, which is a
  long-only two-day oscillator pullback rather than a symmetric, event-clocked
  cross-horizon continuation rule.
- Manual verdict:
  `CLEAN_XNG_STANDARD_THURSDAY_EVENT_SLOW_TREND_AGREEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 15 tests PASS. Coverage includes native and
  uniform `+1` energy labels, holiday rejection, exact weekday sequence,
  Friday grace, both agreement sides, disagreement/zero/invalid rejection,
  the exact 252-session endpoint, exclusion of Thursday from the slow state,
  durable attempt identity, and first-later-D1 exit.
- Both Strategy Card copies are byte-identical and pass schema/ML and G0 lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_165733/QM5_41048_xng-thu-trend-agree.compile.log`.
- Targeted build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_165858.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41048/P1/P1_QM5_41048_result.json`.
- Factory symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- MQ5 SHA-256:
  `D0CAFFFFEECC293285430AA5B9324E60EC83CA0FFF8230AB537F5124191F9315`.
- Compiled EX5 SHA-256:
  `19D2C37E91752AEB12540FAC07BE855E6585EB25394A785CB79A0B8B2B340A9C`.
- Backtest-set normalized-content build hash:
  `80974e1c67e39ad4fecf5698b9c8f14e38881bb551f47f080a04b792354c8b7a`.

## Q02 Capacity Gate And Enqueue

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded/recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41048 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only `farmctl.py mt5-slots` census at
`2026-08-17T17:04:08Z` found five active exact-path research terminals: `T1`,
`T2`, `T4`, `T6`, and `T7`. This was below the documented seven-terminal
backtest ceiling. The census also observed `T_Live` and an unrelated FTMO
terminal only to exclude them. The configured
`D:/QM/strategy_farm/state/launch_gate_max.txt` value was `1`.

A five-sample whole-host CPU reading beginning at
`2026-08-17T17:04:23.8085108Z` measured `96.93`, `93.87`, `95.36`, `92.38`,
and `95.46` percent (average `94.80`, maximum `96.93`). The maximum remained
below the explicit `97%` hard host-CPU stop.

The target-only apply therefore created exactly one work item:

- ID: `6d4dbb7f-736b-4255-965a-b12e7333f24e`
- phase: `Q02`
- created: `2026-08-17T17:04:47+00:00`
- route: exact `XNGUSD.DWX`, D1
- initial state: `pending`, attempt count 0
- priority track: true

An immediate read-only query confirmed the single pending item. A later
read-only query at `2026-08-17T17:06:14Z` found that the scheduled fleet had
claimed it `active` on T7, still with attempt count 0. The post-apply
target-only dry run selected zero rows, so this handoff created no duplicate.
The operator did not invoke a dispatcher tick or start, stop, kill, attach to,
or otherwise control any terminal, worker, tester, or backtest process.

## Safety And Handoff

No manual backtest, pipeline phase run, terminal or worker mutation,
AutoTrading action, live/demo/shadow/stress/optimization preset, `T_Live`
change, deploy/T_Live manifest, portfolio-gate edit, portfolio admission,
decorrelation claim, or correlation waiver occurred.

The paced factory owns the Q02 item. Q02 must retire the identity on zero
trades, fewer than eight completed positions per full post-warm-up year,
nonpositive governed economics, wrong calendar/endpoints, slow-state leakage,
invalid sign agreement or side, late/repeated entry, wrong next-D1 lifecycle,
nondeterminism, or invalid risk mode.
