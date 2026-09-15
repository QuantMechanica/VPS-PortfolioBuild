# Slice report — `x1_bc_followups`

Follow-ups from the Phase B/C adversarial reviews plus CBE bookkeeping.
Authority: OWNER-DEC-CBE-20260915. Worktree base commit `4ad7ab7016`.

## Scope addressed

Review sources:
- `review/c1_orchestration_fanout_review.md` — M1 (fail-open candidate-query branch),
  M2 (single-session one-task-per-cycle throughput regression), m1 (mislabeled test comment).
- `review/b2_portfolio_caps_review.md` — MAJOR-1 (stale `select_under_aggregate_control`
  docstring), MAJOR-3 (`book_reoptimizer.py` hard `--max-corr` cut).
- Bookkeeping: `OPEN_ITEMS_STATUS.md` CBE section, `KIMI_INTEGRATION_ARCHITECTURE.md`
  continuous-lane annex.

## Files changed

1. `tools/strategy_farm/run_agent_orchestration_task.py`
   - Added `import threading`; added `CLAUDE_MAX_TASKS_PER_SESSION_DEFAULT = 4` and
     `_claude_max_tasks_per_session()` (env `QM_CLAUDE_MAX_TASKS_PER_SESSION` >
     `CLAUDE_BUDGET_POLICY.json` `max_tasks_per_session` > default 4).
   - **M1 fail-closed:** the Claude lane now delegates to a new
     `_run_claude_session_chains(...)`. When `_quota_lane_candidates("claude")` returns
     `db_missing`/`db_error:*`, it returns `skipped` with reason
     `claude_candidate_query_unavailable` and spawns **nothing** (previously
     `session_count` was left unclamped, re-opening the unpinned N*M fan-out when
     `--max-sessions > 1`).
   - **M2 drain:** each of the ≤`session_count` concurrent sessions is seeded with one
     distinct pid-owned exec-lease, then chains — after finishing its task it leases the
     NEXT eligible task and drains sequentially until no unpinned task remains,
     `max_tasks_per_session` is reached, or the run time budget (`timeout_minutes`) is
     spent. Claiming is serialized under a lock and worked task-ids are excluded, so a
     task is leased at most once per launcher run (never two sessions on one task).
     `max_sessions` in the result now reports real concurrent sessions; `tasks_worked`
     and `max_tasks_per_session` are added.
   - Non-claude lanes (and the claude dry-run) keep the historical task-agnostic
     single/parallel path (no exec-lease pin).
2. `tools/strategy_farm/portfolio/build_book_ftmo.py`
   - **MAJOR-1:** rewrote the `select_under_aggregate_control` docstring control (a) to the
     admit-with-WARN semantics (measured high correlation is `ADMITTED_CORRELATION_WARN`,
     consumes the account weight budget, recorded in the dependence panel;
     `CLUSTER_CORRELATION_UNVERIFIED` stays fail-closed; the account risk budget is the
     remaining hard guard). Docstring only — no behavior change.
3. `tools/strategy_farm/portfolio/book_reoptimizer.py`
   - **MAJOR-3:** `--max-corr` (default 0.50) is now the ADVISORY reference (flags warnings,
     never excludes). Added opt-in `--hard-max-corr` (default `None`) for explicit
     experiments. New pure helpers `correlation_hard_block(...)` (opt-in exclusion only)
     and `build_correlation_diagnostics(...)` (emits `correlation_warnings` +
     `dependence_panel` in the same shape as `build_book_ftmo`, reusing
     `portfolio_correlation.dependence_panel_entry`). Output JSON now carries a
     `correlation_policy` block and a `risk_diagnostics` block assembled by
     `risk_diagnostics.build(...)`. Module docstring updated.
4. `tools/strategy_farm/tests/test_run_agent_orchestration_fanout.py`
   - Updated `test_max_sessions_bounds_concurrent_sessions_and_drains_disjoint` (was
     `test_max_sessions_bounds_disjoint_task_sets`) for the M2 drain semantics; corrected
     the mislabeled TTL comment (m1). Added:
     `test_candidate_query_failure_fails_closed_no_unpinned_spawn` (M1),
     `test_single_session_drains_multiple_tasks_sequentially` (M2),
     `test_max_tasks_per_session_caps_the_drain` (M2),
     `test_chaining_never_double_works_a_task_under_concurrency` (M2).
5. `tools/strategy_farm/tests/test_book_reoptimizer_advisory_corr.py` (new) — 5 tests for
   the advisory correlation / opt-in hard-cut / diagnostics structure.
6. `docs/ops/OPEN_ITEMS_STATUS.md` — dated 2026-09-15 CBE-programme RESULT section
   (phases A–C done with commit ids, D–I open, interim `--max-sessions 1` mitigation +
   exit criterion, RAM-44 hold, Kimi lane task installed, Kimi telemetry auth_error).
7. `docs/ops/KIMI_INTEGRATION_ARCHITECTURE.md` — §5.4 STATUS annex: Kimi is a continuously
   available lane (`QM_StrategyFarm_KimiOrchestration_15min` installed 2026-09-15 ~13:5xZ).

## Contracts changed

- `run_agent_orchestration_task._run_agent_with_session_lease` (claude lane): new skip
  reason `claude_candidate_query_unavailable` (fail-closed on candidate-query failure);
  result now reports concurrent `max_sessions` plus `tasks_worked` /
  `max_tasks_per_session`. New internal function `_run_claude_session_chains`; new config
  `_claude_max_tasks_per_session()`. Regression tests added.
- `book_reoptimizer` CLI: `--max-corr` is advisory (was hard cut); new `--hard-max-corr`
  opt-in flag; output JSON gains `correlation_policy` + `risk_diagnostics`. Regression
  tests added.
- No gate threshold, verdict semantics, or qualification criterion changed. No farm-DB
  write beyond the pre-existing additive `agent_task_exec:<id>` exec-lease coordination
  (unchanged from the landed c1 slice; GRÜN infra coordination, not a verdict write).

## Tests + pytest summary

Command (from worktree root):
`python -X utf8 -m pytest tools/strategy_farm/tests/test_run_agent_orchestration_fanout.py tools/strategy_farm/tests/test_book_reoptimizer_advisory_corr.py test_agent_orchestration_lock.py test_agent_selection_skill_contract.py test_antigravity_backend_contract.py test_codex_model_tiers.py test_codex_tiers_enforce_preconditions.py test_run_agent_orchestration_heartbeat.py test_run_agent_orchestration_kimi.py test_task_contract_fix_package.py test_video_analysis_ai_lanes.py test_dual_book_builders.py test_concentration_tail.py test_portfolio_correlation.py -q`

Result: **293 passed, 1 skipped in 38.15s** (the 1 skip is a pre-existing DXZ-panel skip
in the dual-book suite). Fanout-only: 12 passed. book_reoptimizer-only: 5 passed.
`py_compile` clean on the three changed `.py` modules.

## Runtime artifacts written

None written by this slice (code + docs + tests only). `book_reoptimizer` now emits a
`risk_diagnostics` block into its existing `--out` JSON when run; not executed here (it
reads the live farm DB / streams, out of scope for a code slice).

## Rollback

- Revert the seven files. The fan-out change is self-contained in
  `_run_agent_with_session_lease` + `_run_claude_session_chains`; reverting restores the
  landed c1 up-front-claim behavior. `book_reoptimizer` reverts to the hard `--max-corr`
  cut. Docs are additive sections. To disable M2 chaining without a revert, set
  `QM_CLAUDE_MAX_TASKS_PER_SESSION=1` (each session works exactly one task, i.e. the c1
  behavior) — M1 fail-closed still applies.

## Items NOT done (with reasons)

- **c1 B1 (stale PS1 hunk base):** N/A here — the `install_agent_orchestration_scheduled_
  tasks.ps1` `-ClaudeMaxSessions` change already landed in canonical commit `ac2db161ef`;
  this slice does not touch the installer. The interim `--max-sessions 1` default stands;
  re-registration to `-ClaudeMaxSessions 3` is the documented exit criterion (ops action,
  not this slice).
- **b2 MAJOR-2 (trade-overlap/downside in the dependence panel):** deferred to Phase E
  `metrics.py` per the review; `dependence_panel_entry` already accepts
  `downside_correlation`/`trade_overlap` params, so wiring the existing overlap primitive
  is a Phase-E follow-up. This slice only relaxes `book_reoptimizer` correlation to
  advisory (MAJOR-3) and keeps the panel correlation-only there, consistent with the FTMO
  builder.
- **c1 m3 (dangling decision citation):** resolved independently — the decision record
  `decisions/2026-09-15_owner_continuous_book_evolution.md` landed in `a5453d3b94`, so the
  `OWNER-DEC-CBE-20260915` citations resolve.
- **Kimi first-campaign telemetry (`auth_error`):** documented, not fixed here — it clears
  when the first campaign warms the OAuth path; no code change is warranted (fail-closed
  fallback to local caps is the intended behavior).
