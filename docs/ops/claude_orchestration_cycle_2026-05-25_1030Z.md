# Claude orchestration cycle — 2026-05-25 10:30Z

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

Overall: FAIL (4 fail / 2 warn / 13 ok). checked_at 2026-05-25T04:49:26Z.

| Check | Value | Status | Δ vs 1000Z |
|---|---|---|---|
| mt5_worker_saturation | 9/10 alive (T1 missing) | WARN | +0 |
| mt5_dispatch_idle | 166 pending, 8 active | OK | -27 pending, +0 active |
| p2_pass_no_p3 | 127 | FAIL | +0 |
| unbuilt_cards_count | 575 | FAIL | +0 |
| unenqueued_eas_count | 9 (QM5_10019, 10021, 10028, 10035, 10039, 10043, 10044, 10076, 10079) | WARN | +0 |
| p_pass_stagnation | 0 P3+ PASS in 12h | FAIL | +0 |
| pump_task_lastresult | exit 267009 | FAIL | REGRESSED (was exit 0) |
| disk_free_gb | D: 154.3 | OK | -1.6 |
| codex_zero_activity | 3 codex, 7 pending | OK | +0 codex, +1 pending |
| approved_cards | 2539 (schema-blocked) | — | +0 |

T1 terminal_worker still missing. Pending queue drained -27 (193 → 166)
with active flat at 8. Pump regressed from exit 0 back to exit 267009 —
same code seen at 0830Z. Three consecutive clean pump cycles broken.
`p2_pass_no_p3` (127), `unbuilt_cards_count` (575), and `p_pass_stagnation`
(0 P3+ in 12h) remain unchanged regardless of pump state.

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

- Pump regressed to FAIL exit 267009 after three OK cycles. Same code as
  0830Z. Flagging to OWNER — if it stays FAIL another 2 cycles, this is a
  real Codex/ops issue, not flapping.
- `p2_pass_no_p3` (127), `unbuilt_cards_count` (575), and
  `p_pass_stagnation` (0 P3+ in 12h) remained flat across both pump=OK and
  pump=FAIL — the bridge that converts P2-PASS into P3 work and
  approved-cards into build tasks is clearly not gated solely on the pump
  task exit code; root cause sits elsewhere.
- Headline blockers unchanged: schema blocker (2539 cards),
  p2_pass_no_p3=127, unbuilt_cards_count=575, unenqueued_eas=9,
  T1 terminal_worker missing.
- Pending queue -27 (166 vs 193); active flat at 8 — fleet continues to
  drain backlog at a steady rate.
- Upstream issues all sit with Codex or OWNER. Claude remains idle until
  the router gives it work.
