# QM5_12778 Q05 Launch-Fault Retry Requeue - 2026-07-02

Branch: `agents/board-advisor`

## Scope

Mission scope was the FX market-neutral cointegration basket frontier. The
strict scan survivors from
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remain already built as
`QM5_12532` and `QM5_12533`, and neither is currently Q02-blocked.

The local scan frontier has no unbuilt positive-hedge EdgeLab FX
cointegration pair left, so this pass advanced the existing higher-progress
forex basket `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` instead.

## Root Cause Addressed

The latest later-phase FX basket infra failures shared Windows launch exit
code `3221225794` (`0xC0000142`, DLL/process initialization failed). That
failure can terminate `pwsh.exe` before `run_smoke.ps1` writes a summary,
which then gets graded as `summary_missing` or invalid evidence even though
the strategy run never started cleanly.

## Code Change

Added a narrow retry wrapper in `framework/scripts/_phase_utils.py`:

- Retries only `0xC0000142` / signed `-1073741502`.
- Leaves timeouts and normal MT5 strategy failures on the existing paths.
- Uses two attempts with a 30-second backoff.
- Writes a `launch_fault_retry` diagnostic into Q04 fold logs.

The wrapper is now used by the smoke-launch subprocesses in Q04, Q05, Q06,
and Q07.

## Validation

Commands run:

```text
python -m py_compile framework/scripts/_phase_utils.py framework/scripts/q04_walkforward.py framework/scripts/q05_stress_medium.py framework/scripts/q06_stress_harsh.py framework/scripts/q07_multiseed.py
python -m pytest framework/scripts/tests/test_q05_q07_verdicts.py framework/scripts/tests/test_q04_walkforward.py -q
```

Result:

```text
37 passed in 0.35s
```

## Queue Action

Farm DB backup:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12778_q05_launchfault_retry_requeue_20260702T121150Z.sqlite`

Command:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12778 --phase Q05
```

Result:

- `enqueued`: `true`
- `created`: none
- `requeued`: work item `1c0405e7-16d3-40e6-b884-6be1b504dc4c`
- symbol: `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`
- final checked state: `Q05_pending`

## Guardrails

No manual MT5 tester run was launched. `T_Live`, AutoTrading, portfolio gate
files, portfolio admission KPI files, and live deploy manifests were not
touched.
