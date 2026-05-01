# QUA-685 D4 — Default Registry Input Activated (2026-05-01)

Run-liveness continuation action completed: `build_p2_dispatch_matrix.py` now defaults to registry CSV input.

## Code change

- File: `infra/scripts/build_p2_dispatch_matrix.py`
- Behavior:
  - If neither `--symbols-file` nor `--matrix-csv` is provided, script now defaults to:
    - `framework/registry/dwx_symbol_matrix.csv`

## Concrete execution evidence

Executed without explicit symbol-source flags:

```powershell
python infra/scripts/build_p2_dispatch_matrix.py --out-json .scratch/qua685_p2_matrix_dispatch_default_registry_2026-05-01.json --ea-id QM5_1003 --version v1 --phase P2 --sub-gate-config-hash H1-2024
```

Result:
- output: `.scratch/qua685_p2_matrix_dispatch_default_registry_2026-05-01.json`
- symbols: `36`
- includes: `NDXm.DWX`, `GDAXIm.DWX`
- excludes: `XBRUSD.DWX`

This makes registry-backed input the operational default for D4-compliant P2 matrix starts.
