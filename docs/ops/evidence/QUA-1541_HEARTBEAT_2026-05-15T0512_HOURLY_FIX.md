# QUA-1541 Heartbeat Evidence - 2026-05-15T0512_HOURLY_FIX.md

## Scope
- Issue: `QUA-1541` (MT5 multi-EA saturation scheduler)
- Action: fix production crash path observed in hourly wrapper and verify scheduler RC returns to 0

## Problem Observed
Hourly log showed intermittent failure:
- `json.decoder.JSONDecodeError ... dispatch_state.json`
- done line: `multi_ea_scheduler=1`

## Code Fix
Updated:
- `C:\QM\paperclip\tools\ops\multi_ea_scheduler.py`

Change:
- `_normalize_dispatch_state(...)` exception guard widened from `except JSONDecodeError` to `except Exception`.
- Behavior remains safe-reset to baseline state:
  - `{"running": {}, "recent_runs": {}}`

## Test Hardening
Updated:
- `C:\QM\paperclip\tools\ops\tests\test_multi_ea_scheduler.py`

Added test:
- `test_normalize_dispatch_state_recovers_unreadable_bytes`

Verification:
```powershell
python -m unittest C:\QM\paperclip\tools\ops\tests\test_multi_ea_scheduler.py -v
```
Result:
- `Ran 7 tests`
- `OK`

## Runtime Verification
Executed:
```powershell
cmd /c C:\QM\paperclip\tools\ops\cron\hourly_status.bat
```
Latest log done-lines now show:
- `sync_from_paperclip=0 escalation_check=0 multi_ea_scheduler=0 mt5_queue_status=0 publish_dashboard_routes=0`

Scheduler payload in same log includes orphan recovery fields and no exception trace.

## Next Action
- Keep this guard in place and monitor next scheduled hourly tick for another clean `multi_ea_scheduler=0` line before considering issue closeout.
