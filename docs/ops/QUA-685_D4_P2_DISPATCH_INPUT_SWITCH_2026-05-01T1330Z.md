# QUA-685 D4 P2 dispatch input switch (2026-05-01T13:30Z)

Implemented the wake instruction by switching P2 matrix dispatch input to canonical import-log output.

## Canonical input now used

- `C:\QM\repo\.scratch\qua685_canonical_symbols_from_hourly_2026-04-27.txt`

## New deterministic builder

- `C:\QM\repo\infra\scripts\build_p2_dispatch_matrix.py`
- Purpose: read canonical symbol file, enforce `.DWX`/dedup/count checks, emit matrix payload for `resolve_backtest_target.py`.

## Produced dispatch payload

- `C:\QM\repo\.scratch\qua685_p2_matrix_dispatch_2026-05-01.json`
- `matrix_count=36`
- Includes canonical symbols (`GDAXIm.DWX`, `NDXm.DWX`, `XNGUSD.DWX`) and excludes invalid legacy symbols.

## Verification (minimal, concrete)

1. `python -m py_compile infra/scripts/build_p2_dispatch_matrix.py` -> pass
2. Built payload from canonical list -> pass
3. Dry dispatch against scratch state files:
   - Command used `framework/scripts/resolve_backtest_target.py --event start`
   - Result: `scheduled=15 duplicate=0 no_capacity=21` at default `max_per_terminal=3` (expected capacity behavior)

## Next action

Use `.scratch/qua685_p2_matrix_dispatch_2026-05-01.json` as the only matrix input for the next live P2 dispatch cycle.
