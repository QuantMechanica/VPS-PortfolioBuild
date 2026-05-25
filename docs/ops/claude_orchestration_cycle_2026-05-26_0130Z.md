# Claude orchestration cycle — 2026-05-26 01:30Z

Single-pass cycle. Idle: no claude tasks in any state.

## Router status

- claude: enabled, max_parallel=3, running=0
- codex: enabled, max_parallel=5, running=0 — 3 APPROVED build_ea + 2 APPROVED ops_issue + 1 REVIEW ops_issue (flat vs 0100Z)
- gemini: enabled, max_parallel=2, running=1 — 5 FAILED research_strategy + 1 IN_PROGRESS

`run --min-ready-strategy-cards 5 --max-routes 5` returned `no_routable_task`;
generic research replenishment remains frozen
(`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`,
ready_strategy_cards=0, approved_cards=2566, blocked_approved_cards=2566).
`route-many --max-routes 5` likewise returned `no_routable_task`.
`list-tasks --agent claude` returned `[]`.

## Health snapshot (farmctl)

Overall: FAIL (3 fail / 2 warn / 14 ok). checked_at 2026-05-25T13:15:22Z.

| Check | Value | Status | Δ vs 0100Z |
|---|---|---|---|
| mt5_worker_saturation | 8/10 alive (T1, T10 missing) | WARN | +0 |
| mt5_dispatch_idle | 518 pending, 8 active, 115 pwsh workers, 11 fresh work_item logs | OK | +46 / +0 |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 832 | FAIL | +0 (third flat cycle) |
| unenqueued_eas_count | 9 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079) | WARN | +0 (chronic-nine flat 4th cycle) |
| p_pass_stagnation | 0 P3+ PASS in 12h | FAIL | +0 |
| zerotrade_rework_backlog | 0 ("no uncovered recurrent zero-trade EAs") | OK | +0 (twelfth clear cycle) |
| quota_snapshot_fresh | codex=31s, claude=31s | OK | -16s (47 → 31, back to baseline) |
| pump_task_lastresult | exit 0 | OK | +0 (thirtieth consecutive cycle) |
| disk_free_gb | D: 145.0 | OK | -0.5 |
| codex_zero_activity | 6 codex, 6 pending | OK | +1 codex (5 → 6) |
| approved_cards | 2566 (schema-blocked) | — | +0 |
| source_pool_drained | 12 pending sources | OK | +0 |

T1 + T10 still missing; fleet flat at 8/10 (fifth consecutive cycle). Pump
exit 0 holds (thirtieth consecutive cycle).

**mt5_dispatch_idle: 518 pending / 8 active (+46 / +0).** Backlog continues
to climb — pending grew another 46 in this 30-min window while active held
at 8 (full fleet claiming). Two-cycle slope on pending: 8 → 457 → 472 →
**518**. The 0030Z surge (8 → 457) drained briefly (472) and is now
re-accumulating. Admit > ship: pump is enqueueing faster than the 8 alive
terminals can run backtests. Not yet a structural alarm — well within Q02
queue lifecycle — but the drain is not happening at fleet=8. Restoring T1+T10
would help; that's an OWNER RDP action.

**QM5_10260 still 8 failed + 3 pending Q02 (flat).** The NDX.DWX /
SP500.DWX / WS30.DWX work_items enqueued at 0030Z (created
2026-05-25T12:43:15Z) are *still* `pending` and unclaimed at this cycle's
check, ~47 min after creation. They now sit behind a 518-deep backlog
(vs 472 last cycle). Ordering not visible from this surface; index symbols
may need specific worker conditions or are simply queue-tail. The 8 failed
FX-pair INVALIDs remain unchanged. Watch.

**unbuilt_cards_count flat at 832 (third consecutive cycle).** Slope:
573 → 776 → 679 → 818 → 832 → 832 → 832 → **832**. Three flat readings
consolidate the read that the pump is currently prioritising dispatch over
card admission. The structural admit-vs-ship gap is paused; whether that
holds depends on the next pump tick.

**unenqueued_eas_count flat at 9 (chronic-nine, fourth consecutive cycle).**
Same nine names: QM5_10019/10021/10028/10035/10039/10043/10044/10076/10079.
2330Z spike (20 names) remains the lone outlier; chronic-nine is the stable
baseline.

**MT5 fleet 8/10, fully claiming.** T1 + T10 still down; active=8 matches
worker count. Restart needs OWNER RDP per
`feedback_factory_interactive_visible_mode_2026-05-23`. Not a Claude action.
With pending now 518 and admit > ship, restoring the missing two terminals
would meaningfully accelerate drain.

**zerotrade_rework_backlog held clear (12th cycle).** QM5_10027 resolution
durable.

`quota_snapshot_fresh` codex=31s / claude=31s — back to the 24–35s baseline
band after touching the top at 0100Z (47s). Normal jitter.

`codex_zero_activity` detail flipped 5 → 6 codex; pending held at 6. Field
counts task assignments not daemons (per memory), so the +1 likely captures
the same set differently — no real signal.

`disk_free_gb` 145.0 (-0.5). Normal accumulation.

`mt5_dispatch_idle` detail now reports "11 fresh work_item logs" — implies
recent activity in the queue surface, consistent with both admit and
dispatch happening.

## QM5_10260 queue state

- 8 work_items still `failed` / `INVALID` (the original FX pairs:
  AUDCAD, AUDCHF, AUDJPY, AUDNZD, AUDUSD, CADCHF, CADJPY, CHFJPY).
- 3 work_items still `pending` / unclaimed: NDX.DWX, SP500.DWX, WS30.DWX
  (Q02), created 2026-05-25T12:43:15Z. Not yet picked up by a worker
  ~47 min after creation; now behind 518-deep backlog.

No claude action. The perf-rework issue noted in
`project_qm5_10260_q02_timeout_2026-05-22` (1800s TIMEOUTs on FX pairs) is
not resolved; the new attempts on index symbols sit behind the growing
queue.

## Actions taken

None. No claude IN_PROGRESS task; router has no routable work; orchestration
cycle exits idle.

## Notes for next cycle

- **Queue 518 pending / 8 active (+46 / +0).** Backlog still climbing —
  admit > ship at fleet=8. Two cycles of net build from the post-surge
  draining state (472 → 518). If T1+T10 stay down, watch whether the
  growth rate continues or peaks; either way drain becomes meaningful
  only when fleet returns to 10 or admit slows.
- **QM5_10260 indexes still unclaimed.** Three Q02 pendings (NDX/SP500/WS30)
  have sat in the queue for ~47 min without claim. Confirm next cycle.
- **unbuilt_cards flat at 832 for third cycle.** Build/ship balance still
  paused on this surface. If the count restarts climbing as the queue keeps
  growing, the structural-gap diagnosis is back; another flat reading
  consolidates the new equilibrium.
- **unenqueued_eas flat at 9 fourth cycle.** Chronic-nine durable.
- **MT5 8/10 fleet flat fifth cycle.** T1+T10 restart still gated on OWNER
  RDP. With backlog growing, restoration would have material impact.
- Pump exit 0 sustained 30 cycles.
- `quota_snapshot_fresh` 47 → 31s (back to baseline) — no concern.
- `codex_zero_activity` 5 → 6 (assignment-count jitter, not staleness).
- Disk D: 145.0 GB (-0.5). Trivial accumulation.
- Worktree still carries unstaged framework EA modifications (QM5_10047
  ex5/mq5/set-files) from Codex; not part of this cycle's commit
  (explicit pathspec only).
- Headline blockers: schema blocker (2566 cards), unbuilt_cards_count=832
  (third flat cycle), p2_pass_no_p3=127, T1+T10 terminal_workers missing,
  growing 518-deep Q02 backlog with admit > ship.
- Upstream issues still sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
