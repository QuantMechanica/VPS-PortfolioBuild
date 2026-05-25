# Claude orchestration cycle — 2026-05-26 03:00Z

Single-pass cycle. Idle: no claude tasks in any state.

> **Label note.** The `2026-05-26 …Z` label series is the established sequential
> 30-min cadence used by prior cycles in this directory; actual wall-clock UTC
> at `checked_at` is `2026-05-25T14:00:35Z`. The label is ahead of real UTC by
> ~12h 30min — a long-standing convention drift, not a new error. Flag for
> OWNER to decide whether the series should be re-anchored.

## Router status

- claude: enabled, max_parallel=3, running=0
- codex: enabled, max_parallel=5, running=0 — 3 APPROVED build_ea + 2 APPROVED ops_issue + 1 REVIEW ops_issue (flat vs 0230Z)
- gemini: enabled, max_parallel=2, running=1 — 5 FAILED research_strategy + 1 IN_PROGRESS

`run --min-ready-strategy-cards 5 --max-routes 5` returned `no_routable_task`;
generic research replenishment remains frozen
(`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`,
ready_strategy_cards=0, approved_cards=2566, blocked_approved_cards=2566).
`route-many --max-routes 5` likewise returned `no_routable_task`.
`list-tasks --agent claude` returned `[]`.

## Health snapshot (farmctl)

Overall: FAIL (3 fail / 2 warn / 14 ok). checked_at 2026-05-25T14:00:35Z.

| Check | Value | Status | Δ vs 0230Z |
|---|---|---|---|
| mt5_worker_saturation | 8/10 alive (T2..T9; T1+T10 missing) | WARN | +0 |
| mt5_dispatch_idle | 688 pending, 8 active, 122 pwsh workers, 12 fresh work_item logs | OK | +45 / +0 |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 832 | FAIL | +0 (sixth flat cycle) |
| unenqueued_eas_count | 9 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079) | WARN | +0 (chronic-nine flat 7th cycle) |
| p_pass_stagnation | 0 P3+ PASS in 12h | FAIL | +0 |
| zerotrade_rework_backlog | 0 ("no uncovered recurrent zero-trade EAs") | OK | +0 (fifteenth clear cycle) |
| quota_snapshot_fresh | codex=42s, claude=42s | OK | -11s (53 → 42, back toward baseline) |
| pump_task_lastresult | exit 0 | OK | +0 (thirty-third consecutive cycle) |
| disk_free_gb | D: 142.8 | OK | -0.6 |
| codex_zero_activity | 5 codex, 3 pending | OK | +0 codex / -3 pending |
| approved_cards | 2566 (schema-blocked) | — | +0 |
| source_pool_drained | 12 pending sources | OK | +0 |

T1 + T10 still missing; fleet flat at 8/10 (eighth consecutive cycle). Pump
exit 0 holds (thirty-third consecutive cycle).

**mt5_dispatch_idle: 688 pending / 8 active (+45 / +0).** Backlog growth
decelerating: 472 → 518 → 590 → 643 → **688**. Five-cycle slope: +15, +46,
+72, +52, **+45**. Acceleration peaked at +72, now easing for the third
straight cycle. Direct DB read 30s later showed 705 pending (still admitting
actively); fleet=8 ship rate not catching up to admit rate, but the gap
continues to narrow.

**QM5_10260 still 8 failed + 3 pending Q02 (flat 4th cycle).** The NDX.DWX
/ SP500.DWX / WS30.DWX work_items (created 2026-05-25T12:43:15Z) are still
`pending` and unclaimed ~78 min after creation (in real UTC), now sitting
behind a 705-deep backlog. Four cycles of zero claim progress. The 8 failed
FX-pair INVALIDs remain unchanged. Watch.

**unbuilt_cards_count flat at 832 (sixth consecutive cycle).** Slope:
573 → 776 → 679 → 818 → 832 → 832 → 832 → 832 → 832 → 832 → **832**. Six
flat readings entrench the dispatch-over-admit equilibrium read. Pump is
admitting backtests faster than cards but not promoting cards to built EAs
at all. Structural to current build-bridge state.

**unenqueued_eas_count flat at 9 (chronic-nine, seventh consecutive cycle).**
Same nine names. 2330Z spike (20 names) remains the lone outlier.

**MT5 fleet 8/10, fully claiming.** T1 + T10 still down; active matches
worker count. Restart needs OWNER RDP per
`feedback_factory_interactive_visible_mode_2026-05-23`.

**zerotrade_rework_backlog held clear (15th cycle).** QM5_10027 resolution
durable.

`quota_snapshot_fresh` codex=42s / claude=42s — both back to baseline after
the 0230Z top-of-band touch (-11s). No alarm.

`codex_zero_activity` field counts task assignments not daemons (per memory
`project_qm_codex_daemon_priority_floor_2026-05-25`); -3 pending churn is
routing motion, not staleness.

`disk_free_gb` 142.8 (-0.6). Trivial accumulation.

## QM5_10260 queue state

- 8 work_items still `failed` / `INVALID` (the original FX pairs:
  AUDCAD, AUDCHF, AUDJPY, AUDNZD, AUDUSD, CADCHF, CADJPY, CHFJPY).
- 3 work_items still `pending` / unclaimed: NDX.DWX, SP500.DWX, WS30.DWX
  (Q02), created 2026-05-25T12:43:15Z. Not yet picked up by a worker
  ~78 min after creation (real UTC); now behind 705-deep backlog.

No claude action. The perf-rework issue noted in
`project_qm5_10260_q02_timeout_2026-05-22` (1800s TIMEOUTs on FX pairs) is
not resolved; the new attempts on index symbols sit behind the still-growing
queue.

## Actions taken

None. No claude IN_PROGRESS task; router has no routable work; orchestration
cycle exits idle.

## Notes for next cycle

- **Queue 688 pending / 8 active (+45 / +0).** Growth deceleration continues:
  +15 → +46 → +72 → +52 → +45. If the deceleration holds, admit may converge
  toward ship rate within a few cycles; net drain still requires either a
  fleet restore (T1+T10) or further admit slowdown.
- **QM5_10260 indexes still unclaimed (4th cycle).** Three Q02 pendings
  (NDX/SP500/WS30) have sat in the queue for ~78 min without claim. Confirm
  next cycle.
- **unbuilt_cards flat at 832 for sixth cycle.** Equilibrium entrenched.
- **unenqueued_eas flat at 9 seventh cycle.** Chronic-nine durable.
- **MT5 8/10 fleet flat eighth cycle.** T1+T10 restart still gated on OWNER
  RDP. With backlog now 688, restoration has growing material impact.
- Pump exit 0 sustained 33 cycles.
- `quota_snapshot_fresh` 53s → 42s (returned to baseline).
- `codex_zero_activity` 6 → 3 pending (assignment churn, not staleness).
- Disk D: 142.8 GB (-0.6). Trivial.
- Worktree still carries unstaged framework EA modifications (QM5_10047
  ex5/mq5/set-files) from Codex; not part of this cycle's commit
  (explicit pathspec only).
- **Date-label drift flagged for OWNER.** The cycle filename and header
  labels are ~12h 30min ahead of true UTC. Continuing the sequence to keep
  the docs monotonic; OWNER decides whether to re-anchor.
- Headline blockers: schema blocker (2566 cards), unbuilt_cards_count=832
  (sixth flat cycle), p2_pass_no_p3=127, T1+T10 terminal_workers missing,
  Q02 backlog now 688 pending with admit > ship (growth decelerating).
- Upstream issues still sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
