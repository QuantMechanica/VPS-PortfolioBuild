# QM5_41070 WTI Weekly Deceleration: Q01 PASS, Q02 Held At Capacity

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41070_wti-wdecel-mom`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED; HARD TESTER/CPU STOP`

## Edge And Portfolio Boundary

`QM5_41070` mechanizes one structural, low-frequency WTI trend state. On the
first tradable `XTIUSD.DWX` D1 bar of a Monday-anchored broker week, it
reconstructs three consecutive completed week-end closes and two adjacent,
non-overlapping weekly log returns. It trades only when the returns have the
same strict sign and the newest absolute move is strictly smaller. Two
positive decelerating weeks buy; two negative decelerating weeks sell. The
position closes at the first later broker week and has one frozen fixed-risk
ATR hard stop.

The candidate carries direct WTI physical-energy risk outside the certified
XAU/SP500/NDX/XNG book. It differs from certified `QM5_12567`, a long-only
two-day cumulative-RSI2 commodity pullback. It also differs from
`QM5_41068`, which requires a strictly larger newest same-sign weekly move,
and `QM5_41069`, which requires opposed signs and follows the older sign after
a smaller counterweek. The canonical pre-card dedup check was CLEAN across
4,557 registry rows and 625 cards.

Carrier and mechanic difference do not prove decorrelation. Q09 alone may
establish realized correlation with the certified book, and no portfolio
admission occurred here.

## Source, Governance, And Commits

- reputable source: Moskowitz, Ooi, and Pedersen (2012), "Time Series
  Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`;
- complete-read parent packet SHA-256:
  `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`;
- source approval and bounded translation: `82b48303d`;
- deterministic EA reservation: `5c9b99117`;
- slot-zero WTI magic/resolver allocation: `bc55a9805`;
- approved card and G0 decision: `02ebf026d`;
- deterministic build: `486d9dc1a`.

The approved packet discloses that the weekly horizon, same-sign state,
strict smaller-newest-magnitude gate, and one-week hold are QM timing
hypotheses layered onto the peer-reviewed own-return-continuation lineage. No
source or sibling return, frequency, cost, CFD-equivalence, or portfolio-
correlation result is imported.

## Q01 Evidence

- card schema and prohibited-ML lint: PASS;
- G0 build-readiness lint and targeted registry/magic/resolver identity:
  PASS;
- deterministic weekly-deceleration reference suite: 9 tests, PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings, log
  `framework/build/compile/20260820_142753/QM5_41070_wti-wdecel-mom.compile.log`;
- strict targeted V5 build check: PASS, 0 failures, 0 warnings, report
  `D:/QM/reports/framework/21/build_check_20260820_142753.json`;
- static P1 artifact validation: PASS, evidence
  `D:/QM/reports/pipeline/QM5_41070/P1/P1_QM5_41070_result.json`;
- MQ5 SHA-256:
  `FACF2A5AFD7A09479424340247929BA68E108A4681D3D1BE69ADE47606E02883`;
- EX5 SHA-256:
  `D025875DE0990E7DE8ADC4FA37C188164DA111EF0FB863AE972596D18617212E`;
- backtest-set byte SHA-256:
  `09B7A7CA5CFC5485397ED3387567884C09F6388E100DC3C2584F774019B146C1`;
- normalized set content build hash:
  `d386486f7b9d3b21171e77aff9479faf1340ca5d5d78017cc95b1a685ab332c6`.

The only preset is exact `XTIUSD.DWX`, D1, backtest, slot zero, with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
and Friday close OFF. No manual tester or smoke run occurred.

## Target-Only Q02 Admission Check

Read-only `farmctl.py work-items --ea QM5_41070` queries immediately before
and after the capacity check both returned `count=0`.

The canonical target-only dry run selected exactly one fresh Q02 row and no
recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41070 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

No `--apply` command was issued, so the final external state is
`Q02 NOT_ENQUEUED_CPU_CEILING` with no duplicate row.

## Binding Capacity Stop

The read-only `farmctl.py mt5-slots` census at
`2026-08-20T14:30:29+00:00` found eight active exact-path governed research
terminals: `T1`, `T3`, `T4`, `T5`, `T6`, `T7`, `T8`, and `T9`. That exceeds
the paced seven-terminal ceiling. The separate `T_Live` and unrelated FTMO
terminal were observed only so they could be excluded. No orphaned or
duplicate tester process was reported, and none was touched.

The binding five-sample `GetSystemTimes` whole-host CPU check ran from
`2026-08-20T14:31:06.828104+00:00` through
`2026-08-20T14:31:20.337787+00:00`. Two-second samples were `100.00`,
`100.00`, `100.00`, `99.96`, and `100.00` percent; average was `99.99` and
maximum was `100.00`. All five samples crossed the explicit `97%` hard CPU
ceiling.

Per the mission stop condition, this lane issued no apply command, dispatcher
tick, manual backtest, terminal reservation or control, requeue, priority
change, cancellation, or attempt to accelerate the candidate.

## Safety And Handoff

No AutoTrading action, `T_Live` edit, deploy/T_Live manifest change,
portfolio-gate mutation, portfolio admission, decorrelation claim,
correlation waiver, live/demo/shadow/stress/optimization preset, or live use
occurred.

A later paced worker may rerun the exact target-only dry run and enqueue one
fresh row only after a fresh governed-terminal and host-CPU check is below all
ceilings. It must first confirm `work-items --ea QM5_41070` is still empty and
must not enqueue a duplicate. Q02 must retire this identity on zero trades,
fewer than five completed positions per full post-warm-up year, nonpositive
governed economics, label/week/endpoint defect, opposed-sign entry, equal or
larger newest move, wrong-side entry, current-week leakage, duplicate attempt,
missing hard stop, wrong next-week close, nondeterminism, or invalid fixed-risk
mode. It must not be tuned to escape those retirement conditions.

