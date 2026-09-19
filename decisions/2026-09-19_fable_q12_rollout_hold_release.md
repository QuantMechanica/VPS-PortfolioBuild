# Decision 2026-09-19 — Re-pin the Q12 restart-hold preparation to Fable authority; prepare (not execute) governed release

- Decision id (pinned payload): `OWNER_DEC_FABLE_Q12_ROLLOUT_RELEASE_20260919`
- Authority: OWNER, delegated to Fable per `decisions/2026-09-17_owner_fable_full_executive_authority.md`
  (§2 "Factory / MT5" row; §7 item 5 — enforcement code/config that would otherwise stop Fable is reviewed
  case-by-case with its own receipt). This is that case and this is its receipt.
- Payload: `docs/ops/evidence/2026-09-19_fable_q12_rollout_hold_release_owner_decision.json`
  (schema `qm.factory-restart-owner-preparation-decision/v1`, same schema as the superseded pin).
- Router provenance: successor chain `23ccce7a-ed43-4afe-b9c7-dd4880719c48` ->
  `221e4e91-a0ab-494a-85d4-9134e035f503` (this ticket).

## What this changes

`tools/strategy_farm/maintenance_control.py`'s `CANONICAL_OWNER_DECISION_{RELATIVE_PATH,SHA256,COMMIT,BLOB}`
constants and the `decision_id` it hash-verifies now point at the new 2026-09-19 payload instead of
`docs/ops/evidence/2026-08-11_factory_preparation_owner_decision_standing_unlimited.json`. The 08-11 file
is untouched (history preserved); it authorized **zero** restart-hold releases. The new payload authorizes
**8** — every `Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING` row currently active with `release_on_restart=1`
(verified live via read-only `farm_state.sqlite` query at authorship time, not from the stale 7-row count
in the predecessor ticket, which had already drifted upward by one row before this session started):

| work_item_id | EA | symbol |
|---|---|---|
| 2dad5730-30ed-5ab1-ace1-d5db4ede60db | QM5_10706 | GBPUSD |
| f364ed13-9f09-5fa6-b7df-d414e8a13d77 | QM5_11422 | USDCAD |
| 19761d0c-3877-587d-a5cd-a8e48291cdf7 | QM5_11421 | EURUSD |
| 73063ec5-3abe-5e11-8497-8df833e3ec4c | QM5_13013 | NDX |
| 5cf3ea75-2fe0-5420-97c6-650678c52b31 | QM5_10911 | GDAXI |
| 897169ba-9b8f-53ef-8c43-3013f3c7f2e8 | QM5_10911 | GDAXI |
| 779da760-42c2-50ed-80c3-263ef3366edb | QM5_10911 | GDAXI |
| ba724ef2-22eb-54fa-b155-a793ef54b5c1 | QM5_1355 | NDX |

## Precondition verified (not merely claimed)

The task payload asserted "the whole fleet runs the routing guard (full staggered reload 2026-09-19)".
Verified against `docs/ops/evidence/2026-09-19_factory_unblock/RECEIPT.md`: the fleet was staggered onto
`terminal_worker.py` HEAD today (T10/T4 -> T1/T2/T5 -> T7/T9/T8, then T2/T6; "all 10 workers on HEAD").
The DL-089 routing guard (`dl089_matrix_service.py`, `ROLLOUT_HOLD_CODE`) has been on `main`/HEAD since
commit `5475aed8ea` (2026-08-26), well before today's reload, so every resident worker process has it.

## What this does NOT do

No hold is released by this decision. `explicit_exclusions.hold_release_now` stays `false`, matching the
invariant `maintenance_control._validate_canonical_restart_owner_decision()` enforces (a preparation
decision can never itself be a runtime release trigger). Actual release additionally requires, in this
order:

1. A freshly minted runtime-activation decision (`build_runtime_activation_decision.py`) whose
   `restart_hold_ids` exactly equals this decision's `authorized_work_item_ids` at mint time.
2. A real `Factory_OFF.ps1` -> `Factory_ON.ps1` cycle with post-start health-gate pass, then
   `maintenance_control.py release-on-restart --apply --factory-on-lock-nonce <nonce>`.

Neither step is executed here. Factory_OFF/ON stops all T1-T10 backtests; the launcher's hard rule for
this ticket forbids interrupting active backtests without explicit OWNER/Fable go-ahead for that specific
disruption, and no such go-ahead exists yet. **Recommended next step:** fold this release into the next
Factory OFF/ON cycle that happens for any other operational reason (recovery, scheduled maintenance), by
re-verifying the live active hold set immediately before minting the runtime-activation decision (subset
semantics tolerate additional rows accrued in the meantime — they simply stay held) and confirming none of
these 8 stopped being active in between (that would hard-error, not silently skip).

## Verification performed this session

- `git log -S"ROLLOUT_HOLD_CODE"` / `git log -1` on `5475aed8ea` — confirms guard code age.
- Read-only `farm_state.sqlite` query for `hold_code='Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING' AND
  active=1 AND release_on_restart=1` — 8 rows, re-checked twice ~6 minutes apart (stable).
- `pytest tools/strategy_farm/tests/test_maintenance_control.py` — 41/41 passed before and after the code
  edit (constants are referenced dynamically in tests, not hardcoded).
- `maintenance_control.py release-on-restart` dry-run (no `--apply`) after the re-pin — see
  `docs/ops/evidence/2026-09-19_fable_q12_rollout_hold_release/dryrun_postpin.json`.
- No `work_items`, `work_item_holds`, or `work_item_supersedes` row was inserted or updated; no verdict
  touched.
