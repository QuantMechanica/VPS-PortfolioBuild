# DWX M1 overlap canonicalization failure isolation

Date: 2026-09-11
Router task: `6bbbf070-2945-4512-9d69-9c7782a5fbec`
Parent task: `3032534e-eaf0-5b68-b09f-2127ebb315b0`
Disposition: `REVIEW`
Scope: Python build, focused tests, and evidence only

## Outcome

`framework/scripts/mt5_diagnostics/dwx_m1_overlap_export.py::canonicalize_export_set`
now isolates `ValueError` per symbol. An empty export, schema mismatch, invalid
row, or reconciliation-reader compatibility failure no longer prevents later
symbols in the exact 37-symbol universe from being attempted.

Every raw CSV is still copied before canonicalization. Successful symbols retain
the existing file binding in `files`. Failed symbols are excluded from `files`
and recorded in `dwx_m1_manifest.json` as ordered objects containing exactly
`symbol` and `reason`. If a compatibility failure happens after a final CSV was
installed, that failed final CSV is removed so `dwx_m1/` contains successful
canonical outputs only.

The manifest binding, `export_receipt.json`, and `summary.json` now expose:

- `canonicalization_status`: `COMPLETE`, `PARTIAL`, or `NOT_RUN` at receipt level;
- attempted, successful, and failed symbol counts;
- the complete `failed_symbols` list with a reason for each symbol.

A partial canonicalization is deliberately not admissible. The overall receipt
status remains `FAIL`, the summary verdict remains `INFRA_FAIL`, and
`tools/strategy_farm/dwx_m1_overlap_export_work_item.py::validate_summary` plus
its exact-37-file manifest contract were not changed.

## Real Q00 incident reproduced

The defect was exposed by governed T1 work item
`bb3d2f7f-282b-4321-807f-31c01ed936fb`, export stamp
`20260911_010423`:

- MT5 completion marker: `successes=25 failures=12 terminal=T1 build=6182
  total_rows=1735391`.
- The terminal output directory contains all 37 raw CSVs: 25 contain data and 12
  are header-only.
- The old Python loop copied only `AUDCAD.DWX_M1.csv` and
  `AUDCHF.DWX_M1.csv` into `raw/`, produced one final `AUDCAD.DWX` CSV, then
  stopped on alphabetical symbol 2 with
  `ValueError: raw M1 export is empty: AUDCHF.DWX`.
- The remaining 35 symbols were never attempted, so the old summary had
  `m1_export_manifest=null` and could identify only the first failure.
- The signed archive was unchanged according to the run receipt.

The 12 preserved header-only inputs are:

`AUDCHF.DWX`, `EURJPY.DWX`, `EURUSD.DWX`, `GBPCAD.DWX`, `GBPNZD.DWX`,
`GBPUSD.DWX`, `GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `USDJPY.DWX`,
`WS30.DWX`, and `XNGUSD.DWX`.

Evidence bindings for the incident:

- receipt:
  `D:/QM/reports/dukascopy/reconciliation_inputs/dwx_m1/20260911_010423/export_receipt.json`
  (`b5c9d1ac6fe4609563bb84ba8bb4a1b8a2330b188e9057bb3f0e089c54c2de3a`)
- summary:
  `D:/QM/reports/work_items/bb3d2f7f-282b-4321-807f-31c01ed936fb/QM_DIAG_DWX_M1_OVERLAP/Q00/summary.json`
  (`0d3066e964ba2706e489d45202fdee76324fdec07ba6cc04a2677ff1970c9a6a`)

## Verification

- Focused test module:
  `python -m pytest tools/strategy_farm/tests/test_dwx_m1_overlap_export.py -q`
  -> `13 passed`.
- The new 37-file fixture makes `AUDCHF.DWX` header-only while keeping valid
  symbols before and after it alphabetically. It proves 37 attempts, 36
  successes, one recorded failure, successful neighbors retained, all 37 raw
  copies present, and no failed final CSV.
- The fixture passes its partial manifest to the unchanged governed manifest
  validator and proves it is rejected with `M1 export manifest contract
  mismatch`.
- An offline canonicalizer-only replay against the preserved real raw directory
  attempted 37 symbols and returned `PARTIAL`, 25 successes, 12 failures, 25
  final file bindings, and all 37 raw copies. The reported failure list exactly
  matched the 12 header-only inputs above. Replay output lived under a guarded
  system temporary directory and was removed after inspection.
- `git diff --check` passed for both changed Python files.

Changed-file SHA-256 bindings before commit:

- `framework/scripts/mt5_diagnostics/dwx_m1_overlap_export.py`:
  `eb941dc890bfcb8917f89a99678ed855bf52507983228afc16e1b995495e7707`
- `tools/strategy_farm/tests/test_dwx_m1_overlap_export.py`:
  `256cf1d585d9b9296c880fb1a9e36034fe836e1022d294b309dd1ed303b00559`

## Safety boundary

No `.mq5` file changed, so no MetaEditor compile was required. This task did not
enqueue or dispatch another Q00 export, start or interrupt a terminal, alter
Factory state, touch `T_Live` or AutoTrading, call a `Custom*`/trading API,
change a reconciliation criterion, or issue a pipeline verdict.
