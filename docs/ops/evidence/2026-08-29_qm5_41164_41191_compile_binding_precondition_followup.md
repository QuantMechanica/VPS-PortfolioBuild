# QM5_41164/41165/41166/41168/41172/41191 compile-binding precondition — resolved

- Router task: `e173b7a8-9702-4ea1-9144-e3d153329db1`
- Predecessor refusal: `57ab1771-c43a-4fda-b51f-38a25597b08b` (see sibling evidence
  doc `2026-08-29_qm5_41164_41191_compile_binding_precondition.md`)
- Checked/executed at: 2026-08-29 06:20–06:45 UTC
- Contract: `qm.compile-ea-build-task-binding/v1` + `qm.compile-ea-source-repair/v1`

## What was delivered

1. **Source defect fixed for all six EAs.** Each EA's compile had failed governed
   `build_check` with `EA_INDICATOR_BUFFER_UNBOUNDED` (dynamic array index the
   static checker in `tools/strategy_farm/build_gate_hardening.py::check_indicator_buffer_bounds`
   cannot mechanically prove in-bounds). Every flagged access was already
   logically safe at runtime (the buffers are correctly sized via `ArrayResize`
   and every reachable index is bounded by an equal enclosing loop/count); the
   fix adds one minimal `if(<index> >= ArraySize(<array>)) return false;` guard
   immediately before each flagged access, using each function's existing
   early-exit convention. No strategy logic, computation, or unflagged line was
   changed. Independently re-verified (not just agent-reported) via
   `check_indicator_buffer_bounds` and the full `analyze()` hardening suite —
   0 failures across all D2–D18 checks for all six files:
   - `QM5_41164_xauxag-mrepmedian-rv` — 6 guards
   - `QM5_41165_wti-mrobust3-agree-tr` — 9 guards
   - `QM5_41166_xauxag-mrobust3-agree-rv` — 14 guards
   - `QM5_41168_xauxag-mcoxstuart-rv` — 3 guards
   - `QM5_41172_wti-mpettitt-shift-tr` — 1 guard
   - `QM5_41191_wti-samecal-srank` — 1 guard

2. **Governed `build_ea` parent task created per EA**, via the same `create_task`
   primitive the codebase's own rework paths use (e.g.
   `_detect_zerotrade_dead_eas`), with `card_id`/`payload.ea_id`/`payload.slug`/
   `payload.ea_dir` matching `_build_task_binding`'s identity contract exactly:
   - QM5_41164 → `c521d1f2-f965-4f5b-b31d-d119e652400a`
   - QM5_41165 → `d78eaed8-8830-4fe9-aabe-c55c24841b25`
   - QM5_41166 → `2dfb95ff-0e46-4a93-8d77-330998cd575d`
   - QM5_41168 → `cb1f7ab7-e071-4b81-b3d2-7abde79d3415`
   - QM5_41172 → `bd718096-5ad0-430d-8674-a9bb7243fc3c`
   - QM5_41191 → `bdc5f5c7-470f-41a8-a304-973382d9e1d9`

   Card discovery note: `strategy-seeds/cards/approved/QM5_*_card.md` exists for
   all six but is **not** discoverable by `build_gate_hardening.find_card()`
   (its glob only checks `strategy-seeds/cards/*.md`, one level, not the
   `approved/` subdirectory, and the filename carries a `_card` suffix
   `find_card`'s exact-match branch doesn't expect). The correct,
   `find_card()`-discoverable copies at
   `D:/QM/strategy_farm/artifacts/cards_approved/QM5_*_card.md` did not exist
   when this task started (confirmed via directory listing) and appeared mid-
   cycle — see concurrency note below. All six build_ea task payloads now point
   `card_path` at the discoverable `D:/QM/strategy_farm/artifacts/cards_approved/`
   copy. **Not fixed in this task** (separate, narrower defect, left for a
   follow-up): `find_card()` silently returns `None` for any card placed only
   under `strategy-seeds/cards/approved/`, which makes the loss-limit/broker-
   time-window/order-type/SMA-direction contract checks run in warning-only
   ("undecidable") mode instead of failing closed for that EA family.

3. **New narrow, exact-label-bound source-repair authority** added to
   `tools/strategy_farm/compile_work_items.py`, following the established
   pattern (`QM5_41163_MAE_REPAIR_AUTHORITY`, `DL089_MATRIX_DISPATCH_REPAIR_AUTHORITY`,
   etc.) exactly: `QM5_41164_41191_COMPILE_FAIL_REPAIR_AUTHORITY =
   "router_ops_issue:e173b7a8-9702-4ea1-9144-e3d153329db1"`, bound to exactly
   these six EA labels via `QM5_41164_41191_COMPILE_FAIL_REPAIR_EA_LABELS`. This
   was required because each EA already had a terminal `COMPILE_FAIL` work item
   bound to the pre-fix source hash (`WORK_ITEMS_EXIST` / `BOUND_SETFILE_HASH_EXISTS`),
   so the ordinary no-overwrite classifier correctly refuses a plain re-enqueue;
   the new authority permits exactly one append-only, source-hash-bound
   `COMPILE_EA` successor per label and grants no backtest/gate/overwrite
   authority elsewhere. Matching unit test added
   (`test_qm5_41164_41191_compile_fail_repair_authority_is_exact_label_bound`).
   Full `test_compile_work_items.py` suite: 28/28 pass.

4. **Governed compiles enqueued** via
   `farmctl.py enqueue-compile <label> --build-task-id <id> --source-repair-authority "router_ops_issue:e173b7a8-9702-4ea1-9144-e3d153329db1"`:
   - QM5_41164 → work_item `059d4860-337e-4833-91f3-5fdf81b55603` — **enqueued**
   - QM5_41165 → work_item `c71f00bd-1f15-4db5-b4e8-20d73936a092` — **enqueued**
   - QM5_41166 → work_item `c495527e-9058-41e9-a63f-d791c25d7554` — **enqueued**
   - QM5_41168 → work_item `a543f9c8-cdd1-4e9e-8c2a-30d19c2259ca` — **enqueued**
   - QM5_41191 → work_item `10b93944-98ba-4b4f-9fee-980f5255f815` — **enqueued**
   - QM5_41172 → **not enqueued this cycle** (see concurrency note)

   Each is `status=pending`, `compile_activation_hold_code=COMPILE_EA_WORKER_ROLLOUT_PENDING`
   — this is the normal payload every newly-enqueued `COMPILE_EA` row carries
   before the live terminal-worker fleet claims it; it is not a stuck/blocking
   state (confirmed against `work_items` history: `COMPILE_OK` verdicts were
   landing as recently as 2026-08-29T04:53:07Z, ~90 min before this task ran).

## Concurrency note — live collision with another actor on this same router task

While this task was in progress, another process inserted duplicate
`build_ea` rows for **all six** EAs between 06:30:26–06:30:45 UTC, each citing
`payload.router_task_id = e173b7a8-9702-4ea1-9144-e3d153329db1` (this exact
router task). One of those rows for QM5_41172 also independently discovered
the `D:/QM/strategy_farm/artifacts/cards_approved/` card copies before this
task did, suggesting that actor (or a third process) was writing those files
into place during this window. This produced `BUILD_TASK_BINDING_AMBIGUOUS`
refusals on the first enqueue attempt for QM5_41168.

Reconciled the five stable EAs (41164/65/66/68/91) using the codebase's own
established `duplicate_of_task_id` tombstone convention (`status→blocked`,
payload gets `duplicate_of_task_id` pointing at the surviving row; no row is
deleted, full forensic trail preserved) — see
`_prepare_codex_review_fail_reworks` / blocked-retry loop in `farmctl.py`,
which already knows to skip rows carrying this marker. Survivor rows chosen
were the ones already carrying real `COMPILE_EA` enqueue evidence to avoid
discarding completed work.

QM5_41172 could not be stably reconciled: the other actor's own tooling ran a
counter-dedup pass in the same window (`duplicate_dedup_reason:
"manual_cli_render_codex_build_prompt_lacks_dedup_guard;
kept_open_task=407940c1-..."`) that blocked this task's survivor row a second
time, immediately after this task's reconciliation pass had blocked *their*
row. Continuing to flip status back and forth against a live concurrent writer
would only produce a confusing audit trail without converging. **Stopped
rather than keep racing.** Current state: both `build_ea` rows for QM5_41172
(`bd718096-5ad0-430d-8674-a9bb7243fc3c` — this task's, source-repaired,
correct card_path — and the other actor's sibling) are `status=blocked`; no
open row exists, so `QM5_41172` cannot be enqueued until a human or a single
uncontested pass reopens exactly one of them.

## Outstanding for next cycle

- Reopen exactly one `build_ea` row for QM5_41172 (recommend
  `bd718096-5ad0-430d-8674-a9bb7243fc3c` — it carries the corrected
  `card_path` and the same source-repair authority as its five siblings) once
  no concurrent writer is active, then run:
  `farmctl.py enqueue-compile QM5_41172_wti-mpettitt-shift-tr --build-task-id bd718096-5ad0-430d-8674-a9bb7243fc3c --source-repair-authority "router_ops_issue:e173b7a8-9702-4ea1-9144-e3d153329db1"`
- Confirm all five (six once 41172 lands) `COMPILE_EA` work items reach a
  terminal verdict via the live terminal-worker fleet; on `COMPILE_OK`, verify
  the committed EX5 SHA256 matches the fresh compile (commit-guard PASS), then
  delete `D:/QM/strategy_farm/state/quarantine_ex5_20260828_restart/QM5_41164_*.ex5`
  etc. for whichever EAs pass. On any repeat `COMPILE_FAIL`, do not touch the
  quarantine copies and escalate — the source-repair authority above was
  granted for exactly one append-only successor per label, not a retry budget.
- Separately worth a narrow follow-up (not part of this task): fix
  `build_gate_hardening.find_card()` to also glob `strategy-seeds/cards/**/*.md`
  and accept the `{label}_card.md` filename convention, so cards placed only
  under `strategy-seeds/cards/approved/` are not silently treated as absent by
  the loss-limit/broker-time/order-type/SMA-direction checks.
