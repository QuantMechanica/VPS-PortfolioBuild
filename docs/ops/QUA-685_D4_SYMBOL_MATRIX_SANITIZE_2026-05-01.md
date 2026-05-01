# QUA-685 D4 — Sanitized .DWX Symbol Matrix (2026-05-01)

Scope: sanitize the P2 `.DWX` symbol matrix using canonical import-log evidence, not hand-maintained lists.

## Canonical source

- Log: `D:\QM\mt5\T1\dwx_import\logs\hourly_2026-04-27.log`
- Extraction rule: parse only lines matching `skip <root>: already in MT5 as <SYMBOL>.DWX`.
- Rationale: these rows are emitted by the hourly importer itself and encode the exact custom-symbol names present in MT5.

## Output artifacts

- Canonical 36-symbol list:
  - `.scratch/qua685_canonical_symbols_from_hourly_2026-04-27.txt`
- Sanitization JSON summary:
  - `docs/ops/QUA-685_D4_SYMBOL_MATRIX_SANITIZE_2026-05-01.json`
- Script used:
  - `infra/scripts/sanitize_dwx_symbol_matrix.py`

## Results (candidate = `.scratch/qua662_done_symbols.txt.INVALID`)

- Canonical count: `36` (expected `36`) => `count_match=true`
- Candidate count: `34`
- Unexpected in candidate (`4`):
  - `GDAXI.DWX`, `JPN225.DWX`, `NDX.DWX`, `XBRUSD.DWX`
- Missing from candidate (`6`):
  - `AUDJPY.DWX`, `GBPJPY.DWX`, `GDAXIm.DWX`, `NDXm.DWX`, `NZDJPY.DWX`, `XNGUSD.DWX`

## Operational next action

Use `.scratch/qua685_canonical_symbols_from_hourly_2026-04-27.txt` as the only allowed matrix input for the next P2 rerun and reject any symbol not present in this file before dispatch.
