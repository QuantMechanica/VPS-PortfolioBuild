# Q09 pilot b2468d2e append-only successor

Date: 2026-08-22  
Scope: `QM5_11294` / `XAUUSD.DWX` / Q09  
Disposition: successor sealed and runnable; failed predecessor preserved

## Result

- Failed predecessor `b2468d2e-92a5-4fd8-a6ae-29967da0ca08` remains `failed / INFRA_FAIL` with verdict reason `summary_missing:launch_fault`. No predecessor field or verdict was changed.
- The governed enqueue command had already created append-only successor `ba24e7a3-4edf-4dc1-b74d-5854a6b5ecf2` at `2026-08-22T12:20:14+00:00`. Its payload binds `append_only_rerun_of_work_item=b2468d2e-92a5-4fd8-a6ae-29967da0ca08`, `promoted_from_work_item=d0f55c10-bcaf-414d-ba04-5e1307e5a061`, and `priority_track=true`.
- A new 40-cell plan was generated specifically for successor `ba24e7a3-4edf-4dc1-b74d-5854a6b5ecf2` and bound through `farmctl bind-q09-plan`.
- Plan path: `D:/QM/reports/work_items/ba24e7a3-4edf-4dc1-b74d-5854a6b5ecf2/run_plan.json`
- Plan semantic SHA-256: `5e80d1bd7bc8df56ac6c251d011c035dc3330b2b27e5847414f9e953ccd54099`
- Plan file SHA-256: `ad9b7411e48cd165d70e23c86819b4da53075657d9af63f5ee810af94768999d`
- Binding SHA-256: `ca1cd7e5ab0b8da174040356b1a0c3fc61936f3b1d2b4537f024cf1aae7581f7`
- Binding result: `RUNNABLE_BOUND`, 40 cells, 10,800-second per-cell timeout. The ordinary factory worker owns subsequent execution.

## Why the earlier CLI output showed `requeued: []`

This was an output-field interpretation issue, not an empty enqueue. Event `373639` (`cascade_backtest_enqueued`, `2026-08-22T12:20:15+00:00`) records successor `ba24e7a3-4edf-4dc1-b74d-5854a6b5ecf2` under `created`, with `rerun_of_work_item_id=b2468d2e-92a5-4fd8-a6ae-29967da0ca08`; the same event correctly records `requeued: []` and `skipped: []`.

The append-only branch in `farmctl.enqueue_backtest_for_ea` inserts a new immutable row and appends it to `created`. It does not mutate/requeue the terminal predecessor, so an empty `requeued` array is expected. No duplicate successor was created.

## Receipt carry-forward authentication

The runner contract authenticates a cell receipt against the planned run identity, paired-base identity, arm, temporal mode, compliance mode, requested/effective seed, generated setfile hash, report hash, evidence hash, and evidence bindings. It does not bind a cell receipt to a work-item ID.

Verification performed before carry-forward:

- The predecessor and successor plans have the same 40 cell keys.
- All 40 `run_identity_sha256`, `paired_base_identity_sha256`, and `setfile_sha256` values match between plans.
- The runner's own `_receipt_to_cell` validator authenticated all 23 predecessor receipts, including their referenced report/evidence artifacts.
- Only those 23 `cell_receipt.json` files were copied to the corresponding successor cell directories. No failure sidecars or work-item-bound files were copied.
- The copied files are byte-identical to their authenticated source receipts.
- A second `_receipt_to_cell` pass against the successor plan authenticated all 23 carried receipts; 17 cells remain absent and will be computed normally.

This is receipt reuse under an identical experiment identity, not receipt synthesis or alteration.

## Terminal reservation check

At binding time `D:/QM/strategy_farm/state/terminal_reservations.json` reserved T3 for `run_smoke_custom_history_admission` until `2026-08-22T16:40:35.291269+00:00`. The ordinary terminal worker checks `farmctl.terminal_reservation(...)` before claim and returns `terminal_reserved`, so the successor cannot claim the smoke-reserved T3 while that reservation is live. The successor was not dispatched manually.

## Guardrails

- No terminal was started or interrupted.
- No pipeline verdict was asserted.
- No predecessor verdict or historical evidence was overwritten.
- No live-trading or AutoTrading state was touched.
