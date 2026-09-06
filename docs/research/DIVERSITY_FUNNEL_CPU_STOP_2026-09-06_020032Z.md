# Diversity Funnel — CPU-Ceiling Stop

Date: 2026-09-06 UTC (`2026-09-06T02:00:32Z`); 2026-09-06 04:00
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `d3b9ac18b4b3fc57bde052cb436a252769805c4b`

Status: stopped before claiming, building, compiling, smoking, or enqueueing an
EA because the explicit backtest CPU ceiling was reached.

## Binding capacity result

The first fresh five-sample whole-host window measured `100%` on all five
samples. Average and maximum CPU were both `100%`, above the strict `<97%`
admission rule. This is the binding window for this paced unit.

A subsequent read-only confirmation window measured `89.5676%`, `94.3381%`,
`95.6056%`, `91.0166%`, and `83.5064%` (average `90.8069%`, maximum
`95.6056%`). This shows the saturation was transient, but it does not undo the
explicit stop after this unit had already hit the ceiling. A later paced wake
must take its own fresh admission window.

The process snapshot between the two windows found five factory terminal and
metatester pairs on T2, T6, T7, T8, and T9. T_Live and an unrelated FTMO
terminal were observed only to classify processes; neither was controlled.

## Collision and funnel state

The highest-priority diversity build visible in the farm was already claimed:
task `b0f920f1-0904-4b93-a494-0961b10202f8` holds
`QM5_41143_gbpusd-month-end-benchmark-fix-hedge-flow`, and its governed compile
row `ea884470-c638-4d3c-9eaf-438561b4778e` was pending. This pass therefore did
not claim or duplicate that GBPUSD card.

At the snapshot, the farm already carried 28 pending `COMPILE_EA` rows, 772
pending Q02 rows, 142 pending Q03 rows, and 1,120 pending Q04 rows. Five
`OPT_CENSUS` rows and two Q07 rows were active. Adding compile or tester work
after the binding CPU window would have violated the paced-fleet stop rule.

## Non-duplicate delta

The prior committed ceiling record on 2026-09-05 saw four factory tester pairs
and a 97.5129% average. This observation sees five pairs, a first window pinned
at 100%, the newly claimed QM5_41143 diversity build, and its pending governed
compile row. Those changed facts make this a new capacity and coordination
receipt rather than a replay of the earlier commodity stop.

## Scope and safety boundary

No farm claim or task state, source approval, Strategy Card, allocation,
registry row, resolver, EA, binary, setfile, basket manifest, compile, smoke,
pipeline phase, Q02 row, dispatch, priority, or verdict was created or changed.
The portfolio gate, portfolio-admission surfaces, deploy manifests, T_Live,
and AutoTrading were untouched. Existing unrelated shared-worktree changes
were preserved and excluded from the commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_stop_20260906T020032Z_board_advisor.json`.

## Continuation condition

On a later paced wake, take a new five-sample whole-host CPU window. Proceed
only if both average and maximum remain strictly below 97%, then re-query farm
claims and choose the highest-diversity non-colliding unit. Do not reclaim
QM5_41143 while task `b0f920f1-0904-4b93-a494-0961b10202f8` remains active.
