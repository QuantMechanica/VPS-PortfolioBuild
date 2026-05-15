# QUA-1541 Heartbeat Evidence - 2026-05-15T05:10_TEST_RUNONCE.md

## Scope
- Issue: `QUA-1541` (MT5 multi-EA saturation scheduler)
- Action: add integration-style unit test for `run_once` orphan recovery metrics contract

## File Updated
- `C:\QM\paperclip\tools\ops\tests\test_multi_ea_scheduler.py`

## New Test
- `test_run_once_emits_orphan_recovery_metrics`
  - injects stub `framework.scripts.mt5_saturation_scheduler.run_tick`
  - injects stub `framework.scripts.pipeline_dispatcher.load_dispatch_state`
  - injects stub `lib.paperclip_api.PaperclipClient`
  - executes `run_once` with `recover_orphan_dispatched=True`
  - asserts `orphan_recovery` metrics are present and consistent (`candidate_count=1`, `recovered_count=1`, `candidate_row_ids=[1]`)
  - asserts evidence JSON persists `orphan_recovery.recovered_count=1`

## Verification
Command:
```powershell
python -m unittest C:\QM\paperclip\tools\ops\tests\test_multi_ea_scheduler.py -v
```
Result:
- `Ran 5 tests`
- `OK`

## Next Action
- If desired, add one additional test that exercises `--recover-orphan-dispatched` through CLI parse + `main()` one-shot with monkeypatched `run_once` for argument wiring coverage.
