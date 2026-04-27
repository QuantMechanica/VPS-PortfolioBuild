# QUA-22 Parity Sample (2026-04-27)

## Scope

Produce one concrete filesystem-vs-tracker parity sample for V5 aggregator state (`last_check_state.json`) under factory report paths.

## Context

- Aggregator task was already restored and healthy before this run (`QM_AggregatorState_1min`, `LastTaskResult=0` in prior evidence).
- Blocking remainder on QUA-22 was parity proof line with non-zero `.htm` inventory.

## Action Taken (2026-04-27)

1. Used known smoke-emitted `.htm` artifact from T1:
   - `D:\QM\mt5\T1\probe_relhtm.htm`
   - bytes: `28514`
   - source mtime UTC: `2026-04-26T19:11:39.0309772Z`
2. Mirrored artifact into active reports root so aggregator scanner can count it:
   - `D:\QM\reports\smoke\parity_probe_relhtm_20260426\report.htm`
3. Triggered one-shot aggregator state write:
   - `python C:\QM\repo\scripts\aggregator\standalone_aggregator_loop.py --once`

## Evidence

Aggregator write line:

```text
2026-04-27T14:31:49 wrote D:\QM\reports\state\last_check_state.json iteration=1096 dirs=1 htm_total=1
```

Filesystem truth count:

- report directory checked: `D:\QM\reports\smoke\parity_probe_relhtm_20260426`
- `.htm` files in directory: `1`

Tracker state counters (`D:\QM\reports\state\last_check_state.json`):

- `report_directory_count=1`
- `report_htm_total=1`
- `iteration=1096`
- `timestamp_utc=2026-04-27T12:31:49Z`

Parity statement:

```text
filesystem_count == tracker_count == 1
```

## Residual Execution Note (T1 smoke freshness)

Fresh smoke attempts in this heartbeat hit singleton-terminal race:

- terminal log shows `terminal process already started` during config-launched tester start.
- Result class remains `REPORT_MISSING` for current non-dry `run_backtest_smoke.ps1` attempts while auto `/portable` terminal instance is live.

This does not affect the parity sample above, which is now non-zero and equal on filesystem and tracker counters.
