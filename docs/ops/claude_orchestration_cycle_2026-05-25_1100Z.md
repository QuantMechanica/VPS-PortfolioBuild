# Claude orchestration cycle — 2026-05-25 11:00Z

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

Overall: FAIL (3 fail / 2 warn / 14 ok). checked_at 2026-05-25T05:00:36Z.

| Check | Value | Status | Δ vs 1030Z |
|---|---|---|---|
| mt5_worker_saturation | 9/10 alive (T1 missing) | WARN | +0 |
| mt5_dispatch_idle | 164 pending, 9 active | OK | -2 pending, +1 active |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 575 | FAIL | +0 |
| unenqueued_eas_count | 9 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079) | WARN | +0 |
| p_pass_stagnation | 0 P3+ PASS in 12h | FAIL | +0 |
| pump_task_lastresult | exit 0 | OK | RECOVERED (was exit 267009) |
| disk_free_gb | D: 153.9 | OK | -0.4 |
| codex_zero_activity | 4 codex, 7 pending | OK | +1 codex, +0 pending |
| approved_cards | 2539 (schema-blocked) | — | +0 |

T1 terminal_worker still missing. Pump recovered to exit 0 after one cycle of
exit 267009 — looks like a transient flap, not a sustained Codex/ops issue.
Backlog drain slowed (-2 pending vs -27 last cycle) but active rose +1 to 9 —
fleet still processing. `p2_pass_no_p3` (127), `unbuilt_cards_count` (575),
and `p_pass_stagnation` (0 P3+ in 12h) remain flat; the pump-OK state did not
restart any of the bridge work, confirming root cause is not the pump.

Backtest queue: 159 pending / 9 active / 1930 done / 88 failed.

## QM5_10260 queue state

All 8 Q02 work_items remain `failed` INVALID (0 pending). Stable since
2026-05-24 21:16:08Z. Preflight reason is `setfile_missing` — canonical
checkout at `framework/EAs/QM5_10260_cieslak-fomc-cycle-idx/sets/` holds
only the 3 indices/M30 setfiles (NDX/SP500/WS30); the forex M15 setfiles
referenced by the failed work_items have not been pushed to main. No change.

## Actions taken

None. No claude IN_PROGRESS task; router has no routable work; orchestration
cycle exits idle.

## Notes for next cycle

- Pump recovered from exit 267009 → exit 0 in a single cycle — last cycle's
  regression was a single-cycle flap, not a sustained outage. Continue
  watching.
- Bridge work still inert despite pump OK: `p2_pass_no_p3` (127),
  `unbuilt_cards_count` (575), `p_pass_stagnation` (0 P3+ in 12h) all flat
  for many cycles. Root cause sits in promotion logic, not pump exit code —
  needs OWNER/Codex investigation, not waiting.
- Headline blockers unchanged: schema blocker (2539 cards),
  p2_pass_no_p3=127, unbuilt_cards_count=575, unenqueued_eas=9,
  T1 terminal_worker missing.
- Backlog drain decelerating (-2 pending this cycle vs -27 last); active +1
  to 9 — fleet still working at near saturation.
- Upstream issues all sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
