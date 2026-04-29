# QUA-415 Pipeline-Operator Handoff

Status: DevOps side complete. This handoff provides the exact co-owner verification path.

## DevOps commits

- `21cc3e6` generator + dispatch refusal
- `fc52012` worked example + deterministic output
- `591e9af` dispatch gate evidence artifact
- `a19c7cf` closeout comment artifact
- `f28df74` dispatcher schema requires `setfile_path`
- `61699e2` changeset manifest + hashes

## Pipeline-Operator verification commands

```powershell
python -m unittest framework.scripts.tests.test_pipeline_dispatcher framework.scripts.tests.test_resolve_backtest_target
```

```powershell
python framework/scripts/resolve_backtest_target.py `
  --job-json artifacts/qua-415_job_missing_set.json `
  --state-json artifacts/qua-415_dispatch_state.json `
  --dedup-index-json artifacts/qua-415_dedup_index.json `
  --event start
```

Expected reject code:

- `BACKTEST_REJECTED_NO_SETFILE`

Worked example set file:

- `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/sets/QM5_SRC04_S03_lien_fade_double_zeros_EURUSD.DWX_H1_backtest.set`

## Required co-owner closeout

- Post Pipeline-Operator workflow confirmation commit hash on QUA-415 issue thread.
