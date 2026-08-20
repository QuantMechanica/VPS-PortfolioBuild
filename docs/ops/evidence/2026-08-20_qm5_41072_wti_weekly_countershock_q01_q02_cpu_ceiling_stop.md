# QM5_41072 Q01 PASS and Q02 CPU-ceiling stop

Date: 2026-08-20

EA: `QM5_41072_wti-wcounter-dom`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## Built edge

`QM5_41072` is a low-frequency structural WTI completed-week
countershock-dominance strategy on `XTIUSD.DWX` D1. It uses four completed
broker-week-end closes to form three disjoint weekly log returns. The two
outer returns must share a strict sign, the middle return must oppose them,
and the middle absolute return must strictly exceed the sum of both outer
absolute returns. The trade follows the middle and cumulative three-week sign
for one broker week. The Q02 preset is fixed at `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

This is a new direct-energy identity. It makes no certified-correlation claim;
Q09 retains that decision.

## Governance and build trail

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `83b83ee3a` |
| deterministic EA reservation | `c8ca0aa93` |
| magic allocation and resolver regeneration | `950a4d98b` |
| G0-approved card | `0ef2aa701` |
| implementation and Q01 build | `0a07825c9` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260820_171553.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41072/P1/P1_QM5_41072_result.json` |

Q01 evidence:

- deterministic reference suite: 9 tests passed;
- strict MetaEditor compile: 0 errors, 0 warnings;
- targeted build check: PASS, 0 failures, 0 warnings;
- static P1 validation: PASS;
- card/source schema and banned-signal checks: PASS;
- MQ5 SHA-256: `EB7A64FF056A56BE6823E9BDB10EA0C18DF9F0C46F18DC132FF5F864FA363E51`;
- EX5 SHA-256: `E502DF893BB557D0445F67FCF1980C2EA0847AA023B5FD195A77FCEC6D8DB906`;
- setfile byte SHA-256: `6C7B274175B8BC09634D7A57C4D46DC518E0E1B4113998A450376382FF28B6CB`;
- normalized set build hash: `5211f6dbb2b20d3ed6230b4cb7f01d1215c74638eb6cef2e9ca71fbdf07ec461`.

## Q02 target preflight

The target had no existing work item:

```text
python -m tools.strategy_farm.farmctl work-items --ea QM5_41072
count=0
```

The non-mutating, target-only dry run found exactly one fresh baseline row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41072 --max-part2-per-run 0
APPLY=False
part1 never_tested enqueued=1 skipped=0
part2 stranded enqueued=0 skipped=0
priority_track items=1
```

No `--apply` invocation was made.

## Binding capacity stop

At `2026-08-20T17:19:48Z`, read-only slot inspection showed eight running
governed research terminals against the paced ceiling of seven: `T2`, `T3`,
`T4`, `T6`, `T7`, `T8`, `T9`, and `T10`. `T_Live` and FTMO were observed only
to exclude them from the research count; neither was controlled or modified.

Five two-second `GetSystemTimes` samples from
`2026-08-20T17:19:53.854187Z` through
`2026-08-20T17:20:04.354841Z` were:

```text
99.95%, 99.86%, 98.93%, 99.74%, 100.00%
average=99.70% max=100.00% ceiling=97.00%
```

The CPU ceiling and terminal-count ceiling were both binding. In accordance
with the paced-fleet stop rule, Q02 was not enqueued, dispatched, reserved, or
run. No terminal was stopped, no manual backtest was launched, and no queue
state was mutated.

## Safe handoff

After capacity falls below both ceilings, re-run the target work-item check,
slot inspection, and a fresh CPU sample before using the target-only enqueue
path for `QM5_41072`. Do not broaden the sweep. This record does not authorize
`T_Live`, AutoTrading, deploy/T_Live manifest changes, portfolio-gate changes,
or portfolio admission.
