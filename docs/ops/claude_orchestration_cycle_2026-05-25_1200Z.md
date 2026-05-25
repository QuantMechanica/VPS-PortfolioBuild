# Claude orchestration cycle — 2026-05-25 12:00Z

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

Overall: FAIL (3 fail / 2 warn / 14 ok). checked_at 2026-05-25T05:32:17Z.

| Check | Value | Status | Δ vs 1130Z |
|---|---|---|---|
| mt5_worker_saturation | 9/10 alive (T1 missing) | WARN | +0 |
| mt5_dispatch_idle | 140 pending, 9 active | OK | -8 pending, +0 active |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 575 | FAIL | +0 |
| unenqueued_eas_count | 9 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079) | WARN | +0 |
| p_pass_stagnation | 0 P3+ PASS in 12h | FAIL | +0 |
| pump_task_lastresult | exit 0 | OK | +0 (third consecutive cycle) |
| disk_free_gb | D: 152.7 | OK | -0.4 |
| codex_zero_activity | 2 codex, 5 pending | OK | -1 codex, -1 pending |
| approved_cards | 2539 (schema-blocked) | — | +0 |

T1 terminal_worker still missing. Pump exit 0 holds across this cycle. Backlog
drain continues (-8 pending vs -11 last cycle), 9 active steady — fleet still
processing. `p2_pass_no_p3` (127), `unbuilt_cards_count` (575), and
`p_pass_stagnation` (0 P3+ in 12h) remain flat — promotion logic still inert
despite pump OK; root cause is not the pump.

Backtest queue (direct sqlite): 138 pending / 9 active / 1961 done / 88 failed.
+17 done vs prior cycle's 1944; steady throughput.

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

- Pump exit 0 held for a third consecutive cycle after the single-cycle 267009
  flap. Treat as stable; revisit only if it regresses.
- Bridge work still inert despite pump OK: `p2_pass_no_p3` (127),
  `unbuilt_cards_count` (575), `p_pass_stagnation` (0 P3+ in 12h) all flat
  for many cycles. Root cause sits in promotion logic, not pump exit code —
  needs OWNER/Codex investigation, not waiting.
- Headline blockers unchanged: schema blocker (2539 cards),
  p2_pass_no_p3=127, unbuilt_cards_count=575, unenqueued_eas=9,
  T1 terminal_worker missing.
- Backlog drain slowing slightly (-8 pending this cycle vs -11 last); active
  flat at 9 — fleet still working at near saturation, +17 done.
- Upstream issues all sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
