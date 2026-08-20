# QM5_41068 WTI Weekly Acceleration: Q01 PASS, Q02 Pending At CPU Ceiling

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41068_wti-waccel-mom`

Outcome: `Q01 PASS; Q02 ENQUEUED/PENDING; THIS LANE STOPPED AT TERMINAL AND HOST-CPU CEILINGS`

## Edge And Portfolio Boundary

`QM5_41068` mechanizes one structural, low-frequency WTI stream. On the first
tradable `XTIUSD.DWX` D1 bar of a Monday-anchored broker week, it reconstructs
three consecutive completed week-end closes and two adjacent, non-overlapping
weekly log returns. It buys only when both returns are strictly positive and
the newest absolute return is strictly larger. It sells only when both are
strictly negative and the newest absolute return is strictly larger. All
other states are flat. One restart-safe attempt is consumed per week and one
frozen fixed-risk ATR hard stop is mandatory.

This is a direct-WTI physical-energy research carrier outside the certified
XAU/SP500/NDX/XNG book. It differs from certified `QM5_12567`, a long-only
two-day cumulative-RSI2 commodity pullback, and from `QM5_41065`, which trades
only opposite-sign completed-week handoffs. The pre-card canonical dedup check
was CLEAN across 4,555 registry rows and 625 cards. Manual review also
separated it from thresholded five-day momentum, low-volatility weekly
momentum, within-week segment agreement, and weekly NR7 identities.

Mechanic and carrier difference do not prove decorrelation. Q09 alone may
establish realized correlation with the certified book, and no portfolio
admission occurred here.

## Source, Governance, And Commits

- reputable source: Moskowitz, Ooi, and Pedersen (2012), "Time Series
  Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`;
- complete-read parent source SHA-256:
  `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`;
- source approval and bounded translation: `b6c50e85f`;
- deterministic EA reservation: `17fb34638`;
- slot-zero WTI magic/resolver allocation: `574a9d70c`;
- approved card and G0 decision: `2d3759736`;
- deterministic build: `b67420453`.

The approved packet discloses that the weekly horizon and adjacent-week
magnitude-acceleration gate are QM timing hypotheses layered onto the
peer-reviewed own-return-continuation lineage. No source or sibling return,
frequency, cost, CFD-equivalence, or portfolio-correlation result is imported.

## Q01 Evidence

- card schema and prohibited-ML lint: PASS;
- G0 build-readiness guard and targeted registry/magic/resolver identity:
  PASS;
- deterministic weekly-acceleration reference suite: 9 tests, PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings, log
  `framework/build/compile/20260820_124830/QM5_41068_wti-waccel-mom.compile.log`;
- strict targeted V5 build check: PASS, 0 failures, 0 warnings, report
  `D:/QM/reports/framework/21/build_check_20260820_124830.json`;
- static P1 artifact validation: PASS, evidence
  `D:/QM/reports/pipeline/QM5_41068/P1/P1_QM5_41068_result.json`;
- MQ5 SHA-256:
  `EEA79A135DFE9EB6E8AA02E90965534EBD6FD7A500661153734782149F33AEC1`;
- EX5 SHA-256:
  `60662F06E6D856A9836EBA277E313E8C1F57CDFE1143DBF0EB9AD7272BFB2708`;
- backtest-set byte SHA-256:
  `5FC63556DED96B119E4F426BC1ED798ED3E09DABD8B2CB6D567954A71239A6D1`;
- normalized set content build hash:
  `c26561cf7e6531a72d98e8974aaaae6f1f0fe7df237528a100943d34270fc9fa`.

The only preset is exact `XTIUSD.DWX`, D1, backtest, slot zero, with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
and Friday close OFF. No manual tester or smoke run occurred.

The repository-wide registry validator remains noisy from 1,185 pre-existing
legacy inconsistencies. They were not changed. The new row, slot-zero magic,
generated resolver branch, G0 build guard, and targeted V5 build check were
all verified for `QM5_41068`.

## Target-Only Q02 Admission

The canonical target-only dry run selected exactly one fresh Q02 row and no
recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41068 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

No `--apply` command followed in this lane. The immediate read-only
`farmctl.py work-items --ea QM5_41068` query returned `count=0`, confirming
that the dry run had not immediately created a row.

A later read-only query found one concurrently-created pending Q02 row:

```text
id: 747954ed-a571-47a7-a56e-b222c949c483
created_at: 2026-08-20T12:52:58+00:00
phase: Q02
symbol: XTIUSD.DWX
status: pending
attempt_count: 0
claimed_by: null
payload enqueued_by: claude_sweep_enqueue_2026-06-10.never_tested
```

The row appeared between the empty immediate read and the post-capacity read,
without an apply command from this lane. It was left singular, pending, and
untouched. The final external state is therefore
`Q02 ENQUEUED_PENDING_CPU_CEILING`, not `NOT_ENQUEUED`.

## Binding Capacity Stop

The read-only `farmctl.py mt5-slots` census at
`2026-08-20T12:52:38+00:00` found eight active governed research terminals:
`T1`, `T2`, `T3`, `T5`, `T6`, `T7`, `T8`, and `T9`. That exceeds the
seven-terminal ceiling. The separate `T_Live` and unrelated FTMO terminal
were observed only so they could be excluded; neither was touched.

The binding five-sample `GetSystemTimes` whole-host CPU check ran from
`2026-08-20T12:53:42.829876+00:00` through
`2026-08-20T12:53:53.237721+00:00`. Two-second samples were `100.00`,
`100.00`, `100.00`, `99.95`, and `100.00` percent; average was `99.99` and
maximum was `100.00`. The explicit `97%` hard CPU ceiling was active.

Per the mission stop condition, this lane issued no apply command, dispatcher
tick, manual backtest, terminal reservation or control, requeue, priority
change, cancellation, or attempt to accelerate the pending item.

## Safety And Handoff

No AutoTrading action, `T_Live` edit, deploy/T_Live manifest change,
portfolio-gate mutation, portfolio admission, decorrelation claim,
correlation waiver, live/demo/shadow/stress/optimization preset, or live use
occurred.

A later paced worker should leave the existing row singular and dispatch it
only under the fleet's normal capacity controls after fresh governed-terminal
and host-CPU checks pass. It must not enqueue a duplicate. Q02 must retire
this identity on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, label/week/endpoint defect,
opposed-sign, equal-magnitude, non-accelerating, or wrong-side entry,
current-week leakage, duplicate attempt, missing hard stop, wrong next-week
close, nondeterminism, or invalid fixed-risk mode. It must not be tuned to
escape those retirement conditions.
