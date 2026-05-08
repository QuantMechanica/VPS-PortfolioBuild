# QUA-842 — Pipeline-Op GDAXIm/NDXm cleanup on T2-T5 (DL-059 propagation)

Date: 2026-05-08
Operator: Pipeline-Operator (`46fc11e5-7fc2-43f4-9a34-bde29e5dee3b`)
Scope: remove legacy `NDXm.DWX` / `GDAXIm.DWX` folders from `T2..T5` `Bases\\Custom\\{history,ticks}` while preserving canonical `NDX.DWX` / `GDAXI.DWX`.

## Wake acknowledgment

Heartbeat wake target: `QUA-842 Pipeline-Op: GDAXIm/NDXm Cleanup T2-T5 (DL-059 propagation)`.
Action taken in this heartbeat: executed live filesystem cleanup + verification on T2..T5.

## Pre-cleanup evidence (legacy payload present)

Observed before delete:

- `T2`
- `history\\NDXm.DWX`: missing
- `history\\GDAXIm.DWX`: 9 files, 115,080,122 bytes
- `ticks\\NDXm.DWX`: 95 files, 1,458,992,522 bytes
- `ticks\\GDAXIm.DWX`: 95 files, 293,498,589 bytes

- `T3`
- `history\\NDXm.DWX`: 9 files, 44,521,553 bytes
- `history\\GDAXIm.DWX`: 9 files, 115,080,122 bytes
- `ticks\\NDXm.DWX`: 95 files, 1,783,599,621 bytes
- `ticks\\GDAXIm.DWX`: 95 files, 440,143,062 bytes

- `T4`
- `history\\NDXm.DWX`: 9 files, 44,521,742 bytes
- `history\\GDAXIm.DWX`: 9 files, 115,080,122 bytes
- `ticks\\NDXm.DWX`: 96 files, 1,775,859,965 bytes
- `ticks\\GDAXIm.DWX`: 95 files, 440,143,062 bytes

- `T5`
- `history\\NDXm.DWX`: 9 files, 44,521,553 bytes
- `history\\GDAXIm.DWX`: 9 files, 115,080,311 bytes
- `ticks\\NDXm.DWX`: 95 files, 1,783,599,621 bytes
- `ticks\\GDAXIm.DWX`: 96 files, 432,403,406 bytes

Total legacy bytes removed (T2..T5): `8,888,125,373` bytes (~8.28 GiB).

## Actions executed

Deleted these legacy directories on each of T2, T3, T4, T5:

- `D:\QM\mt5\<Tn>\Bases\Custom\history\NDXm.DWX`
- `D:\QM\mt5\<Tn>\Bases\Custom\history\GDAXIm.DWX`
- `D:\QM\mt5\<Tn>\Bases\Custom\ticks\NDXm.DWX`
- `D:\QM\mt5\<Tn>\Bases\Custom\ticks\GDAXIm.DWX`

## Post-cleanup verification

- Legacy folders `NDXm.DWX` + `GDAXIm.DWX` under `T2..T5` `history/` and `ticks/`: absent.
- Canonical folders `NDX.DWX` + `GDAXI.DWX` remain present.
- Canonical HCC topology unchanged across T2..T5:
  - `NDX.DWX`: 9 `.hcc`, 165,026,271 bytes (each terminal)
  - `GDAXI.DWX`: 9 `.hcc`, 131,872,434 bytes (each terminal)

## Notes

- T1 not modified in this heartbeat (scope was T2..T5 cleanup propagation).
- No active `terminal64`/`robocopy` processes observed during verification snapshot.

## Next action

Run a short delayed re-check in next heartbeat to confirm no external sync job reintroduces legacy folders, then close QUA-842 if stable.

## Continuation 2026-05-08 (post-cleanup verification)

Executed sequential terminal-pinned smoke validation (HR16) for canonical symbols:
- T2: NDX.DWX, GDAXI.DWX
- T3: NDX.DWX, GDAXI.DWX
- T4: NDX.DWX, GDAXI.DWX
- T5: NDX.DWX, GDAXI.DWX

Result matrix: 8/8 FAIL with reason_classes=REPORT_MISSING;INCOMPLETE_RUNS; 0 exported report.htm artifacts in each run dir.

Per-terminal receipts:
- docs/ops/QUA-842_T2_GDAXIm_NDXm_cleanup_2026-05-08.md
- docs/ops/QUA-842_T3_GDAXIm_NDXm_cleanup_2026-05-08.md
- docs/ops/QUA-842_T4_GDAXIm_NDXm_cleanup_2026-05-08.md
- docs/ops/QUA-842_T5_GDAXIm_NDXm_cleanup_2026-05-08.md

Blocked-by recommendation: CTO+DevOps to repair tester report export pipeline on T2..T5, then rerun QUA-842 verification matrix.
