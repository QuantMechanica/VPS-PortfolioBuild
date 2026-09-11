# Dukascopy P3 unblock — governed T1 DWX M1 overlap export

Date: 2026-09-11
Router task: `ba2a478e-f437-404b-843b-a1def6f2cf4c`
Parent task: `3032534e-eaf0-5b68-b09f-2127ebb315b0`
Disposition: `REVIEW`
Production run: `NOT_RUN_BY_DESIGN`

## Outcome

The canonical repository now contains a governed, read-only T1 diagnostic that
exports one M1 OHLC/tick-volume CSV per symbol for the exact 37-symbol `.DWX`
universe. The requested inclusive window is fixed at
`2025-10-01T00:00:00Z` through `2026-04-01T00:00:00Z`, which contains the
November 2025 US-DST end and March 2026 US-DST start transition weeks.

The MQL5 script reads only T1's existing imported custom-symbol history. It
retrieves synchronized weekly `CopyRates` chunks, verifies each chunk against
the corresponding `Bars` count, and writes one row for every available M1 bar.
The Python wrapper converts Darwinex GMT+2/+3 broker-wall epochs to UTC ISO-8601
timestamps and emits the exact header:

```text
time,open,high,low,close,tickvol
```

`tools/dukascopy/reconcile_overlap.py::read_m1_csv` now accepts those explicit
UTC ISO values while retaining its existing numeric broker-epoch input. ISO
values are normalized back to the Darwinex broker epoch before the unchanged P3
comparison logic runs. No reconciliation threshold or gate criterion changed.

No factory work item was enqueued and no production export was run. In
particular, this build did not start `terminal64.exe`, import or download data,
touch `T_Live`, change AutoTrading, or emit a pipeline verdict.

## Governed route

The route is sealed by these values:

- work-item kind: `diagnostic`
- operator-facing phase: `Q00`
- pseudo EA identity: `QM_DIAG_DWX_M1_OVERLAP`
- contract: `qm.dwx-m1-overlap-export-work-item/v1`
- allowed terminal: `T1` only
- `diagnostic_non_admission=true`
- `no_gate_verdict=true`
- `read_only=true`
- `priority_track=true`, `diagnostic_queue_rank=0`
- completion verdict: `REVIEW_REQUIRED`; never a strategy PASS or pipeline
  admission

The resident T1 worker claims and serializes the row through the ordinary
factory claim. The wrapper is spawned inside the worker's Windows Job object,
revalidates the active work-item and source hashes, compiles the MQL5 source,
and permits only the exact T1 executable/config identity. Its startup config
sets `Enabled=0`, `AllowLiveTrading=0`, `AllowDllImport=0`, and
`ShutdownTerminal=0`. It identifies and terminates only the process it owns.

Before and after a governed future run, the wrapper performs the same
custom-history isolation audit and OWNER-signed 2017–2025 archive inventory used
by the tick-tail probe. A successful result requires the signed inventory to be
identical. Static validation rejects every `Custom*` call and the trading APIs
covered by the established diagnostic denylist. The MQL5 source contains no
network or import path.

## Durable production output contract

A separately authorized future enqueue will write a new immutable child of:

```text
D:/QM/reports/dukascopy/reconciliation_inputs/dwx_m1/<stamp>/
```

The child contains:

- `dwx_m1/<SYMBOL>.DWX_M1.csv` for all 37 canonical symbols;
- `raw/` copies of the numeric broker-epoch MQL5 output;
- `dwx_m1_manifest.json`, binding every final CSV path, hash, row count,
  first/last UTC timestamp, exact schema, fixed window, P3 parser hash, and the
  existing nine-row `price_scale.csv` contract;
- `export_receipt.json`, compile evidence, pre/post isolation evidence, exact
  process identity, and `signed_archive_unchanged`;
- the worker summary under
  `D:/QM/reports/work_items/<work-item-id>/QM_DIAG_DWX_M1_OVERLAP/Q00/summary.json`.

The wrapper directly loads every emitted final CSV with
`read_m1_csv` before accepting it. Unit coverage proves this contract for
`EURUSD.DWX` and for `XAUUSD.DWX` using the exact nine-symbol non-FX
`price_scale.csv` schema.

## Bound inputs

- Symbol matrix: `framework/registry/dwx_symbol_matrix.csv`
  - exact rows: 37
  - SHA-256: `e7844d9a18db8723db2b31d839581d0cc348140cf883200524a1af26d465821d`
- P0 M1 history ranges:
  `docs/ops/evidence/2026-09-02_dukascopy_p0_history_ranges.csv`
  - exact M1 rows: 37; all authorize T1
  - SHA-256: `023f955337a24c16e47e354ca9ce431ace0bd2660d62cfcdc3a36b6e95ba0c4b`
- OWNER-approved archive manifest:
  `D:/QM/strategy_farm/artifacts/ops/custom_history_custom_history_variant_a_20260809/archive_manifest_owner_approved.json`
  - archive years: 2017–2025
  - SHA-256: `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`
- Existing governed non-FX metadata:
  `D:/QM/reports/dukascopy/splice/20260909_185632/price_scale.csv`
  - exact rows: 9
  - SHA-256: `b72a05df91da8da053cd066a698a02aeda2930761e990f4f35d379899761fb4d`

## Verification

- Python syntax compile: PASS for the wrapper, enqueuer/validator, P3 parser,
  `farmctl.py`, `terminal_worker.py`, and the focused test module.
- Focused exporter + existing tick-tail + Dukascopy suite: `42 passed`.
- Adjacent atomic-claim, custom-history isolation, Job containment,
  history-isolation, Windows Job, and bootstrap suite: `197 passed`.
- Isolated T1 MetaEditor compile: exit code `1` (MetaEditor success convention),
  `0 errors`, `0 warnings`, 815 ms.
  - compile artifact:
    `D:/QM/reports/dukascopy/build_dry_run/20260911T0000Z_dwx_m1_overlap_ba2a478e`
  - source SHA-256:
    `8dccb744ceaa1510313b5129b17840e4a1994882f72ebb7dc3cc12fb2919ee79`
  - EX5 SHA-256:
    `19ac7a4ed700e26fbbe0c56f292189d1daa3a7fb0e39ebc8b636469dc9b84464`
  - compile-log SHA-256:
    `0770f626b7e98ed77a7524c62dd2d8b8c089568db1b0d16fa3ef156aef8642a1`
- Live-input planner dry-run: PASS for stamp `20260911_002500`.
  - `apply=false`, `enqueued=false`, 37 symbols, T1 only
  - dispatch binding SHA-256:
    `3902e7b0d0b3c45e32b03e0161d7874534db7cc74b98bf1d45d5f700ab821ac5`
  - planned output absent after the dry run
  - matching farm `work_items` rows after the dry run: 0
- MQL5 forbidden-call scan: 0 `Custom*`, trading, or `WebRequest` calls.
- Production `terminal64.exe` launch: none.

Machine-readable bindings are in `wiring_receipt.json` beside this README.

## Review handoff

This ticket stops in `REVIEW`. The first production T1 dispatch is a separate
governed enqueue and is not authorized by this build ticket. A reviewer can
repeat the non-mutating planner proof with:

```powershell
python C:/QM/repo/tools/strategy_farm/dwx_m1_overlap_export_work_item.py --root D:/QM/strategy_farm --stamp <YYYYMMDD_HHMMSS> --authority-task-id <separately-authorized-task-id>
```

Do not add `--apply` without that separate authorization. Do not invoke the
wrapper or `terminal64.exe` directly; the resident T1 worker owns any future
launch.
