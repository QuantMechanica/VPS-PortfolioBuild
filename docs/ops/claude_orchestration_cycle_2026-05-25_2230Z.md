# Claude orchestration cycle — 2026-05-25 22:30Z

Single-pass cycle. Idle: no claude tasks in any state.

## Router status

- claude: enabled, max_parallel=3, running=0
- codex: enabled, max_parallel=5, running=0 — 3 APPROVED build_ea + 2 APPROVED ops_issue + 1 REVIEW ops_issue
- gemini: enabled, max_parallel=2, running=1 — 5 FAILED research_strategy + 1 IN_PROGRESS

`run --min-ready-strategy-cards 5 --max-routes 5` returned `no_routable_task`;
generic research replenishment remains frozen
(`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`,
ready_strategy_cards=0, approved_cards=2566, blocked_approved_cards=2566).
`route-many --max-routes 5` likewise returned `no_routable_task`.
`list-tasks --agent claude` returned `[]`.

## Health snapshot (farmctl)

Overall: FAIL (3 fail / 2 warn / 14 ok). checked_at 2026-05-25T11:45:17Z.

| Check | Value | Status | Δ vs 2200Z |
|---|---|---|---|
| mt5_worker_saturation | 9/10 alive (T1 missing) | WARN | +0 |
| mt5_dispatch_idle | 12 pending, 4 active | OK | -3 pending, +0 active |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 776 | FAIL | **+203** |
| unenqueued_eas_count | 9 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079) | WARN | +0 (same chronic nine) |
| p_pass_stagnation | 0 P3+ PASS in 12h | FAIL | +0 |
| zerotrade_rework_backlog | 0 ("no uncovered recurrent zero-trade EAs") | OK | +0 (sixth clear cycle) |
| quota_snapshot_fresh | codex=27s, claude=27s | OK | -8s (35 → 27) |
| pump_task_lastresult | exit 0 | OK | +0 (twenty-fourth consecutive cycle) |
| disk_free_gb | D: 146.6 | OK | -0.2 |
| codex_zero_activity | 6 codex, 11 pending | OK | +5 codex, +5 pending (counter rollover — see notes) |
| approved_cards | 2566 (schema-blocked) | — | +0 |
| source_pool_drained | 12 pending sources | OK | +0 |

T1 terminal_worker still missing. Pump exit 0 holds (twenty-fourth consecutive
cycle). Pending -3 / active +0 this cycle (15/4 → 12/4): drain continues but
shallower than the prior cycle's -6. Active count plateaued at 4 for a third
consecutive cycle.

**unbuilt_cards_count jumped +203 (573 → 776).** Approved_cards held at 2566 and
agent_tasks shows only 3 APPROVED build_ea tasks — i.e. build-task supply did
not grow. The most plausible read is that a batch of prebuild-failed /
auto-build records were cleared from another bookkeeping store (consistent with
the recent dead-bridge inbox cleanup + PT13 advance-past-prebuild-failed
patch noted in memory `project_qm_dead_bridge_inbox_blocker_2026-05-25`), so
those cards now register as "lacks .ex5 and auto-build task". No corrective
action this cycle — this is a Codex/pump-owned remediation path.

**zerotrade_rework_backlog held clear (6th cycle).** QM5_10027 resolution
durable; treat as the stable state.

**unenqueued_eas_count flat at 9.** Same chronic nine
(QM5_10019/10021/10028/10035/10039/10043/10044/10076/10079).

`quota_snapshot_fresh` codex=27s / claude=27s — -8s (35 → 27). Back inside the
24–35s band the prior cycles tracked.

`codex_zero_activity` field reports 6 codex / 11 pending. This appears to be a
counter-rollover or sampler glitch — direct agent_router status shows codex
running=0 and only 5 APPROVED + 1 REVIEW codex tasks total. Treat the health
detail as noisy this cycle and trust the router status.

## QM5_10260 queue state

All 8 Q02 work_items remain `failed` with verdict `INVALID` (0 pending).
No change. Preflight reason still `setfile_missing` — forex M15 setfiles
referenced by failed work_items have not been pushed to main.

## Actions taken

None. No claude IN_PROGRESS task; router has no routable work; orchestration
cycle exits idle.

## Notes for next cycle

- **unbuilt_cards_count broke the four-cycle flat run at 573 with a +203 jump
  to 776.** Likely a delayed accounting effect of the recent inbox cleanup +
  PT13 patch (memory `project_qm_dead_bridge_inbox_blocker_2026-05-25`).
  Worth watching whether the pump now drains this surfaced backlog in the next
  few cycles or whether it stalls (which would indicate a deeper bridge issue).
- zerotrade_rework_backlog clear sustained 6 cycles. QM5_10027 resolution is
  the stable state, not a flap.
- Pending drain continues but shallower: -3 (15 → 12); active held at 4 for
  a third cycle. Active replenishment from T1 absence remains the open
  question.
- Pump exit 0 held for a twenty-fourth consecutive cycle. Treat as stable.
- `quota_snapshot_fresh` -8s (35 → 27); back inside baseline band.
- Codex APPROVED -1 (6 → 5) suggests one task moved through since 2200Z. REVIEW
  ops_issue (id 3854cd8b...) still pending OWNER/codex closeout.
- `codex_zero_activity` detail "6 codex, 11 pending" disagrees with router
  status (0 running, 5 APPROVED + 1 REVIEW). Worth flagging if recurring next
  cycle — could be a stale snapshot in the health collector.
- Disk D: 146.6 GB (-0.2 GB). Trivial.
- Worktree still carries unstaged framework EA modifications (QM5_10047
  and 10047 set-files) from Codex; not part of this cycle's commit
  (explicit pathspec only).
- Headline blockers: schema blocker (2566 cards), p2_pass_no_p3=127,
  unbuilt_cards_count=776 (newly elevated), unenqueued_eas=9, T1
  terminal_worker missing.
- Upstream issues still sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
