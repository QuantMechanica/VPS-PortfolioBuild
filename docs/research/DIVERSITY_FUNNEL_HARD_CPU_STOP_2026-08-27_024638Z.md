# Diversity funnel: hard CPU stop before farm claim

Date: 2026-08-27 UTC (`2026-08-27T02:46:38Z`); 2026-08-27 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `d14f41087568f691323bc29b5f1b5befb426b6f0`

Status: stopped at the explicit backtest CPU ceiling before selecting or
claiming an approved Strategy Card, a diverse Q02-Q03 infrastructure repair,
or a new structural edge

## Binding capacity result

Five fresh one-second whole-host readings were `100.0%`, `99.9034%`,
`100.0%`, `100.0%`, and `100.0%`. Their average was `99.9807%` and their
maximum was `100.0%`. The governed admission rule binds when either the
average or maximum is at least `97%`, so both tests independently fired the
mission's hard stop.

The DB-backed `farmctl mt5-slots` snapshot at `2026-08-27T02:47:20Z`
observed the full seven-terminal tester ceiling active on T1, T2, T4, T5,
T6, T8, and T10. The rows were seven distinct work items spanning Q03, Q07,
Q09, Q10_NEWS, and Q11. All ten terminal-worker daemons were present, seven
terminal reservations and seven `metatester64` processes were active, and no
orphaned factory terminal process was reported. `T_Live` and the unrelated
FTMO terminal were observed only so they could be excluded; neither was
controlled.

## Farm coordination and non-duplicate delta

The live farm database was resolved at
`D:\QM\strategy_farm\state\farm_state.sqlite` and accessed read-only through
the supported slot snapshot. Because the CPU gate bound first, no farm claim
was created and no candidate was selected. This avoids colliding with other
paced agents or the approved-card commit that landed concurrently in the
shared branch.

Relative to the preceding receipt at `2026-08-26T23:15:35Z`, active factory
tests rose from five to the seven-terminal ceiling: T10, T5, and T8 joined
while T7 left. Average CPU rose from `95.8033%` to `99.9807%`, and the maximum
rose from `99.8048%` to `100.0%`. This is a fresh saturation-state change, not
a duplicate queue insertion.

## Actions and safety boundary

Per the mission stop condition, no approved Card was claimed, no Q02-Q03
infrastructure target was advanced, and no structural edge was mechanized.
No source, Card, EA, EX5, setfile, basket manifest, registry row, magic row,
build check, compile, smoke, queue row, priority, verdict, dispatch,
reservation, terminal process, tester, or backtest was created or changed.

No portfolio gate, Q08 contribution, T_Live manifest, T_Live process, or
AutoTrading state was touched. Concurrent unrelated worktree changes were
preserved and excluded from this evidence-only unit.

Machine-readable evidence:
`artifacts/diversity_funnel_hard_cpu_stop_20260827T024638Z_board_advisor.json`.
