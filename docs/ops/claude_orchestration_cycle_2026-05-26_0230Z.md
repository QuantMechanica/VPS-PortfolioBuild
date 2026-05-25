# Claude orchestration cycle — 2026-05-26 02:30Z

Single-pass cycle. Idle: no claude tasks in any state.

## Router status

- claude: enabled, max_parallel=3, running=0
- codex: enabled, max_parallel=5, running=0 — 3 APPROVED build_ea + 2 APPROVED ops_issue + 1 REVIEW ops_issue (flat vs 0200Z)
- gemini: enabled, max_parallel=2, running=1 — 5 FAILED research_strategy + 1 IN_PROGRESS

`run --min-ready-strategy-cards 5 --max-routes 5` returned `no_routable_task`;
generic research replenishment remains frozen
(`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`,
ready_strategy_cards=0, approved_cards=2566, blocked_approved_cards=2566).
`route-many --max-routes 5` likewise returned `no_routable_task`.
`list-tasks --agent claude` returned `[]`.

## Health snapshot (farmctl)

Overall: FAIL (3 fail / 2 warn / 14 ok). checked_at 2026-05-25T13:45:39Z.

| Check | Value | Status | Δ vs 0200Z |
|---|---|---|---|
| mt5_worker_saturation | 8/10 alive (T2..T9; T1+T10 missing) | WARN | +0 |
| mt5_dispatch_idle | 643 pending, 8 active, 118 pwsh workers, 12 fresh work_item logs | OK | +53 / +1 |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 832 | FAIL | +0 (fifth flat cycle) |
| unenqueued_eas_count | 9 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079) | WARN | +0 (chronic-nine flat 6th cycle) |
| p_pass_stagnation | 0 P3+ PASS in 12h | FAIL | +0 |
| zerotrade_rework_backlog | 0 ("no uncovered recurrent zero-trade EAs") | OK | +0 (fourteenth clear cycle) |
| quota_snapshot_fresh | codex=53s, claude=51s | OK | +26s (27 → 53, top of normal band) |
| pump_task_lastresult | exit 0 | OK | +0 (thirty-second consecutive cycle) |
| disk_free_gb | D: 143.4 | OK | -1.0 |
| codex_zero_activity | 5 codex, 6 pending | OK | +3 codex / +2 pending |
| approved_cards | 2566 (schema-blocked) | — | +0 |
| source_pool_drained | 12 pending sources | OK | +0 |

T1 + T10 still missing; fleet flat at 8/10 (seventh consecutive cycle). Pump
exit 0 holds (thirty-second consecutive cycle).

**mt5_dispatch_idle: 643 pending / 8 active (+53 / +1).** Backlog still
climbing but growth decelerated this cycle. Direct DB snapshot read 642
pending / 8 active (small race; substantively identical). Four-cycle slope
on pending: 472 → 518 → 590 → **643**. Growth rate per cycle: +15, +46,
+72, **+52**. Acceleration peaked at +72 last cycle and has now eased.
Admit still > ship at fleet=8, but the gap is narrowing. Drain becomes
meaningful only when fleet returns to 10 or admission slows further.

**QM5_10260 still 8 failed + 3 pending Q02 (flat).** The NDX.DWX /
SP500.DWX / WS30.DWX work_items (created 2026-05-25T12:43:15Z) are
*still* `pending` and unclaimed ~107 min after creation. They now sit
behind a 642-deep backlog. Three cycles of zero claim progress on the
indexes. The 8 failed FX-pair INVALIDs remain unchanged. Watch.

**unbuilt_cards_count flat at 832 (fifth consecutive cycle).** Slope:
573 → 776 → 679 → 818 → 832 → 832 → 832 → 832 → 832 → **832**. Five flat
readings entrench the dispatch-over-admit equilibrium read. Pump is
admitting backtests faster than cards but not promoting cards to built
EAs at all. Backlog of unbuilt cards is structural to the current
build-bridge state, not a transient dispatch lag.

**unenqueued_eas_count flat at 9 (chronic-nine, sixth consecutive cycle).**
Same nine names: QM5_10019/10021/10028/10035/10039/10043/10044/10076/10079.
2330Z spike (20 names) remains the lone outlier; chronic-nine is the
stable baseline.

**MT5 fleet 8/10, fully claiming.** T1 + T10 still down; active matches
worker count. Restart needs OWNER RDP per
`feedback_factory_interactive_visible_mode_2026-05-23`. Not a Claude
action. With pending now 643, restoring the missing two terminals would
have growing material impact.

**zerotrade_rework_backlog held clear (14th cycle).** QM5_10027 resolution
durable.

`quota_snapshot_fresh` codex=53s / claude=51s — top of normal band (+26s
vs 0200Z's 27s). Still well under the 300s threshold; no alarm, but
worth noting whether next cycle returns to baseline or holds elevated.

`codex_zero_activity` detail 2 → 5 codex; pending 4 → 6. Field counts task
assignments not daemons (per memory
`project_qm_codex_daemon_priority_floor_2026-05-25`), so the +3/+2 churn
reflects task-routing not daemon health.

`disk_free_gb` 143.4 (-1.0). Slightly larger accumulation than recent
cycles but still well above the 25 GB threshold.

## QM5_10260 queue state

- 8 work_items still `failed` / `INVALID` (the original FX pairs:
  AUDCAD, AUDCHF, AUDJPY, AUDNZD, AUDUSD, CADCHF, CADJPY, CHFJPY).
- 3 work_items still `pending` / unclaimed: NDX.DWX, SP500.DWX, WS30.DWX
  (Q02), created 2026-05-25T12:43:15Z. Not yet picked up by a worker
  ~107 min after creation; now behind 642-deep backlog.

No claude action. The perf-rework issue noted in
`project_qm5_10260_q02_timeout_2026-05-22` (1800s TIMEOUTs on FX pairs) is
not resolved; the new attempts on index symbols sit behind the still-growing
queue.

## Actions taken

None. No claude IN_PROGRESS task; router has no routable work; orchestration
cycle exits idle.

## Notes for next cycle

- **Queue 643 pending / 8 active (+53 / +1).** Growth decelerated from
  +72 to +52. Watch whether the +15 → +46 → +72 → +52 sequence continues
  to ease toward zero or rebounds; structural alarm threshold not yet hit
  but four straight cycles of net positive admit-over-ship is the trend.
- **QM5_10260 indexes still unclaimed.** Three Q02 pendings (NDX/SP500/WS30)
  have sat in the queue for ~107 min without claim. Three cycles of zero
  movement. Confirm next cycle.
- **unbuilt_cards flat at 832 for fifth cycle.** Equilibrium consolidated —
  dispatch is the bottleneck, not card admission. If count starts climbing
  as pending grows, the structural-gap diagnosis returns.
- **unenqueued_eas flat at 9 sixth cycle.** Chronic-nine durable.
- **MT5 8/10 fleet flat seventh cycle.** T1+T10 restart still gated on OWNER
  RDP. With backlog above 600, restoration has growing material impact.
- Pump exit 0 sustained 32 cycles.
- `quota_snapshot_fresh` 27 → 53s (top of normal band; no alarm).
- `codex_zero_activity` 2 → 5 / 4 → 6 (assignment-count churn, not
  staleness).
- Disk D: 143.4 GB (-1.0). Trivial accumulation.
- Worktree still carries unstaged framework EA modifications (QM5_10047
  ex5/mq5/set-files) from Codex; not part of this cycle's commit
  (explicit pathspec only).
- Headline blockers: schema blocker (2566 cards), unbuilt_cards_count=832
  (fifth flat cycle), p2_pass_no_p3=127, T1+T10 terminal_workers missing,
  Q02 backlog now 643 pending with admit > ship (growth decelerating).
- Upstream issues still sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
