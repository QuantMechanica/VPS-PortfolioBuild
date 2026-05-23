# QUA-1541 Heartbeat Evidence - 2026-05-15T05:08:XXZ

## Scope
- Issue: `QUA-1541` (MT5 multi-EA saturation scheduler)
- Action: add unit coverage for orphan-dispatch recovery path

## File Updated
- `C:\QM\paperclip\tools\ops\tests\test_multi_ea_scheduler.py`

## Added Tests
- `test_recover_orphan_dispatched_rows_dry_run_reports_candidate`
  - verifies candidate detection without DB mutation in dry-run mode.
- `test_recover_orphan_dispatched_rows_requeues_row`
  - verifies mutation path sets:
    - `status='queued'`
    - `assigned_terminal=NULL`
    - `dispatched_at=NULL`
    - `dispatch_decision='requeued_orphan'`
    - `last_error` prefixed with `requeued_orphan_dispatch_at_`

## Verification
Command:
```powershell
python -m unittest C:\QM\paperclip\tools\ops\tests\test_multi_ea_scheduler.py -v
```
Result:
- `Ran 4 tests`
- `OK`

## Next Action
- Optional hardening: add integration-style test for `run_once(... --recover-orphan-dispatched ...)` to validate `orphan_recovery` metrics are emitted in evidence JSON.
