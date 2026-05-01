# QUA-685 D4 — Registry-to-Dispatch Integration (2026-05-01)

Integrated canonical DWX registry directly into P2 matrix payload generation.

## Change

- Updated `infra/scripts/build_p2_dispatch_matrix.py`:
  - New input mode: `--matrix-csv framework/registry/dwx_symbol_matrix.csv`
  - Validation: requires `symbol` + `canonical_name_verified` columns
  - Enforces `canonical_name_verified=true` for every emitted symbol
  - Keeps strict `.DWX` + duplicate checks

## Verification

1. `python -m py_compile infra/scripts/build_p2_dispatch_matrix.py` => PASS
2. Payload generated from registry CSV:
   - `.scratch/qua685_p2_matrix_dispatch_from_registry_2026-05-01.json`
   - symbol count: `36`
   - includes `NDXm.DWX`, `GDAXIm.DWX`
   - excludes `XBRUSD.DWX`, `NDX.DWX`, `GDAXI.DWX`
3. Dispatcher acceptance check:
   - `resolve_backtest_target.py --event start` with scratch state files
   - result: `matrix_count=36`, `scheduled=15`, `no_capacity=21`, `duplicate=0`

## Next action

Use `--matrix-csv framework/registry/dwx_symbol_matrix.csv` as the default D4-compliant payload source for all future P2 matrix start events.
