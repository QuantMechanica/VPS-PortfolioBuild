# QUA-1541 Heartbeat Evidence - 2026-05-15T0511_CLI_FLAGS.md

## Scope
- Issue: `QUA-1541` (MT5 multi-EA saturation scheduler)
- Action: add CLI argument wiring test for orphan recovery flags

## File Updated
- `C:\QM\paperclip\tools\ops\tests\test_multi_ea_scheduler.py`

## New Test
- `test_parse_args_recognizes_orphan_recovery_flags`
  - verifies `parse_args()` accepts:
    - `--recover-orphan-dispatched`
    - `--orphan-dispatched-minutes <int>`
  - asserts parsed values are correctly mapped into args namespace.

## Verification
Command:
```powershell
python -m unittest C:\QM\paperclip\tools\ops\tests\test_multi_ea_scheduler.py -v
```
Result:
- `Ran 6 tests`
- `OK`

## Next Action
- If needed for closure criteria, run a single hourly wrapper dry execution (`cron/hourly_status.bat`) and capture log snippet proving production command now includes orphan recovery flags.
