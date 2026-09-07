# Dukascopy P0 tick-tail probe — governed T1 claim wiring

Date: 2026-09-07
Router task: `a7e1333c-9b06-45de-a6be-f14477b5f78b`
Disposition: `READY_FOR_OWNER_RUN` / `REVIEW_REQUIRED`
Production run: `NOT_RUN_BY_DESIGN`

## Outcome

The repository now contains a governed, read-only T1 utility route that can
inventory the first and last custom-symbol tick and the final-day tick count for
the exact 37-symbol `.DWX` universe. It produces the requested canonical CSV and
a JSON receipt under a new direct child of
`D:/QM/reports/dukascopy/splice/<YYYYMMDD_HHMMSS>/`.

No queue row was created and no production probe was run in this task. The
factory was administratively off at verification time, and the task explicitly
reserves the first production invocation for the CEO after review of this new
claim type.

## Governed route

The route is sealed by these exact values:

- work-item kind: `diagnostic`
- operator-facing phase: `Q00`
- pseudo EA identity: `QM_DIAG_DWX_TICK_TAIL`
- contract: `qm.dwx-tick-tail-probe-work-item/v1`
- allowed terminal: `T1` only
- completion verdict: `REVIEW_REQUIRED`; never `PASS`, never pipeline admission

The resident terminal worker claims the row through the ordinary serialized
factory claim. It expands the claim's history dependency to all 37 `.DWX`
symbols, but routes the exact diagnostic contract before ordinary setfile, EX5,
EA-registry, history-copy, and strategy-gate handling. The legacy dispatcher
observes an active row but cannot independently launch or classify it.

The worker launches the Python wrapper inside its Windows Job object. The
wrapper then:

1. revalidates the active work-item ID, exact T1 claim, payload hashes, output
   scope, and `FACTORY_OFF` interlock;
2. runs a read-only custom-history isolation audit and records the signed
   archive inventory before launch;
3. compiles the read-only MQL5 script with
   `D:/QM/mt5/T1/MetaEditor64.exe` into a unique run directory;
4. launches only `D:/QM/mt5/T1/terminal64.exe /portable /config:<exact ini>`
   with `Enabled=0`, `AllowLiveTrading=0`, and `AllowDllImport=0`;
5. identifies and terminates only the T1 process matching the exact executable,
   config path, PID, and creation time;
6. repeats the isolation/archive inventory and accepts output only when it is
   unchanged and all 37 rows validate.

The MQL5 program uses only `SymbolSelect`, `SymbolInfo*`, `CopyTicks`, and
`CopyTicksRange` for symbol/history access. Static validation rejects trading
APIs and all `CustomTicks*`, `CustomRates*`, and custom-symbol mutation APIs.

## Output contract

`tick_tail.csv` has exactly one lexicographically ordered row per canonical
symbol and this exact schema:

```text
symbol,last_tick_time_msc,last_tick_utc,last_tick_bid,last_tick_ask,tick_count_last_day,first_tick_time_msc,source_terminal,probe_sha256
```

The millisecond values remain the Darwinex broker-wall epoch. `last_tick_utc`
is derived with `qm.dst_rule.us.v1`: UTC+3 during US DST, UTC+2 otherwise, with
the repeated November wall hour deterministically resolved to standard time.
Every row has a canonical SHA-256 binding. The final validator requires exact
37-symbol coverage, positive finite bid/ask values, a positive final-day tick
count, `source_terminal=T1`, consistency with the P0 M1 first/last years, and an
unchanged signed archive inventory.

## Bound inputs

- P0 ranges: `docs/ops/evidence/2026-09-02_dukascopy_p0_history_ranges.csv`
  - SHA-256: `023f955337a24c16e47e354ca9ce431ace0bd2660d62cfcdc3a36b6e95ba0c4b`
  - exact M1 rows: 37
  - observed first years: 2017, 2018
  - observed last years: 2025, 2026
- symbol matrix: `framework/registry/dwx_symbol_matrix.csv`
  - SHA-256: `e7844d9a18db8723db2b31d839581d0cc348140cf883200524a1af26d465821d`
- OWNER-approved archive manifest:
  `D:/QM/strategy_farm/artifacts/ops/custom_history_custom_history_variant_a_20260809/archive_manifest_owner_approved.json`
  - SHA-256: `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`
  - archive years: 2017–2025

The dry-run planner successfully selected signed archive rows for every one of
the 37 symbols.

## Verification

- Python syntax compile: PASS for the wrapper, enqueue/validation module,
  `farmctl.py`, and `terminal_worker.py`.
- New focused suite: `10 passed`.
- Adjacent worker/history/Job containment regression suite: `56 passed`.
- Isolated T1 MetaEditor compile: exit code `1` (MetaEditor success convention),
  `0 errors`, `0 warnings`, 454 ms; EX5 SHA-256
  `d1af5ebd5ddd9086d34608bbafd02ca40f11402788f5804f95a80ef110503d3c`.
- Live-input planner dry-run: PASS at stamp `20260907_180940`.
- Post-dry-run checks: `FACTORY_OFF=true`, output directory absent, open
  `diagnostic/Q00` rows = 0.
- Production downloads: not started.
- `terminal64.exe`: not started during verification.

Machine-readable verification and source bindings are in
`wiring_receipt.json` beside this README.

## OWNER handoff after review

Use the planner without `--apply` first, substituting one fresh UTC stamp:

```powershell
python C:/QM/repo/tools/strategy_farm/dwx_tick_tail_probe_work_item.py --root D:/QM/strategy_farm --stamp <YYYYMMDD_HHMMSS> --authority-task-id a7e1333c-9b06-45de-a6be-f14477b5f78b
```

After the normal operator-controlled Factory-ON procedure, and only if T1 is
idle and the dry-run remains valid, the CEO may enqueue that exact plan by
adding `--apply`. The resident T1 worker owns the launch. Do not invoke the
wrapper or `terminal64.exe` directly.

Expected durable production artifacts are:

- `D:/QM/reports/dukascopy/splice/<stamp>/tick_tail.csv`
- `D:/QM/reports/dukascopy/splice/<stamp>/probe_receipt.json`
- `D:/QM/reports/work_items/<work_item_id>/QM_DIAG_DWX_TICK_TAIL/Q00/summary.json`

Only a reviewed production receipt may unblock the separate P1 download work.
