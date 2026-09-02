# DL-089 Q12 binding reconciliation — QM5_10706 / GBPUSD

Date: 2026-09-02
Task: `0058a401-29c0-4042-826c-17dd737ef3cb`
Authority: CEO mandate 2026-09-02; append-only queue/binding hygiene only

## Incident and root cause

The live program `DL089_QM5_10706_GBPUSD_DWX_2019_2025` had 1,085
`OPT_CENSUS` rows. All rows retained their original, internally consistent
binding:

- Q12 owner / `parent_task_id`: `1a92b33e-e34f-532e-80b3-e0144f3b3755`
- Q12 declaration SHA-256:
  `6dd542a2302ec5ee866c3c12e2509e200b15c6904f1e1d196c5451685c2bc49b`
- cell population: 292 done, 793 pending

A second Q12 PATTERN row,
`2dad5730-30ed-5ab1-ace1-d5db4ede60db`, was created from
`QM5_10706_tv-mon-ls_GBPUSD.DWX_H1_backtest_ablation_02.set`. Both Q12 rows
produce the same deterministic program ID and the same 1,085 cell UUIDs.
During one service pass the original row was maintained, then the newer row
entered `_materialize`. `opt_census.enqueue` wrote the shared ledger before its
idempotent cell inserts discovered that every UUID already existed. The inserts
therefore changed no row, but the ledger and registration were left bound to
the newer row and its declaration SHA-256
`411498eff0abccffb2f75825bf1801b25ac1b48bfa38b4a59fe57c6cd6ffd088`.
Lane preflight correctly rejected the ledger/cell disagreement.

## Repair and prevention

The matrix service now treats existing census cells as the durable
owner-of-record. Before materialization it verifies the program's exact 1,085
cell UUID/key set, `parent_task_id`, payload Q12 binding, declaration hash, and
ledger cell set. A different Q12 owner is refused before any artifact write
with machine reason `PROGRAM_Q12_REBIND_REFUSED`. A mismatched ledger can be
re-stamped only from the Q12 row already proven by every persisted cell.

The orphan ablation-sourced Q12 row is recorded in canonical
`work_item_supersedes` with the confirmation-sourced row as successor. No work
item status, verdict, sealed criterion, or terminal state is edited.

## Verification

- Focused service tests:
  `python -m pytest tools/strategy_farm/tests/test_dl089_matrix_service.py -q`
  -> `13 passed` (latest focused run: 13.42s). Targeted `compileall` also
  completed successfully.
- Canonical supersession dry-run identified `2dad5730` as pending with no
  verdict and `1a92b33e` as its valid successor. Apply recorded
  `source_encoding=operator:record` at `2026-09-02T12:56:42+00:00`. The
  automatic pre-write backup is
  `D:/QM/strategy_farm/state/backups/farm_state_before_supersedes_20260902T125618Z.sqlite`
  with SHA-256
  `59abf536e91ee9b699577d1c094cfcc1b2bc85edcf50672e8e8df435fb2c1e11`.
- Targeted matrix service apply for `1a92b33e` reported
  `RESTAMPED_FROM_CELL_OWNER`, `existing=1085`, `inserted=0`, and preserved the
  292 done / 793 pending cell population. Both `ledger.json` and
  `runner_registration.json` now bind Q12 `1a92b33e` and declaration
  `6dd542a2302ec5ee866c3c12e2509e200b15c6904f1e1d196c5451685c2bc49b`.
- Priority-track dry-run and apply each selected exactly 793 pending rows; the
  apply changed all 793 back to `priority_track=true` with reason
  `DL089_Q12_BINDING_RECONCILED_TASK_0058a401`.
- At `2026-09-02T12:57:55+00:00`, resident worker T1 claimed cell
  `8cccde6d-f248-5c1c-9e62-3ea319b3d36c`
  (`...:2019:buy_093`). The durable worker log records
  `dl089_lane_preflight_status="checked"`, program ID
  `DL089_QM5_10706_GBPUSD_DWX_2019_2025`, and arm `buy_093` at
  `D:/QM/strategy_farm/logs/terminal_worker_T1.log:561`.
- A live service dry-run targeted at the superseded `2dad5730` row returned no
  maintained/materialized owner and the expected
  `PROGRAM_Q12_REBIND_REFUSED` machine reason while four repaired-program
  census cells were active.

No terminal was started or interrupted, and no `T_Live` / AutoTrading state
was changed. The claim was made naturally by the already-running worker fleet.
