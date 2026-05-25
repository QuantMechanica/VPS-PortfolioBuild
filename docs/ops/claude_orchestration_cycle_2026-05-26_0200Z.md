# Claude orchestration cycle — 2026-05-26 02:00Z

Single-pass cycle. Idle: no claude tasks in any state.

## Router status

- claude: enabled, max_parallel=3, running=0
- codex: enabled, max_parallel=5, running=0 — 3 APPROVED build_ea + 2 APPROVED ops_issue + 1 REVIEW ops_issue (flat vs 0130Z)
- gemini: enabled, max_parallel=2, running=1 — 5 FAILED research_strategy + 1 IN_PROGRESS

`run --min-ready-strategy-cards 5 --max-routes 5` returned `no_routable_task`;
generic research replenishment remains frozen
(`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`,
ready_strategy_cards=0, approved_cards=2566, blocked_approved_cards=2566).
`route-many --max-routes 5` likewise returned `no_routable_task`.
`list-tasks --agent claude` returned `[]`.

## Health snapshot (farmctl)

Overall: FAIL (3 fail / 2 warn / 14 ok). checked_at 2026-05-25T13:30:17Z.

| Check | Value | Status | Δ vs 0130Z |
|---|---|---|---|
| mt5_worker_saturation | 8/10 alive (T2..T9; T1+T10 missing) | WARN | +0 |
| mt5_dispatch_idle | 590 pending, 7 active, 116 pwsh workers, 9 fresh work_item logs | OK | +72 / -1 |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 832 | FAIL | +0 (fourth flat cycle) |
| unenqueued_eas_count | 9 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079) | WARN | +0 (chronic-nine flat 5th cycle) |
| p_pass_stagnation | 0 P3+ PASS in 12h | FAIL | +0 |
| zerotrade_rework_backlog | 0 ("no uncovered recurrent zero-trade EAs") | OK | +0 (thirteenth clear cycle) |
| quota_snapshot_fresh | codex=27s, claude=27s | OK | -4s (31 → 27, baseline) |
| pump_task_lastresult | exit 0 | OK | +0 (thirty-first consecutive cycle) |
| disk_free_gb | D: 144.4 | OK | -0.6 |
| codex_zero_activity | 2 codex, 4 pending | OK | -4 codex / -2 pending |
| approved_cards | 2566 (schema-blocked) | — | +0 |
| source_pool_drained | 12 pending sources | OK | +0 |

T1 + T10 still missing; fleet flat at 8/10 (sixth consecutive cycle). Pump
exit 0 holds (thirty-first consecutive cycle).

**mt5_dispatch_idle: 590 pending / 7 active (+72 / -1).** Backlog still
climbing — pending grew another 72 in this 30-min window. Direct DB snapshot
read 589 pending / 8 active (small race vs health snapshot's 590/7;
substantively identical). Three-cycle slope on pending: 457 → 472 → 518 →
**590**. Admit > ship continues at fleet=8. Growth rate per cycle: +15,
+46, +72 — accelerating. Not yet a structural alarm (queue depth and
phase-timeout still healthy), but the divergence is widening. Drain
becomes meaningful only when fleet returns to 10 or admission slows.

**QM5_10260 still 8 failed + 3 pending Q02 (flat).** The NDX.DWX /
SP500.DWX / WS30.DWX work_items (created 2026-05-25T12:43:15Z) are
*still* `pending` and unclaimed ~77 min after creation. They now sit
behind a 589-deep backlog. Two cycles of zero claim progress on the
indexes. The 8 failed FX-pair INVALIDs remain unchanged. Watch.

**unbuilt_cards_count flat at 832 (fourth consecutive cycle).** Slope:
573 → 776 → 679 → 818 → 832 → 832 → 832 → 832 → **832**. Four flat
readings reinforce the dispatch-over-admit equilibrium read. Pump is
admitting backtests faster than cards but not promoting cards to built
EAs at all. Backlog of unbuilt cards is structural to the current
build-bridge state, not a transient dispatch lag.

**unenqueued_eas_count flat at 9 (chronic-nine, fifth consecutive cycle).**
Same nine names: QM5_10019/10021/10028/10035/10039/10043/10044/10076/10079.
2330Z spike (20 names) remains the lone outlier; chronic-nine is the
stable baseline.

**MT5 fleet 8/10, fully claiming.** T1 + T10 still down; active matches
worker count. Restart needs OWNER RDP per
`feedback_factory_interactive_visible_mode_2026-05-23`. Not a Claude
action. With pending now 590 and acceleration trend, restoring the
missing two terminals would have growing material impact.

**zerotrade_rework_backlog held clear (13th cycle).** QM5_10027 resolution
durable.

`quota_snapshot_fresh` codex=27s / claude=27s — clean baseline.

`codex_zero_activity` detail 6 → 2 codex; pending 6 → 4. Smaller delta
than earlier cycles. Field counts task assignments not daemons
(per memory `project_qm_codex_daemon_priority_floor_2026-05-25`), so
this likely reflects task-routing churn — no real signal about daemon
health.

`disk_free_gb` 144.4 (-0.6). Normal accumulation.

## QM5_10260 queue state

- 8 work_items still `failed` / `INVALID` (the original FX pairs:
  AUDCAD, AUDCHF, AUDJPY, AUDNZD, AUDUSD, CADCHF, CADJPY, CHFJPY).
- 3 work_items still `pending` / unclaimed: NDX.DWX, SP500.DWX, WS30.DWX
  (Q02), created 2026-05-25T12:43:15Z. Not yet picked up by a worker
  ~77 min after creation; now behind 589-deep backlog.

No claude action. The perf-rework issue noted in
`project_qm5_10260_q02_timeout_2026-05-22` (1800s TIMEOUTs on FX pairs) is
not resolved; the new attempts on index symbols sit behind the still-growing
queue.

## Actions taken

None. No claude IN_PROGRESS task; router has no routable work; orchestration
cycle exits idle.

## Notes for next cycle

- **Queue 590 pending / 7 active (+72 / -1).** Growth accelerating
  (+15 → +46 → +72 over last three cycles). Watch whether this trend
  continues or peaks; structural alarm threshold not yet hit but the
  divergence is widening.
- **QM5_10260 indexes still unclaimed.** Three Q02 pendings (NDX/SP500/WS30)
  have sat in the queue for ~77 min without claim. Two cycles of zero
  movement. Confirm next cycle.
- **unbuilt_cards flat at 832 for fourth cycle.** Equilibrium consolidated
  — dispatch is the bottleneck, not card admission. If count starts
  climbing as pending grows, the structural-gap diagnosis returns.
- **unenqueued_eas flat at 9 fifth cycle.** Chronic-nine durable.
- **MT5 8/10 fleet flat sixth cycle.** T1+T10 restart still gated on OWNER
  RDP. With backlog accelerating, restoration has growing material impact.
- Pump exit 0 sustained 31 cycles.
- `quota_snapshot_fresh` 31 → 27s (baseline).
- `codex_zero_activity` 6 → 2 / 6 → 4 (assignment-count churn, not
  staleness).
- Disk D: 144.4 GB (-0.6). Trivial accumulation.
- Worktree still carries unstaged framework EA modifications (QM5_10047
  ex5/mq5/set-files) from Codex; not part of this cycle's commit
  (explicit pathspec only).
- Headline blockers: schema blocker (2566 cards), unbuilt_cards_count=832
  (fourth flat cycle), p2_pass_no_p3=127, T1+T10 terminal_workers missing,
  accelerating Q02 backlog (now 590 pending) with admit > ship.
- Upstream issues still sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
