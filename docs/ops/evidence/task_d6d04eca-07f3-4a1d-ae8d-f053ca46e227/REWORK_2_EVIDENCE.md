# task d6d04eca — rework 2 (landing-only) evidence

Written 2026-10-16T18:10:52Z by Claude (Opus), lane `agents/claude-orchestration-2`.

## Verdict being answered

RECYCLE 2/3 (Fable delegate, 2026-10-16T14:22Z): code review PASS; only blocker was a
cherry-pick conflict of the round-2 review shas onto canonical in
`tools/strategy_farm/tests/test_start_terminal_workers_env.py` (both sides appended tests at EOF).
Fix exactly: re-apply on current canonical keeping BOTH test blocks, no code change, rerun the
six named test files, publish a fresh review ref.

## What was done

1. Detached scratch worktree at canonical `agents/board-advisor` 9d629b26752159219695a53c0858f42ec5841fda;
   `git cherry-pick` of round-2 review shas d5684bfb06f4 → a756582bde2b → 7e8a6ef365b7.
2. Only conflict: `test_start_terminal_workers_env.py`. Resolved by deleting the three conflict
   marker lines only — canonical block (`test_memory_limit_production_refuses_canary_binding`,
   `test_memory_limit_production_refuses_cap_other_than_one`) kept first, then the lane block
   (`test_machine_scope_overrides_stale_caller_dl089_allowlist`,
   `test_retired_exact_dl089_value_is_not_inherited_from_caller`,
   `test_governed_selection_never_fills_a_live_reserved_terminal`,
   `test_legacy_powershell_starter_delegates_to_governed_launcher`). No other file needed a
   manual change; no production code was edited.
3. Lane commits (this branch is diverged from canonical, so the same two-step pattern as round 2):
   - `ee50a32a4eae126164a00e7cc93b795694779a2a` — sets the 12 touched code/test paths to exact
     canonical 9d629b2675 content + `REWORK_2_BASELINE_SYNC.md` (on canonical only the note changes).
   - `3959de184d45576bbd3f2bd8135074b6b1f98772` — fix: the 12 paths at the resolved rebase
     content. `git diff` vs the verified scratch rebase tip over those paths = 0 lines.
   Both are source commits for this round.
4. Publish simulation: cherry-pick of ee50a32a4e + 3959de184d onto the then-current canonical
   0065e982e4be (canonical drift since 9d629b26 = 3 docs files only) → clean, no conflict;
   touched paths byte-identical to the verified rebase.

## Tests (on rebased tree, canonical 9d629b26 + round-2 content)

`python -m pytest -q tools/strategy_farm/tests/{test_factory_watchdog_reservation_reset_guard,
test_factory_canary_fleet, test_start_terminal_workers_env, test_dwx_2026_band_a_export,
test_factory_watchdog_interactive_heal_static, test_terminal_worker_atomic_claim}.py`

→ **179 passed, 4 failed** (85 s). The 4 failures are all in `test_terminal_worker_atomic_claim.py`:

- `test_ordinary_reservation_blocks_following_specific_multisymbol_claim`
- `test_physical_ram_reservation_classes_are_conservative`
- `test_specific_claim_requires_factory_off_and_selects_exact_item`
- `test_two_leg_fx_claim_uses_measured_eight_gb_reservation`

Baseline control: the same file on untouched canonical 9d629b26 → **4 failed, 109 passed**, the
identical four test ids. They come from canonical, not from this change (the verdict already listed
them as known pre-existing; in this run the sqlite-contention timing test passed).

## Lane hygiene note

This lane worktree had a stale uncommitted edit to `tools/strategy_farm/start_terminal_workers.py`
(file mtime 2026-07-19, +3/−13, not from this task). After the branch advanced, that edit would have
reverted the fix on any later pathspec commit. Backed up to
`D:/QM/strategy_farm/artifacts/lane_dirty_backups/claude-orchestration-2_20261016_task_d6d04eca/`
(full file + patch vs c1cb301ee8), then the path was restored to HEAD. Other unrelated dirty files in
the worktree were left alone.

## Not done (by rule)

No write to C:/QM/repo, no main/board-advisor advance, no terminal touched. Landing remains a
Claude+OWNER close-out after review.
