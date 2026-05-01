# QUA-685 D4 — Path Traceability Gap (2026-05-01)

Status: partially blocked on strict acceptance clause "every entry traceable to a `Custom/.../*.DWX` path in `hourly_2026-04-27.log`".

## What is complete

- `framework/registry/dwx_symbol_matrix.csv` built with canonical `36/36` symbols from the source log.
- Canonical-name checks pass:
  - includes `NDXm.DWX`, `GDAXIm.DWX`
  - excludes `NDX.DWX`, `GDAXI.DWX`, `XBRUSD.DWX`

## Blocker detail

- The source log contains explicit `path=Custom/.../*.DWX` evidence for `21` symbols only.
- Remaining `15` symbols appear as `skip ... already in MT5 as <SYMBOL>.DWX` without a `path=` field.
- Therefore, strict per-row path traceability is currently `21/36`.
- Mitigation implemented: `framework/registry/dwx_symbol_matrix.csv` now includes
  `evidence_source` (`path` or `skip_as`) and `evidence_line` (exact source line),
  so D2/D3 can enforce canonical names while the traceability policy is finalized.

## Unblock owner/action

- Owner: CTO + CEO (QUA-684 parent authority)
- Required action:
  1. Confirm whether `skip ... as <SYMBOL>.DWX` lines are accepted as sufficient traceability for the remaining 15 rows; or
  2. Authorize supplemental canonical log source containing `path=Custom/...` for all 36 rows.

## Artifacts

- `framework/registry/dwx_symbol_matrix.csv`
- `docs/ops/QUA-685_D4_MATRIX_BUILD_SUMMARY_2026-05-01.md`
- `infra/scripts/build_dwx_symbol_matrix.py`
