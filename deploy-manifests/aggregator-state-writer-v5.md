# V5 Aggregator State Writer Deploy Manifest

## Scope

- Issue: `QUA-22`
- Surface: standalone state writer only (`last_check_state.json`)
- Explicitly excluded:
  - `push_status.py` integration
  - T3 disk-pause policy logic
  - T6 Live/Demo scanning

## Path Mapping

- Factory terminals:
  - `D:\QM\mt5\T1`
  - `D:\QM\mt5\T2`
  - `D:\QM\mt5\T3`
  - `D:\QM\mt5\T4`
  - `D:\QM\mt5\T5`
- Reports root: `D:\QM\reports`
- State file: `D:\QM\reports\state\last_check_state.json`
- Heartbeat file: `C:\QM\logs\aggregator\heartbeat.txt`
- Hard exclusions:
  - `C:\QM\mt5\T6_Live`
  - `D:\QM\mt5\T6_Live`
  - `C:\QM\mt5\T6_Demo`
  - `D:\QM\mt5\T6_Demo`

## Run Mode Decision

Chosen mode: Windows Task Scheduler, per-minute one-shot run.

Reason:
- deterministic restart behavior
- bounded execution time per tick
- native overlap guard (`MultipleInstances=IgnoreNew`)
- easy observability through task history + file heartbeat age

## Idempotent Convergence Commands

```powershell
# Register/refresh the task definition
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-AggregatorStateTask.ps1

# Optional immediate one-shot
python C:\QM\repo\scripts\aggregator\standalone_aggregator_loop.py --once
```
