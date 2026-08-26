# Diversity funnel: hard CPU stop before farm claim

Date: 2026-08-26 UTC (`2026-08-26T23:15:35Z`); 2026-08-27 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `3a7eaf8c7a26e6eb1036b6728976e2041158d6d9`

Status: stopped at the explicit backtest CPU ceiling before selecting or
claiming a Strategy Card, diverse infrastructure repair, or new edge

## Binding capacity result

Five fresh one-second whole-host readings were `99.8048%`, `98.3420%`,
`97.6618%`, `83.6955%`, and `99.5124%`. Their average was `95.8033%` and
their maximum was `99.8048%`. The governed admission rule binds when either
the average or maximum is at least `97%`, so the maximum independently fired
the mission's hard stop.

The supported `farmctl mt5-slots` snapshot at `2026-08-26T23:15:35Z`
observed five governed factory terminals actively testing: T1, T2, T4, T6,
and T7. All ten terminal-worker daemons were present, seven terminal
reservations were reported, five `metatester64` processes were active, and no
orphaned factory terminal process was reported. `T_Live` and the unrelated
FTMO terminal were observed only so they could be excluded; neither was
controlled.

## Farm coordination and non-duplicate delta

The live farm database was resolved at
`D:\QM\strategy_farm\state\farm_state.sqlite` and accessed read-only through
the supported slot snapshot. Because the CPU gate bound first, no farm claim
was created and no candidate was selected. This avoids colliding with paced
agents or duplicating the already-visible shared-worktree build activity.

This receipt is a changed capacity observation relative to
`artifacts/diversity_funnel_hard_cpu_stop_20260826T223118Z_board_advisor.json`:
T2 replaced T5 in the running factory cohort, active reservations increased
from five to seven, and average CPU eased from `98.0%` to `95.8033%`, while
the fresh `99.8048%` maximum still crossed the binding ceiling. It records no
duplicate queue insertion.

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
`artifacts/diversity_funnel_hard_cpu_stop_20260826T231535Z_board_advisor.json`.
