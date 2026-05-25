# Claude orchestration cycle — 2026-05-26 00:00Z

Single-pass cycle. Idle: no claude tasks in any state.

## Router status

- claude: enabled, max_parallel=3, running=0
- codex: enabled, max_parallel=5, running=0 — 3 APPROVED build_ea + 2 APPROVED ops_issue + 1 REVIEW ops_issue (flat vs 2330Z)
- gemini: enabled, max_parallel=2, running=1 — 5 FAILED research_strategy + 1 IN_PROGRESS

`run --min-ready-strategy-cards 5 --max-routes 5` returned `no_routable_task`;
generic research replenishment remains frozen
(`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`,
ready_strategy_cards=0, approved_cards=2566, blocked_approved_cards=2566).
`route-many --max-routes 5` likewise returned `no_routable_task`.
`list-tasks --agent claude` returned `[]`.

## Health snapshot (farmctl)

Overall: FAIL (3 fail / 2 warn / 14 ok). checked_at 2026-05-25T12:30:16Z.

| Check | Value | Status | Δ vs 2330Z |
|---|---|---|---|
| mt5_worker_saturation | 8/10 alive (T1, T10 missing) | WARN | +0 |
| mt5_dispatch_idle | 8 pending, 2 active | OK | +0 / +0 |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 832 | FAIL | **+14** (818 → 832) |
| unenqueued_eas_count | 9 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079) | WARN | **-11** (20 → 9 — recovers to chronic-nine baseline) |
| p_pass_stagnation | 0 P3+ PASS in 12h | FAIL | +0 |
| zerotrade_rework_backlog | 0 ("no uncovered recurrent zero-trade EAs") | OK | +0 (ninth clear cycle) |
| quota_snapshot_fresh | codex=25s, claude=25s | OK | +1s (24 → 25) |
| pump_task_lastresult | exit 0 | OK | +0 (twenty-seventh consecutive cycle) |
| disk_free_gb | D: 146.2 | OK | +0 |
| codex_zero_activity | 4 codex, 6 pending | OK | **-20 pending** (26 → 6 — now matches router) |
| approved_cards | 2566 (schema-blocked) | — | +0 |
| source_pool_drained | 12 pending sources | OK | +0 |

T1 + T10 still missing; fleet flat at 8/10. Pump exit 0 holds (twenty-seventh
consecutive cycle).

**unenqueued_eas_count recovers WARN (20 → 9).** Last cycle's spike off the
chronic-nine baseline reversed in one cycle. The check is back to the same
nine names (QM5_10019/10021/10028/10035/10039/10043/10044/10076/10079) that
held for seven cycles before the 2330Z bump. The eleven extras enqueued
through to Q02 work_items between cycles. Status downgrades FAIL → WARN.
Read: 2330Z was a transient backlog at the build → enqueue handoff, not a
durable break; the pump's enqueue step caught up.

**unbuilt_cards_count +14 (818 → 832).** Still rising, but the +139 surge
from 2330Z did not extend at the same rate. Pump exit 0 throughout; admit
slightly exceeds ship. Slope: 573 → 776 → 679 → 818 → 832. The optimistic
read remains "auto-build is producing ex5 fast enough that the pump just
admits more"; the pessimistic read is "ex5 ship rate is throttled by
something other than build success and the gap will widen." Watch slope
next cycle: a single-digit climb is noise, a +50+ would confirm pessimistic.

**MT5 fleet flat at 8/10.** T1 + T10 both still offline. Active still 2,
pending still 8 — fleet sized to current queue. No saturation pressure.

**zerotrade_rework_backlog held clear (9th cycle).** QM5_10027 resolution
durable; stable state.

`quota_snapshot_fresh` codex=25s / claude=25s — +1s vs prior. Inside the
24–35s observed band.

`codex_zero_activity` field now reports 4 codex / 6 pending — matches the
router's 5 APPROVED + 1 REVIEW exactly. The three-cycle stale-collector
disagreement from 2230Z–2330Z has cleared. The snapshot is fresh again;
no codex daemon issue ever existed (as suspected last cycle).

## QM5_10260 queue state

All 8 Q02 work_items remain `failed` with verdict `INVALID` (0 pending).
No change ninth consecutive orchestration cycle. Preflight reason
unchanged. Perf rework still not in.

## Actions taken

None. No claude IN_PROGRESS task; router has no routable work; orchestration
cycle exits idle.

## Notes for next cycle

- **unenqueued_eas recovered to chronic-nine baseline (20 → 9).** WARN/FAIL
  oscillation cleared in one cycle — confirms 2330Z was a transient
  build → enqueue lag, not a structural break. Watch for repeat; if the
  20+ spike returns and persists, escalate to ops.
- **unbuilt_cards_count +14 → 832.** Slope decelerated from +139 last
  cycle but the climb continues. Pump is admitting faster than it ships.
  Slope to watch: single-digit = noise, +50+ next cycle = real divergence.
- **codex_zero_activity collector resynced.** Detail now matches router
  (4 codex / 6 pending vs 0 running / 6 approved+review). Three-cycle
  staleness window closed; no real codex daemon problem.
- zerotrade_rework_backlog clear sustained 9 cycles. Stable.
- Pump exit 0 held for twenty-seventh consecutive cycle. Stable.
- `quota_snapshot_fresh` +1s (24 → 25); baseline.
- MT5 fleet flat 8/10 (T1, T10 missing). Active 2 / pending 8 — fleet
  matches queue; no starvation. Flag if active falls to 0 with pending > 0.
- Codex 5 APPROVED + 1 REVIEW flat vs last cycle — no task movement this
  30-min window.
- Disk D: 146.2 GB (flat). Trivial.
- Worktree still carries unstaged framework EA modifications (QM5_10047
  ex5/mq5/set-files) from Codex; not part of this cycle's commit
  (explicit pathspec only).
- Headline blockers: schema blocker (2566 cards), unbuilt_cards_count=832
  (+14, still slowly climbing), p2_pass_no_p3=127, T1+T10
  terminal_workers missing.
- Upstream issues still sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
