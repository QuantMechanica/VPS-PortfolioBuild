# Claude orchestration cycle — 2026-05-26 00:30Z

Single-pass cycle. Idle: no claude tasks in any state.

## Router status

- claude: enabled, max_parallel=3, running=0
- codex: enabled, max_parallel=5, running=0 — 3 APPROVED build_ea + 2 APPROVED ops_issue + 1 REVIEW ops_issue (flat vs 0000Z)
- gemini: enabled, max_parallel=2, running=1 — 5 FAILED research_strategy + 1 IN_PROGRESS

`run --min-ready-strategy-cards 5 --max-routes 5` returned `no_routable_task`;
generic research replenishment remains frozen
(`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`,
ready_strategy_cards=0, approved_cards=2566, blocked_approved_cards=2566).
`route-many --max-routes 5` likewise returned `no_routable_task`.
`list-tasks --agent claude` returned `[]`.

## Health snapshot (farmctl)

Overall: FAIL (3 fail / 2 warn / 14 ok). checked_at 2026-05-25T12:45:34Z.

| Check | Value | Status | Δ vs 0000Z |
|---|---|---|---|
| mt5_worker_saturation | 8/10 alive (T1, T10 missing) | WARN | +0 |
| mt5_dispatch_idle | 457 pending, 8 active, 120 pwsh workers | OK | **+449 / +6** |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 832 | FAIL | +0 (flat) |
| unenqueued_eas_count | 9 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079) | WARN | +0 (chronic-nine flat) |
| p_pass_stagnation | 0 P3+ PASS in 12h | FAIL | +0 |
| zerotrade_rework_backlog | 0 ("no uncovered recurrent zero-trade EAs") | OK | +0 (tenth clear cycle) |
| quota_snapshot_fresh | codex=43s, claude=43s | OK | +18s (25 → 43, still in band) |
| pump_task_lastresult | exit 0 | OK | +0 (twenty-eighth consecutive cycle) |
| disk_free_gb | D: 146.1 | OK | -0.1 |
| codex_zero_activity | 6 codex, 6 pending | OK | +2 codex (4 → 6) |
| approved_cards | 2566 (schema-blocked) | — | +0 |
| source_pool_drained | 12 pending sources | OK | +0 |

T1 + T10 still missing; fleet flat at 8/10. Pump exit 0 holds (twenty-eighth
consecutive cycle).

**mt5_dispatch_idle queue surged: 8 → 457 pending, 2 → 8 active.** A large
batch of work_items got enqueued in the 30-min window between cycles. The
+449 pending implies a substantial pump dispatch run — likely tied to the
QM5_10260 re-enqueue and/or other EAs the pump has been carrying. Active
also jumped 2 → 8 — fleet is now saturated to the live worker count
(8/10 — every alive terminal is claiming work). Read: factory throughput
just unblocked; the eight live terminal_workers are now busy. The 457
backlog will drain over the next several cycles assuming no new failure
mode.

**QM5_10260 just got 3 new Q02 pending work_items.** First movement in nine
cycles. The three pendings are NDX.DWX, SP500.DWX, WS30.DWX (index
symbols), created 2026-05-25T12:43:15Z — about two minutes before this
cycle's health check. The eight original failed work_items (FX pairs)
remain INVALID. So QM5_10260 didn't unblock the failed history; an
index-only retry was enqueued. Note: SP500.DWX is backtest-only per
`reference_dwx_sp500_unavailable` — fine for Q02 evidence but won't
promote to live; NDX/WS30 are the routable index targets per
`feedback_spx500_card_port_before_build`.

**unbuilt_cards_count flat at 832.** Five-cycle slope: 573 → 776 → 679 →
818 → 832 → **832**. First flat reading after four cycles of climb. With
the queue surging 8 → 457 and 8 active terminals, this is consistent with
the pump shifting effort from card admission to dispatching the backlog
through Q02 — admit rate slowed because the pump is busy producing
work_items, not because ship rate caught up. Watch next cycle: if 832
holds and queue drains, the divergence narrative was a transient handoff
lag; if 832 starts climbing again as queue drains, the throughput gap is
real.

**unenqueued_eas_count flat at 9.** Same nine names (QM5_10019/10021/
10028/10035/10039/10043/10044/10076/10079) — chronic baseline stable two
cycles after the 2330Z spike. Confirms 2330Z (20 names) was a transient
backlog at the build → enqueue handoff.

**MT5 fleet still 8/10 — but now fully claiming.** T1 + T10 missing, but
all 8 alive terminals are active (active=8 = workers alive). 449 pending
work_items behind the active wave. Saturation pressure now present but
worker count cannot grow without T1/T10 restart — which per
`feedback_factory_interactive_visible_mode_2026-05-23` requires OWNER's
RDP session, not auto-recovery.

**zerotrade_rework_backlog held clear (10th cycle).** QM5_10027
resolution durable; stable state.

`quota_snapshot_fresh` codex=43s / claude=43s — +18s vs prior 25s.
Inside the 24–43s observed band but at the high end. Likely just normal
jitter; revisit if it stays >60s.

`codex_zero_activity` field now 6 codex / 6 pending. Router still shows
codex running=0, so detail-vs-router disagreement returned this cycle
(router says no codex IN_PROGRESS; collector says 6 codex active).
The 6 codex value matches the 3 APPROVED build_ea + 2 APPROVED ops_issue
+ 1 REVIEW ops_issue total — i.e. it's counting open task assignments,
not actually-running daemons. Mirror of the prior 4-codex / 6-pending
ambiguity. Not a real outage signal; the field semantics are loose.

## QM5_10260 queue state

- 8 work_items still `failed` / `INVALID` (the original FX pairs:
  AUDCAD, AUDCHF, AUDJPY, AUDNZD, AUDUSD, CADCHF, CADJPY, CHFJPY).
- **3 work_items newly `pending`**: NDX.DWX, SP500.DWX, WS30.DWX (Q02),
  created 2026-05-25T12:43:15Z, not yet claimed.

No claude action — index-symbol retry was enqueued by the pump or an
ops process. The perf-rework issue noted in
`project_qm5_10260_q02_timeout_2026-05-22` (1800s TIMEOUTs on FX pairs)
is not resolved; this is a different attempt on index symbols only.

## Actions taken

None. No claude IN_PROGRESS task; router has no routable work; orchestration
cycle exits idle.

## Notes for next cycle

- **Queue surged +449 pending / +6 active.** The factory just got a large
  dispatch batch. Fleet is fully claiming at 8/10. Watch drain over next
  several cycles — at 8 concurrent terminals and prior throughput,
  draining 457 work_items will take many cycles. If pending falls without
  failed-rate spiking, the surge resolves cleanly.
- **QM5_10260 first movement in 9 cycles** — 3 new Q02 pendings for index
  symbols (NDX/SP500/WS30). The 8 failed FX-pair Q02s remain unchanged.
  Observe whether these new attempts complete cleanly or TIMEOUT like the
  FX series.
- **unbuilt_cards flat at 832 after four cycles of climb.** Pump appears
  to have shifted to dispatching the queue rather than admitting more
  cards. If 832 stays flat or drops next cycle, the +14/+139 spikes were
  build-vs-ship lag, not a structural problem.
- **unenqueued_eas flat at 9** (chronic baseline). Confirms 2330Z spike
  was transient. Same nine names two cycles running.
- `codex_zero_activity` detail now counts task assignments, not daemons.
  Disagreement with router status is field semantics, not staleness.
  No real signal; ignore unless absolute number changes meaningfully.
- zerotrade_rework_backlog clear sustained 10 cycles. Stable.
- Pump exit 0 held for twenty-eighth consecutive cycle. Stable.
- `quota_snapshot_fresh` +18s (25 → 43); top of normal band. Flag if
  it goes >60s next cycle.
- Disk D: 146.1 GB (-0.1). Trivial.
- Worktree still carries unstaged framework EA modifications (QM5_10047
  ex5/mq5/set-files) from Codex; not part of this cycle's commit
  (explicit pathspec only).
- Headline blockers: schema blocker (2566 cards), unbuilt_cards_count=832
  (flat this cycle), p2_pass_no_p3=127, T1+T10 terminal_workers missing.
- Upstream issues still sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
