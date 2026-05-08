# QUA-909 heartbeat evidence (2026-05-08, live sample attempts)

## Mandatory heartbeat action
- Ran `python next_task.py --agent cto --json` (Kanban contract satisfied).

## Live (non-mock) driver attempts

### P5 (`p5_stress_driver.py`)
- Attempted with real EA/symbol/setfile and calibration.
- First failure: `run_smoke.ps1` rejected because terminal T1 was already running.
- Patched driver to support `--allow-running-terminal` passthrough.
- Retry then exceeded local heartbeat command timeout before smoke completion.
- Artifact confirmed:
  - `D:/QM/reports/pipeline/QM5_1003/P5/QM5_1003_EURUSD_P5_STRESS.set`

### P5b (`p5b_noise_driver.py`)
- Executed successfully (non-mock, real calibration input).
- Artifact confirmed:
  - `D:/QM/reports/pipeline/QM5_1003/P5b/p5b_trials.csv`

### P6 (`p6_multiseed_driver.py`)
- First attempt with `--runs 1` failed due `run_smoke.ps1` contract (`Runs >= 2`).
- Retry with `--runs 2` exceeded local heartbeat command timeout before completion.
- Exposed robustness bug: partial `p6_seeds.csv` could be left behind on interruption.
- Patched driver for atomic CSV write and explicit smoke timeout handling.

## Code hardening completed this heartbeat
- `framework/scripts/p5_stress_driver.py`
  - Added `--allow-running-terminal`
  - Added `--smoke-timeout-seconds`
  - Added explicit timeout error path for `run_smoke` subprocess
- `framework/scripts/p6_multiseed_driver.py`
  - Added `--allow-running-terminal`
  - Added `--smoke-timeout-seconds`
  - Added explicit timeout error path for `run_smoke` subprocess
  - Switched to atomic seeds CSV write (`p6_seeds.tmp.csv` -> `p6_seeds.csv`)

## Verification
- `python -m unittest framework.scripts.tests.test_phase_backtest_drivers` => PASS

## Unblock needed for full live P5/P6 completion
- Owner: Pipeline-Op / DevOps runtime environment
- Action: provide a dedicated idle MT5 terminal window and allow a longer execution window than this heartbeat command timeout for full-year smoke runs.
