# Claude orchestration cycle — 2026-05-25 23:30Z

Single-pass cycle. Idle: no claude tasks in any state.

## Router status

- claude: enabled, max_parallel=3, running=0
- codex: enabled, max_parallel=5, running=0 — 3 APPROVED build_ea + 2 APPROVED ops_issue + 1 REVIEW ops_issue (flat vs 2300Z)
- gemini: enabled, max_parallel=2, running=1 — 5 FAILED research_strategy + 1 IN_PROGRESS

`run --min-ready-strategy-cards 5 --max-routes 5` returned `no_routable_task`;
generic research replenishment remains frozen
(`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`,
ready_strategy_cards=992, approved_cards=2566, blocked_approved_cards=1574).
`route-many --max-routes 5` likewise returned `no_routable_task`.
`list-tasks --agent claude` returned `[]`.

## Health snapshot (farmctl)

Overall: FAIL (3 fail / 2 warn / 14 ok). checked_at 2026-05-25T12:15:15Z.

| Check | Value | Status | Δ vs 2300Z |
|---|---|---|---|
| mt5_worker_saturation | 8/10 alive (T1, T10 missing) | WARN | **-1 worker** (9 → 8; T10 now also missing) |
| mt5_dispatch_idle | 8 pending, 2 active | OK | -1 pending, +0 active |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 818 | FAIL | **+139** (679 → 818 — drain reverses) |
| unenqueued_eas_count | 20 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079, 10128, …) | FAIL | **+11** (9 → 20 — chronic nine baseline broken; status escalates WARN → FAIL) |
| p_pass_stagnation | 0 P3+ PASS in 12h | WARN | +0 |
| zerotrade_rework_backlog | 0 ("no uncovered recurrent zero-trade EAs") | OK | +0 (eighth clear cycle) |
| quota_snapshot_fresh | codex=24s, claude=24s | OK | -2s (26 → 24) |
| pump_task_lastresult | exit 0 | OK | +0 (twenty-sixth consecutive cycle) |
| disk_free_gb | D: 146.2 | OK | -0.2 |
| codex_zero_activity | 4 codex, 26 pending | OK | +1 codex, +5 pending (still disagrees with router — see notes) |
| approved_cards | 2566 (schema-blocked) | — | +0 |
| source_pool_drained | 12 pending sources | OK | +0 |

T1 worker still missing; T10 has now also dropped offline — mt5_worker_saturation
declines from 9/10 → 8/10. Pump exit 0 holds (twenty-sixth consecutive cycle).

**unbuilt_cards_count +139 (679 → 818) — drain reversed.** Last cycle's -97 drain
toward the prior 573 baseline did not continue. This cycle the count climbed
back up to 818, the highest value in the recent series (574 → 776 → 679 → 818).
Pump exit 0 throughout, so the pump is running, but it is not net-draining the
unbuilt backlog and is in fact admitting more surfaced cards than it ships ex5
for. The earlier "auto-build producing ex5 without new agent_tasks" read held
for one cycle then reversed — suggests the inbox-cleanup / PT13 surfacing is
still feeding new cards faster than the pump can build them.

**unenqueued_eas_count +11 (9 → 20) — chronic nine baseline broken.** This is
the headline change. The chronic-nine roster
(QM5_10019/10021/10028/10035/10039/10043/10044/10076/10079) held flat for at
least the last 7 cycles. This cycle it jumped to 20 (sample includes 10128 plus
others not enumerated in the truncated check output). Status correspondingly
escalates from WARN → FAIL. New unenqueued EAs imply the pump is producing
.ex5 / review-approving builds but is not enqueueing them into Q02
work_items at the same rate. Combined with the unbuilt_cards +139, the pump's
output stage appears to be lagging behind its admit stage.

**MT5 worker -1 (T10 dropped).** T1 has been missing for many cycles; T10 has
now also gone offline. Fleet is at 8/10 (T2–T9 alive). Active still 2, so
the queue isn't yet starved — but with the queue shrinking and fleet
shrinking together, watch utilisation next cycle.

**zerotrade_rework_backlog held clear (8th cycle).** QM5_10027 resolution
durable; stable state.

`quota_snapshot_fresh` codex=24s / claude=24s — -2s vs prior. Holds well inside
the 24–35s band.

`codex_zero_activity` field reports 4 codex / 26 pending. Router status shows
codex running=0 and only 5 APPROVED + 1 REVIEW codex tasks total. Third cycle
in a row the health collector and router disagree on codex counts. Pattern
remains a stale snapshot in the collector, not a real codex spike; not
actionable from claude.

## QM5_10260 queue state

All 8 Q02 work_items remain `failed` with verdict `INVALID` (0 pending).
No change. Preflight reason still `setfile_missing` — forex M15 setfiles
referenced by failed work_items have not been pushed to main.

## Actions taken

None. No claude IN_PROGRESS task; router has no routable work; orchestration
cycle exits idle.

## Notes for next cycle

- **unbuilt_cards_count drain reversed (+139 → 818).** Last cycle's optimistic
  -97 drift did not extend. Pump auto-build is admitting cards faster than it
  ships ex5. Watch whether 818 is the new ceiling or continues rising.
- **unenqueued_eas escalates WARN → FAIL (+11 → 20).** Chronic nine baseline
  broken. New approved builds are not reaching Q02 work_items. Likely the
  pump's enqueue-after-build step is lagging the build stage. Owner / Codex
  ops issue, not a claude action.
- **MT5 fleet -1 (T10 dropped).** T1 + T10 both missing; active still 2.
  Acceptable for now; flag if active falls to 0 with pending > 0.
- zerotrade_rework_backlog clear sustained 8 cycles. Stable state.
- Pump exit 0 held for a twenty-sixth consecutive cycle. Stable.
- `quota_snapshot_fresh` -2s (26 → 24); baseline.
- Codex 5 APPROVED + 1 REVIEW flat vs last cycle. No task movement this
  30-min window.
- `codex_zero_activity` detail "4 codex, 26 pending" disagrees with router
  (0 running, 5 APPROVED + 1 REVIEW). Third consecutive cycle of disagreement
  — stale health-collector snapshot, not a real codex daemon problem.
- Disk D: 146.2 GB (-0.2 GB). Trivial.
- Worktree still carries unstaged framework EA modifications (QM5_10047
  ex5/mq5/set-files) from Codex; not part of this cycle's commit
  (explicit pathspec only).
- Headline blockers: schema blocker (2566 cards), unbuilt_cards_count=818
  (+139, regressing), unenqueued_eas=20 (chronic nine baseline broken),
  p2_pass_no_p3=127, T1+T10 terminal_workers missing.
- Upstream issues still sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
