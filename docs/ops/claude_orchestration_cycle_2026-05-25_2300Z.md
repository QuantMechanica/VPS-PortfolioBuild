# Claude orchestration cycle — 2026-05-25 23:00Z

Single-pass cycle. Idle: no claude tasks in any state.

## Router status

- claude: enabled, max_parallel=3, running=0
- codex: enabled, max_parallel=5, running=0 — 3 APPROVED build_ea + 2 APPROVED ops_issue + 1 REVIEW ops_issue (flat vs 2230Z)
- gemini: enabled, max_parallel=2, running=1 — 5 FAILED research_strategy + 1 IN_PROGRESS

`run --min-ready-strategy-cards 5 --max-routes 5` returned `no_routable_task`;
generic research replenishment remains frozen
(`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`,
ready_strategy_cards=0, approved_cards=2566, blocked_approved_cards=2566).
`route-many --max-routes 5` likewise returned `no_routable_task`.
`list-tasks --agent claude` returned `[]`.

## Health snapshot (farmctl)

Overall: FAIL (3 fail / 2 warn / 14 ok). checked_at 2026-05-25T12:00:17Z.

| Check | Value | Status | Δ vs 2230Z |
|---|---|---|---|
| mt5_worker_saturation | 9/10 alive (T1 missing) | WARN | +0 |
| mt5_dispatch_idle | 9 pending, 2 active | OK | -3 pending, -2 active |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 679 | FAIL | **-97** (776 → 679) |
| unenqueued_eas_count | 9 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079) | WARN | +0 (same chronic nine) |
| p_pass_stagnation | 0 P3+ PASS in 12h | FAIL | +0 |
| zerotrade_rework_backlog | 0 ("no uncovered recurrent zero-trade EAs") | OK | +0 (seventh clear cycle) |
| quota_snapshot_fresh | codex=26s, claude=26s | OK | -1s (27 → 26) |
| pump_task_lastresult | exit 0 | OK | +0 (twenty-fifth consecutive cycle) |
| disk_free_gb | D: 146.4 | OK | -0.2 |
| codex_zero_activity | 3 codex, 21 pending | OK | -3 codex, +10 pending (still disagrees with router — see notes) |
| approved_cards | 2566 (schema-blocked) | — | +0 |
| source_pool_drained | 12 pending sources | OK | +0 |

T1 terminal_worker still missing. Pump exit 0 holds (twenty-fifth consecutive
cycle).

**Pending -3 / active -2 this cycle (12/4 → 9/2).** Drain accelerated into
active slots for the second time in seven cycles; both pending and active
contracted simultaneously. With T1 missing and active at 2, fleet utilisation
is light — the queue is shrinking faster than dispatch is feeding it.

**unbuilt_cards_count -97 (776 → 679).** Last cycle flagged the +203 jump as
likely delayed accounting from the inbox cleanup + PT13 patch surfacing latent
cards. This cycle the count partially drained back down without any new build_ea
tasks appearing in router state (still 3 APPROVED). Most plausible read: the
pump's auto-build bridge is making progress through the surfaced backlog via
ex5 production rather than agent_tasks creation. Worth watching whether it
keeps draining toward the prior 573 baseline or stalls.

**zerotrade_rework_backlog held clear (7th cycle).** QM5_10027 resolution
durable; this is the stable state.

**unenqueued_eas_count flat at 9.** Same chronic nine
(QM5_10019/10021/10028/10035/10039/10043/10044/10076/10079).

`quota_snapshot_fresh` codex=26s / claude=26s — -1s vs prior. Holds well inside
the 24–35s band.

`codex_zero_activity` field reports 3 codex / 21 pending. Router status shows
codex running=0 and only 5 APPROVED + 1 REVIEW codex tasks total. Second cycle
in a row the health collector and router disagree on codex counts. Pattern
suggests a stale snapshot in the collector rather than a real codex spike;
not actionable from claude.

## QM5_10260 queue state

All 8 Q02 work_items remain `failed` with verdict `INVALID` (0 pending).
No change. Preflight reason still `setfile_missing` — forex M15 setfiles
referenced by failed work_items have not been pushed to main.

## Actions taken

None. No claude IN_PROGRESS task; router has no routable work; orchestration
cycle exits idle.

## Notes for next cycle

- **unbuilt_cards_count drained -97 (776 → 679).** Encouraging — last cycle's
  +203 surface appears to be partially clearing via pump auto-build production
  rather than stalling. Watch whether the next 2–3 cycles continue draining
  toward the prior 573 baseline.
- zerotrade_rework_backlog clear sustained 7 cycles. Stable state.
- Pending -3 / active -2: queue is drying up faster than dispatch refills.
  With T1 still missing and active at 2, this risks an idle-fleet condition
  if pump output slows. Worth flagging if active drops to 0 next cycle.
- Pump exit 0 held for a twenty-fifth consecutive cycle. Stable.
- `quota_snapshot_fresh` -1s (27 → 26); baseline.
- Codex 5 APPROVED + 1 REVIEW flat vs last cycle. No task movement this
  30-min window.
- `codex_zero_activity` detail "3 codex, 21 pending" disagrees with router
  (0 running, 5 APPROVED + 1 REVIEW). Second consecutive cycle of disagreement
  — pattern now points at a stale health-collector snapshot, not a real
  codex daemon problem.
- Disk D: 146.4 GB (-0.2 GB). Trivial.
- Worktree still carries unstaged framework EA modifications (QM5_10047
  ex5/mq5/set-files) from Codex; not part of this cycle's commit
  (explicit pathspec only).
- Headline blockers: schema blocker (2566 cards), p2_pass_no_p3=127,
  unbuilt_cards_count=679 (down but still FAIL), unenqueued_eas=9, T1
  terminal_worker missing.
- Upstream issues still sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
