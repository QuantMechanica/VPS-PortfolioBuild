# Claude orchestration cycle — 2026-05-25 17:30Z

Single-pass cycle. Idle: no claude tasks in any state.

## Router status

- claude: enabled, max_parallel=3, running=0
- codex: enabled, max_parallel=5, running=0 — 3 APPROVED build_ea + 2 APPROVED ops_issue queued
- gemini: enabled, max_parallel=2, running=1 — 5 FAILED research_strategy + 1 IN_PROGRESS

`run --min-ready-strategy-cards 5 --max-routes 5` returned `no_routable_task`;
generic research replenishment remains frozen
(`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`,
ready_strategy_cards=992, approved_cards=2566 [+2 vs 1700Z], blocked_approved_cards=1574).
`route-many --max-routes 5` likewise returned `no_routable_task`.
`list-tasks --agent claude` returned `[]`.

## Health snapshot (farmctl)

Overall: FAIL (3 fail / 3 warn / 13 ok). checked_at 2026-05-25T08:45:35Z.

| Check | Value | Status | Δ vs 1700Z |
|---|---|---|---|
| mt5_worker_saturation | 9/10 alive (T1 missing) | WARN | +0 |
| mt5_dispatch_idle | 49 pending, 9 active | OK | -10 pending, +0 active |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 561 | FAIL | -14 |
| unenqueued_eas_count | 20 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079, 10128) | FAIL | +11 (WARN → FAIL) |
| p_pass_stagnation | 0 P3+ PASS in 12h | WARN | +0 |
| zerotrade_rework_backlog | 1 (QM5_10027: 6/6) | WARN | +1 attempt (eighth consecutive cycle) |
| quota_snapshot_fresh | codex=44s, claude=44s | OK | -1s |
| pump_task_lastresult | exit 0 | OK | +0 (fourteenth consecutive cycle) |
| disk_free_gb | D: 148.3 | OK | -0.3 |
| codex_zero_activity | 4 codex, 6 pending | OK | +1 codex, -1 pending |
| approved_cards | 2566 (schema-blocked) | — | +2 |
| source_pool_drained | 12 pending sources | OK | +0 |

T1 terminal_worker still missing. Pump exit 0 holds (fourteenth consecutive
cycle). Backlog drain continues strong — pending down -10 to 49 with active
flat at 9.

**unenqueued_eas_count jumped 9 → 20 and crossed WARN → FAIL.** Same chronic
nine (QM5_10019/10021/10028/10035/10039/10043/10044/10076/10079) plus eleven
new arrivals (QM5_10128 onward). The build queue drained
(`unbuilt_cards_count` -14) but the freshly-built EAs landed straight in the
unenqueued pile rather than P2. Dispatch-side block, not a build problem.

`unbuilt_cards_count` 575 → 561 (-14); approved_cards 2566 (+2). First
meaningful unbuilt drain in many cycles — build emission finally outpaced
card inflow.

`quota_snapshot_fresh` codex=44s / claude=44s — both well within threshold.

`zerotrade_rework_backlog` (QM5_10027) ticked from 5/5 to **6/6** and persists
into an **eighth** consecutive cycle. Well past the 1500Z escalation point.
Auto-rework emission remains stuck; needs OWNER/Codex intervention.

`codex_zero_activity` 3 → 4 codex with pending 7 → 6 — codex re-ramped one
more in-flight task this cycle.

## QM5_10260 queue state

All 8 Q02 work_items remain `failed` with verdict `INVALID` (0 pending). No
change from previous cycle. State stable since 2026-05-24 21:16:08Z. Preflight
reason still `setfile_missing` — forex M15 setfiles referenced by the failed
work_items have not been pushed to main.

## Actions taken

None. No claude IN_PROGRESS task; router has no routable work; orchestration
cycle exits idle.

## Notes for next cycle

- **unenqueued_eas_count crossed WARN → FAIL (9 → 20).** Eleven newly-built
  EAs landed in the unenqueued backlog instead of P2. Dispatch-side block
  worsening; flag for Codex/OWNER review.
- Pump exit 0 held for a fourteenth consecutive cycle. Treat as stable.
- Backlog drain continues (49 pending / 9 active, -10 pending).
- `unbuilt_cards_count` finally moved (-14 to 561) — build emission outpaced
  inflow for the first time in many cycles. But the gain landed in the
  unenqueued queue rather than P2.
- `quota_snapshot_fresh` 44s, healthy.
- `zerotrade_rework_backlog` (QM5_10027) advanced from 5/5 to 6/6 and
  persists into an **eighth** cycle — well past escalation. Auto-rework
  emission still stuck. OWNER/Codex should inspect why the pump isn't
  building the rework task.
- Codex re-ramped to 4 running (pending 6).
- Worktree carries unstaged framework EA modifications (QM5_10047 and
  10047 set-files) from Codex; not part of this cycle's commit (explicit
  pathspec only).
- Headline blockers unchanged: schema blocker (2566 cards),
  p2_pass_no_p3=127, unbuilt_cards_count=561, unenqueued_eas=20 (newly
  FAIL), T1 terminal_worker missing.
- Upstream issues still sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
