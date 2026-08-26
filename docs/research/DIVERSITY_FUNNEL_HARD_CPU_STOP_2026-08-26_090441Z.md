# Diversity funnel: rotated-fleet hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T09:04:41.8590900Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `1da626c79e627bfcc300de1c8b4684314802f05f`

Status: stopped at the explicit backtest CPU ceiling before any farm claim,
build, compile, registry mutation, Q02 enqueue, terminal reservation, or tester
action.

## Binding capacity stop

Five fresh one-second whole-host CPU readings were `99.902643%`, `100.000000%`,
`100.000000%`, `100.000000%`, and `99.220015%`. The average was `99.824532%`
and the maximum was `100.000000%`. The mission ceiling binds when either value
is at least `97%`; both values bind.

Five `metatester64` processes were active. The farm's read-only slot scan at
`2026-08-26T09:04:42Z` attributed current work to T1, T4, T6, T7, and T9:

- T1: `QM5_20199`, Q03 FX cointegration
- T4: `QM5_20085`, Q07 EURUSD
- T6: `QM5_12708`, Q10_NEWS XAUUSD
- T7: `QM5_12354`, Q10_NEWS XAUUSD
- T9: `QM5_10114`, Q10_NEWS GDAXI

The scan found no duplicate terminal workers or orphaned terminal processes.

## Non-duplicate delta

The preceding diversity receipt at `2026-08-26T08:19:30Z` observed T1, T3, T4,
T7, T8, and T9. The current allocation rotated: T6 entered while T3 and T8
exited. Four of the five tester process identities also changed, and the branch
head advanced from `4e5824c10` to `1da626c79`. This is fresh coordination
evidence despite the host remaining fully saturated; claiming a build now would
still violate the explicit ceiling and contend with materially different active
farm work.

Per the mission stop condition, no diversity backlog EA was claimed, no approved
card was built, no infrastructure repair was advanced, and no new structural
edge was mechanized. No portfolio gate, T_Live manifest, terminal state, or
AutoTrading state changed. Concurrent unrelated worktree changes were preserved
and excluded.

Machine-readable evidence is in
`artifacts/diversity_funnel_hard_cpu_stop_20260826T090441Z_board_advisor.json`.
