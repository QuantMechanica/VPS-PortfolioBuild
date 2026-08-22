# Diversity funnel — hard CPU-ceiling stop

Date: 2026-08-22 UTC

Branch: `agents/board-advisor`

Status: stopped before farm claim, card selection, build, smoke, or Q02 enqueue

## Outcome

The explicit backtest CPU ceiling bound during mandatory capacity preflight.
Five one-second whole-host samples were `100.00%`, `100.00%`, `100.00%`,
`100.00%`, and `99.90%`: average `99.98%`, maximum `100.00%`, above the
`97%` ceiling. Nine governed factory terminals were running (`T2` through
`T10`); the path-anchored census excluded `T_Live`.

Per the mission stop condition, no farm task was claimed and no candidate row
was inspected after capacity bound. No Strategy Card, EA, registry, resolver,
setfile, tester, queue, priority, or terminal state was changed.

## Read-only farm snapshot

The farm database was opened read-only with `PRAGMA query_only=ON`; SQLite
`quick_check=ok`. At `2026-08-22T20:17:49.502485Z` it contained 9 active and
3,249 pending work items. The active mix was one `Q07` item and eight
`Q09_NEWS` items. There were 37 pending and zero active `build_ea` tasks.

This observation is non-duplicate relative to the 2026-08-21 stop receipt:
the current active phase mix is materially different and the pending work-item
count has risen from 2,234 to 3,249. The ceiling nevertheless remains binding.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260822T201752Z_board_advisor.json`.

## Safety and workspace isolation

The canonical shared worktree already had 540 unrelated porcelain entries from
the paced fleet. They were left untouched; only this receipt and its JSON
evidence are committed. No portfolio gate, deploy manifest, `T_Live` file, or
AutoTrading state was queried or changed.

## Continuation

When sustained whole-host CPU is below 97%, rerun ownership preflight and claim
exactly one diversity-first approved build or diverse Q02–Q03 infrastructure
repair through the farm database.
