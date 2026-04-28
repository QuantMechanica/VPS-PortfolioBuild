# QUA-307 Load Balancer Proof (2026-04-28)

## Scope

Proof that factory backtest launcher paths resolve `target_terminal:any` into concrete `T1..T5` assignments using the new dispatcher policy.

## Code commits

- `9287ff1` — scheduler core (3-cap, dedup, round-robin, affinity)
- `24ddff7` — resolver CLI for live dispatch
- `2e987c3` — hook resolver into `run_backtest_smoke.ps1`
- `a3ed74f` — hook resolver into `run_smoke.ps1` (non-smoke path)
- `492961e` — docs alignment to live state + hooks

## Verification commands

```powershell
python -m unittest C:\QM\repo\framework\scripts\tests\test_pipeline_dispatcher.py
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\framework\scripts\run_backtest_smoke.ps1 -Terminal any -DryRun
python C:\QM\repo\framework\scripts\resolve_backtest_target.py --job-json <job.json> --state-json <dispatch_state.json> --event start
python C:\QM\repo\framework\scripts\resolve_backtest_target.py --job-json <job.json> --state-json <dispatch_state.json> --event complete
```

## Verification results

- Unit tests: `Ran 10 tests ... OK`
- Dry run evidence lines:
  - `run_backtest_smoke.dispatch_status=duplicate`
  - `run_backtest_smoke.dispatch_terminal=T1`
  - Preview command includes `-Terminal T1`
- Completion lifecycle evidence:
  - start event returns `status=scheduled`
  - complete event returns `status=released`
  - persisted `running.<terminal>` returns to `0`

## Runtime state path

- `D:\QM\Reports\pipeline\dispatch_state.json`

## Active launcher hooks

- `framework/scripts/run_backtest_smoke.ps1`
- `framework/scripts/run_smoke.ps1`
- `framework/scripts/resolve_backtest_target.py`

## Notes

- T6 is not referenced by the dispatcher code path and remains out of scope.
- Duplicate dedup keys return the original terminal assignment to keep reruns deterministic.
