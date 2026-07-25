# QM5_20062 forex build refresh — CPU ceiling stop

- UTC: `2026-07-25T12:47:48Z`
- Branch: `agents/board-advisor`
- EA: `QM5_20062_kats-eu-macisar`
- Instrument / timeframe: `EURUSD.DWX / D1`
- Farm build task: `ee2fe37e-5509-4371-8979-c58db2966313`

## Selection and collision check

The EURUSD card was the highest-diversity approved build in the farm backlog.
Its build task still showed `active`, but the recorded Claude PID `3952` no
longer existed and the configured `build_result_path` did not exist. The EA
source, SPEC, binary, setfile, EA registry row, and active magic row were already
present from the prior factory build, so this wake repaired the stale artifact
handoff rather than creating a duplicate EA or task.

## Validation and artifact refresh

`python framework/scripts/validate_spec_doc.py
framework/EAs/QM5_20062_kats-eu-macisar` returned `PASS`.

`pwsh -File framework/scripts/build_check.ps1 -EALabel
QM5_20062_kats-eu-macisar` returned:

- `build_check.result=PASS`
- `build_check.failures=0`
- `build_check.warnings=0`
- `compile_one.result=PASS`
- `compile_one.errors=0`
- `compile_one.warnings=0`

The compile refreshed the tracked EX5 and replaced the setfile's pending build
hash with the source-bound hash. Post-refresh SHA-256 values:

- MQ5: `c245bdc262f7d4c8ce0e70171ea852919765eb299a278eaab4b607c2a0b78424`
- EX5: `ecf32d9d273aee8d11cd81c85f323df99f675406fd0c3c0f84307877ce2512b3`

The backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## CPU ceiling stop

The required one-pass smoke command was attempted with `-Terminal any`,
`-SmokeMode`, the canonical setfile, `EURUSD.DWX`, `D1`, and year 2024. Terminal
resolution rejected it before tester launch:

`status=no_capacity ... Terminal resolution returned no terminal`

No smoke or Q02 backtest was launched. Per the paced-fleet CPU-ceiling rule,
execution stopped without retrying, rewriting strategy logic, or manually
occupying a terminal. The refreshed binary is ready for the next capacity-aware
handoff.

## Capacity recheck at 17:30 UTC

A later paced wake atomically reclaimed the same pending farm task only after
confirming that `QM5_20062` had no open work item and no competing agent task.
The canonical smoke command was submitted once more with the same EURUSD.DWX D1
2024 `RISK_FIXED` setfile. Terminal resolution again returned
`status=no_capacity` before any tester process launched.

The claim was released without changing the EA, rerunning compilation, creating
a build-result artifact, or enqueueing Q02. This remains the highest-diversity
approved forex build ready for the next genuinely available factory slot.

## Safety

No T_Live path, AutoTrading setting, portfolio gate, or live manifest was
touched.
