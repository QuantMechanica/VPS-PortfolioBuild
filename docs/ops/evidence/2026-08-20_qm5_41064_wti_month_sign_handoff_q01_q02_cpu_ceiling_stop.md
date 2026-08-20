# QM5_41064 WTI Monthly Sign Handoff: Q01 PASS, Q02 CPU-Ceiling Stop

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41064_wti-mflip-mom`

Outcome: `Q01 PASS; Q02 ENQUEUED/PENDING; THIS LANE STOPPED AT TERMINAL AND HOST-CPU CEILINGS`

## Edge And Portfolio Boundary

`QM5_41064` mechanizes one structural, low-frequency WTI stream. On the first
tradable D1 bar of a broker month, it reconstructs three consecutive completed
month-end closes and two adjacent non-overlapping monthly log returns. It buys
only on a negative-to-positive sign handoff and sells only on a positive-to-
negative handoff, following the newest completed-month sign until the next
broker month. One restart-safe attempt is consumed per month and one frozen
fixed-risk ATR hard stop is mandatory.

This logic differs from certified `QM5_12567`, which is a two-day cumulative-
RSI2 commodity pullback, and puts a distinct WTI physical-energy carrier into
research for the index/metal/XNG book. It also differs from unconditional WTI
one-month continuation, older-trend pullback, nested month/final-week
agreement, and current-month opening reversal. Mechanic and carrier difference
do not prove decorrelation. Q09 alone may establish realized book correlation.

## Source, Governance, And Commits

- reputable source: Moskowitz, Ooi, and Pedersen (2012), "Time Series
  Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`;
- source approval:
  `3eb52da3e002afa30d60b0ef3367bf91234d7183`;
- deterministic EA reservation:
  `6afb259ec5d2c70af4576aa281112a0cdb2655be`;
- slot-zero WTI magic/resolver allocation:
  `ac7c5010a8c78b45040b88e642c064f6fd635658`;
- approved card and G0 decision:
  `d7534494793fb42fcbec879fdb6fc758e4ea8c81`;
- deterministic build:
  `da89d615bf1947d672f1e61eec608f7b91f0d5a8`.

The approved packet discloses that the adjacent-month sign-change gate is a
QM timing hypothesis layered onto peer-reviewed one-month own-return
continuation lineage. No source or sibling return, density, cost, CFD-
equivalence, or portfolio-correlation claim is imported.

## Q01 Evidence

- card schema and prohibited-ML lint: PASS;
- G0 build-readiness guard: PASS;
- deterministic month-sign-handoff reference suite: 8 tests, PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings, log
  `framework/build/compile/20260820_084923/QM5_41064_wti-mflip-mom.compile.log`;
- strict targeted V5 build check: PASS, 0 failures, 0 warnings, report
  `D:/QM/reports/framework/21/build_check_20260820_084922.json`;
- static P1 artifact validation: PASS, evidence
  `D:/QM/reports/pipeline/QM5_41064/P1/P1_QM5_41064_result.json`;
- MQ5 SHA-256:
  `EF4862B17333BF5362ABC5E03D9E574FC41621B292E90398F211F032AC297DBB`;
- EX5 SHA-256:
  `EA7B53472AEA929A93F0D1D12D0EBAA0ADA1581815D9894421127224FC990ADC`;
- backtest-set byte SHA-256:
  `B463964701158DEDA874C1B0708050A6072C10F256B8ACF2D8EA88A8760000B7`;
- normalized set content build hash:
  `9e87684f697849222dd3f5e16b098aea431ab76670d8d2ba4bab0bca9209f872`.

The only preset is exact `XTIUSD.DWX`, D1, backtest, slot zero, with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
and Friday close OFF. No manual tester or smoke run occurred.

## Target-Only Q02 Dry Run

The canonical target-only dry run selected exactly one fresh Q02 row and no
recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41064 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

No `--apply` command followed in this lane. The immediate read-only
`farmctl.py work-items --ea QM5_41064` query returned `count=0`, showing that
the dry run had not immediately created a row.

A later read-only query found one concurrently-created pending Q02 row:

```text
id: e5d1dfa2-a198-4769-9a41-f9c99e7d191a
created_at: 2026-08-20T08:52:58+00:00
phase: Q02
status: pending
symbol: XTIUSD.DWX
attempt_count: 0
```

The row appeared after the empty immediate read and without an apply command
from this lane. It was left pending and untouched. The final external state is
therefore `Q02 ENQUEUED_PENDING_CPU_CEILING`, not `NOT_ENQUEUED`.

## Binding Capacity Stop

The read-only `farmctl.py mt5-slots` census at
`2026-08-20T08:52:29+00:00` found nine active governed research terminals:
`T1`, `T2`, `T3`, `T4`, `T5`, `T6`, `T7`, `T8`, and `T10`. That exceeds the
seven-terminal ceiling. The separate `T_Live` and unrelated FTMO terminal were
observed only so they could be excluded; neither was touched.

The binding five-sample whole-host CPU check completed at
`2026-08-20T08:53:06.0476136Z`. Two-second samples were `99.80`, `100.00`,
`99.95`, `100.00`, and `100.00` percent; average was `99.95` and maximum was
`100.00`. The explicit `97%` hard ceiling was therefore active.

Per the mission stop condition, this lane issued no apply command, dispatcher
tick, manual backtest, terminal reservation or control, requeue, priority
change, cancellation, or attempt to accelerate the pending item.

## Safety And Handoff

No AutoTrading action, `T_Live` edit, deploy/T_Live manifest change,
portfolio-gate mutation, portfolio admission, decorrelation claim, correlation
waiver, live/demo/shadow/stress/optimization preset, or live use occurred.

A later paced operator should leave the existing row singular and allow it to
dispatch only under the fleet's normal capacity controls after fresh governed-
terminal and host-CPU checks pass. It must not enqueue a duplicate. Q02 must
retire this identity on zero trades, fewer than five completed positions per
full post-warm-up year, nonpositive governed economics, label/month/endpoint
defect, same-sign or wrong-side entry, current-month leakage, duplicate
attempt, missing hard stop, wrong next-month close, nondeterminism, or invalid
fixed-risk mode. It must not be tuned to escape those retirement conditions.
