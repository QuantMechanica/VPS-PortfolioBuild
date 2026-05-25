# Claude orchestration cycle — 2026-05-25 12:30Z

Single-pass cycle. Idle: no claude tasks in any state.

## Router status

- claude: enabled, max_parallel=3, running=0
- codex: enabled, max_parallel=5, running=0 — 3 APPROVED build_ea + 2 APPROVED ops_issue queued
- gemini: enabled, max_parallel=2, running=1 — 5 FAILED research_strategy + 1 IN_PROGRESS

`run --min-ready-strategy-cards 5 --max-routes 5` returned `no_routable_task`;
generic research replenishment remains frozen
(`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`,
ready_strategy_cards=0).
`route-many --max-routes 5` likewise returned `no_routable_task`.
`list-tasks --agent claude` returned `[]`.

## Health snapshot (farmctl)

Overall: FAIL (3 fail / 2 warn / 14 ok). checked_at 2026-05-25T05:45:28Z.

| Check | Value | Status | Δ vs 1200Z |
|---|---|---|---|
| mt5_worker_saturation | 9/10 alive (T1 missing) | WARN | +0 |
| mt5_dispatch_idle | 131 pending, 9 active | OK | -9 pending, +0 active |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 575 | FAIL | +0 |
| unenqueued_eas_count | 9 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079) | WARN | +0 |
| p_pass_stagnation | 0 P3+ PASS in 12h | FAIL | +0 |
| pump_task_lastresult | exit 0 | OK | +0 (fourth consecutive cycle) |
| disk_free_gb | D: 152.4 | OK | -0.3 |
| codex_zero_activity | 2 codex, 7 pending | OK | +0 codex, +2 pending |
| approved_cards | 2539 (schema-blocked) | — | +0 |

T1 terminal_worker still missing. Pump exit 0 holds across this cycle (fourth
in a row). Backlog drain steady (-9 pending vs -8 last cycle), 9 active steady
— fleet still processing. `p2_pass_no_p3` (127), `unbuilt_cards_count` (575),
and `p_pass_stagnation` (0 P3+ in 12h) remain flat — promotion logic still
inert despite pump OK; root cause is not the pump.

Backtest queue (direct sqlite): 130 pending / 9 active / 1969 done / 88 failed.
+8 done vs prior cycle's 1961; steady throughput.

## QM5_10260 queue state

All 8 Q02 work_items remain `failed` INVALID (0 pending). Stable since
2026-05-24 21:16:08Z. Preflight reason is `setfile_missing` — canonical
checkout at `framework/EAs/QM5_10260_cieslak-fomc-cycle-idx/sets/` holds only
the 3 indices/M30 setfiles (NDX/SP500/WS30); the forex M15 setfiles referenced
by the failed work_items have not been pushed to main. No change.

## Actions taken

None. No claude IN_PROGRESS task; router has no routable work; orchestration
cycle exits idle.

## Notes for next cycle

- Pump exit 0 held for a fourth consecutive cycle after the single-cycle 267009
  flap. Treat as stable; revisit only if it regresses.
- Bridge work still inert despite pump OK: `p2_pass_no_p3` (127),
  `unbuilt_cards_count` (575), `p_pass_stagnation` (0 P3+ in 12h) all flat
  for many cycles. Root cause sits in promotion logic, not pump exit code —
  needs OWNER/Codex investigation, not waiting.
- Headline blockers unchanged: schema blocker (2539 cards),
  p2_pass_no_p3=127, unbuilt_cards_count=575, unenqueued_eas=9,
  T1 terminal_worker missing.
- Backlog drain steady (-9 pending this cycle vs -8 last); active flat at 9 —
  fleet still working at near saturation, +8 done.
- codex_zero_activity pending crept +2 (5→7) — minor; watch for trend.
- Worktree carries unstaged framework EA modifications (QM5_10047 sets/ex5/mq5)
  from Codex; not part of this cycle's commit.
- Upstream issues all sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
