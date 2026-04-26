# Aggregator Scripts

## `standalone_aggregator_loop.py`

V5 standalone state writer for `last_check_state.json`.

- Writes state atomically with lock-file and stale-lock cleanup.
- Writes heartbeat for monitoring (`C:\QM\logs\aggregator\heartbeat.txt`).
- Scans `D:\QM\reports` recursively for `.htm` report directories and counts.
- Detects scanner and terminal PIDs for T1-T5 only.
- Hard-excludes T6 roots (`C:\QM\mt5\T6_*`, `D:\QM\mt5\T6_*`).
- No `push_status.py` integration.
- No V4 T3 disk-pause policy block.

### One-shot run

```powershell
python C:\QM\repo\scripts\aggregator\standalone_aggregator_loop.py --once
```

### Loop mode (manual)

```powershell
python C:\QM\repo\scripts\aggregator\standalone_aggregator_loop.py --interval-sec 60
```

### Scheduler install (recommended)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-AggregatorStateTask.ps1
```
