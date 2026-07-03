# QM5_12973 FX Q02 Preflight Repair

Date: 2026-07-03

EA: `QM5_12973_eurusd-monthend-fix-fade`

Instrument diversity target: FX (`EURUSD.DWX`, `GBPUSD.DWX`)

## Issue

Both auto-enqueued Q02 work items were still pending but carried stale preflight
metadata from a worker rooted at `C:\QM\worktrees\codex-orchestration-1`.
The preflight evidence reported:

- `reason`: `ea_dir_missing`
- `detail`: `C:\QM\worktrees\codex-orchestration-1\framework\EAs\QM5_12973_*`

The actual compiled EA and setfiles exist under `C:\QM\repo\framework\EAs\QM5_12973_eurusd-monthend-fix-fade`.

## Repair

Ran the farm repair path from `C:\QM\repo`:

```powershell
python tools/strategy_farm/farmctl.py repair
```

The R17 stale-preflight repair cleared the stale payload/evidence markers for:

- `55a51125-1098-4864-8189-a73a40eeec12` (`EURUSD.DWX`)
- `a352e3f4-9004-445e-941f-fd276cbb6f74` (`GBPUSD.DWX`)

Post-repair state:

- `status`: `pending`
- `verdict`: `NULL`
- `evidence_path`: `NULL`
- `claimed_by`: `NULL`
- `cleared_stale_preflight_reason`: `ea_dir_missing`

Current preflight evaluation with the branch code returns `None` for both rows.

## Validation

```powershell
python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12973_eurusd-monthend-fix-fade
pwsh -File framework/scripts/build_check.ps1 -EALabel QM5_12973_eurusd-monthend-fix-fade
```

Results:

- `validate_spec_doc`: PASS
- `build_check`: PASS
- `compile_one`: PASS, `errors=0`, `warnings=0`

The compile refresh updated the EA `.ex5` and the setfile build hashes for the
two Q02 setfiles.

No portfolio gate, T_Live manifest, or AutoTrading state was touched.
