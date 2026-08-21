# MNT-035 — single health and operating-intent contract

Date: 2026-08-21  
Router task: `f5bbd3a9-e6fc-4bab-a58d-ab216d616eb8`  
Branch: `agents/board-advisor`

## Verdict

`IMPLEMENTED_FOR_REVIEW`

Farm health, the silent-failure monitor, the DXZ live-book pulse, the FTMO
trial pulse, and the hourly scheduled-task monitor now publish or consume
`qm.health.contract.v1`. Every check carries the established
`name/status/value/threshold/detail/action_hint` fields, source/layer metadata,
and an explicit operating-intent object where applicable. Aggregation is
worst-severity-wins.

The intent layer accepts only `RUNNING`, `PARKED`, or `MAINTENANCE`:

- `PARKED` plus absent is `OK`.
- `PARKED` plus running is `FAIL` and is observation-only; no monitor stops it.
- planned `MAINTENANCE` is visible as `WARN`, not a false outage or green state.
- an unknown process probe, invalid intent, or expired intent review is `FAIL`.
- unknown producer severity fails closed instead of disappearing from summary.

The farm-health writer reads the four observer sidecars and publishes their
checks in its one payload. Missing or stale sidecars become transport-layer
checks rather than implicit clean results. The task-monitor sidecar is written
atomically by the existing hourly monitor; the script retains its maintenance
quiescence guard and never changes live/factory intent.

## Historical contradiction fixtures

`tools/strategy_farm/tests/fixtures/mnt035_health_contradictions.json` fixes the
previously disagreeing cases as durable inputs:

1. parked and absent;
2. parked but running;
3. maintenance while absent;
4. unknown runtime probe;
5. expired intent while running;
6. invalid intent;
7. base health green while a live surface alarms (worst severity must win).

Before this change, the FTMO short-circuit returned `OK` for maintenance while
the silent monitor returned `WARN`; pulse alarms used `ALARM` while farm health
only counted `FAIL`; and unknown status text could be omitted from the farm
summary. The fixture suite locks the unified outcomes.

## Verification

```text
python -m pytest \
  tools/strategy_farm/tests/test_mnt035_health_contract.py \
  tools/strategy_farm/tests/test_silent_failure_live_uptime.py \
  tools/strategy_farm/tests/test_ftmo_trial_pulse.py \
  tools/strategy_farm/tests/test_live_book_pulse.py -q

52 passed in 2.02s
```

```text
python -m py_compile tools/strategy_farm/health_contract.py \
  tools/strategy_farm/health.py \
  tools/strategy_farm/silent_failure_monitor.py \
  tools/strategy_farm/ftmo_trial_pulse.py \
  tools/strategy_farm/live_book_pulse.py

pwsh -NoProfile -Command \
  "[void][scriptblock]::Create((Get-Content -LiteralPath \
  'tools/strategy_farm/hourly_monitor.ps1' -Raw)); \
  'hourly_monitor_parse=PASS'"

hourly_monitor_parse=PASS
```

No terminal was started or interrupted, and neither AutoTrading nor `T_Live`
was changed.
