# Orchestration Cycle Log — 2026-08-21T1306Z (claude-orchestration-2)

## Summary

Single-pass headless cycle. Per `feedback_farmctl_run_from_canonical_repo`
(Rule 23), `farmctl.py health` and `agent_router.py` reads/writes were
cross-checked against canonical `C:/QM/repo` for the fuller check set and
for lease verification; this worktree's own `farmctl.py health` again
under-reports (19 checks vs 73 from canonical: fail=19/warn=12/ok=42 there).

**0 tasks processed to REVIEW by this session.** 2 `claude`-assigned
`IN_PROGRESS` `ops_issue` tasks were present at cycle start, both
`routed_at=2026-08-21T12:53:40Z`. Both confirmed under a live spawn lease
(`agent_id=claude`, `acquired_at=12:53:40Z`, `expires_at=13:23:40Z`,
matching each task's own `routed_at` — i.e. the router's built-in claim on
the `IN_PROGRESS` transition, not created by this session) and were
deferred, not duplicated — same pattern as 2026-08-17T1829Z, 2026-08-21T0832Z,
0953Z and 1019Z.

## The 2 claude IN_PROGRESS ops_issue tasks at cycle start

- `9bdfde03-c9ef-43ce-b7ea-632347ad0f06` — priority 76,
  OWNER-DEC-FTMO-SYMBOLPOLICY: replace `build_book_ftmo.py`'s
  `select_one_per_symbol` cap with the ratified aggregate (correlation/
  cluster + account risk-budget) control per Q11 Portfolio Construction
  design. Dry-run only, no book/FTMO/T_Live contact. **Lease live**, deferred.
- `6ad915cb-a9e5-48ca-a538-33dc42ac9957` — priority 72, QM-TODO-20260821-121:
  reconcile the Q12 portfolio_candidates register (30 READY/6 EVIDENCE_STALE/
  2 DUPLICATE) against the 24 signed live sleeves, read-only, `claude_headless_model=opus`.
  **Lease live**, deferred.

## Lease check method

Attempted `agent_scopes.acquire_spawn_lease` for both `agent_task:<id>` keys
against the shared `D:/QM/strategy_farm/state/farm_state.sqlite` from
canonical `C:/QM/repo`; both returned `acquired=False`. Direct peek of
`spawn_leases` confirmed both rows: `agent_id=claude`,
`acquired_at=2026-08-21T12:53:40+00:00`, `expires_at=2026-08-21T13:23:40+00:00`
— live at check time (~13:04-13:10Z), not expired. Acquired_at matches each
task's `routed_at` exactly, i.e. the router claimed the lease at routing
time; this session's own routing calls this cycle did not create or touch
these rows (they predate this cycle's `run`/`route-many` invocations).

**Decision: deferred both, did no work on them.** Per this cycle's
instructions ("if the lease is live, skip/defer instead of duplicating the
task") and `project_qm_claude_lease_pool_duplicate_build_2026-08-10`.

## Routing

`agent_router.py run --min-ready-strategy-cards 5 --max-routes 5` and
`route-many --max-routes 5` (canonical repo): both returned
`no_routable_task` / `no_available_agent` — claude 3/3 running, codex 5/5
running, gemini 0/2 (idle, but lacks `ops`/`code` for the pending queue
shape). No new routes this cycle.

## Worktree staleness

`git rev-list --count HEAD..origin/main` = 11,965 (up from 11,912 at
2026-08-21T1019Z, ~53 commits in this window). This worktree's `origin/main`
ref (`7856941c7`, `2026-08-21T15:00:16+02:00`) is itself stale against
canonical `C:/QM/repo` HEAD (`df65b49a4`, `15:06:53+02:00`) read moments
later. `tools/strategy_farm/agent_scopes.py` remains absent from this
worktree; `list-tasks` also lacks a `--state` filter here (present upstream).

## Health

Worktree (19 checks): `overall=FAIL`. Same under-reporting pattern as prior
cycles — not trusted as the operative picture.

Canonical repo (`C:/QM/repo`, 73 checks): `overall=FAIL`,
`fail=19 warn=12 ok=42`. Notable FAILs: `mt5_worker_saturation` 5/10 (T2,
T3, T4, T6, T8 alive — down from 10/10 at 1019Z); `codex_zero_activity` (0
codex build activity in 3h, 37 pending `build_ea`); `q02_stranded_exhausted_pairs`=275
(unchanged, MNT-006 target); `q09_sealed_plan_hold_age` 24 holds >6h, oldest
now 364.0h (was 361.3h); `pending_artifact_binding_drift`=12 across 8 rows
(unchanged); both `QM_StrategyFarm_Pump_5min` and `_Tick_5min` scheduled
tasks show `killed@time-limit` (exit 267014) — a jump from the single
`pump_task_lastresult` WARN seen at 1019Z, worth flagging if it persists
next cycle. `repo_dirty_build_guard`-adjacent WARNs (`codex_bridge_heartbeat`,
`codex_auth_broken`) attribute to 1 uncommitted evidence file in canonical
repo (`docs/ops/evidence/2026-08-21_q07_zero_variance_investigation.md`,
someone else's active WIP, not touched here). Separately, canonical repo
working tree also shows ~dozens of modified `q06_stress_harsh*.set` files
across several EAs (T1-T10 factory backtest churn) — not committed here,
out of router-cycle scope.

## QM5_10260 Q08 check

Confirmed unchanged: latest `Q08` row for `QM5_10260` is still
`verdict=FAIL_HARD`, `updated_at=2026-06-26T22:41:27Z`. No newer Q08 rows,
no action required.

## Quota / capacity snapshot

`claude`: 5h used 12.0%, weekly used 9.0% (from the leased tasks' own
`quota_gate` metrics, decided 12:53:40Z). `claude` running 3/3, `codex`
running 5/5, `gemini` running 0/2 at cycle end — no capacity freed this
cycle (no task closed to REVIEW).

## Recommended next step

No action taken this cycle beyond deferral and health confirmation, per
router-only scope. Flagged for whoever holds the two live leases /
board-advisor:
1. Both leased tasks (`9bdfde03`, `6ad915cb`) still show ~13-19 min of
   lease remaining as of this log; next cycle should re-check before
   assuming stale/abandoned.
2. `mt5_worker_saturation` regressed 10/10 → 5/10 since the last logged
   cycle — worth a `start_terminal_workers.py --dedupe` pass if it hasn't
   self-healed by the next cycle.
3. `QM_StrategyFarm_Pump_5min` / `_Tick_5min` both now show
   `killed@time-limit` — new since 1019Z, worth watching for a stuck
   scheduled-task pattern rather than a one-off.
