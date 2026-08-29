# Diversity funnel — transient CPU-ceiling stop

Date: 2026-08-29 UTC (`2026-08-29T11:00:03Z`); 2026-08-29 13:00 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `378a86eab29f736145f2f06858d45b74f4c518c2`

Status: stopped at the explicit backtest CPU ceiling before backlog ranking,
farm claim, EA selection, build, repair, mechanization, or Q02 enqueue.

## Binding capacity result

The first five-sample whole-host CPU window measured `100.00%`, `100.00%`,
`100.00%`, `99.12%`, and `95.72%`. Its average was `98.968%` and maximum
was `100.00%`, so both measures exceeded the governed `97%` tester-admission
ceiling in `tools/strategy_farm/terminal_worker.py`.

A confirmation window ending about one minute later measured only `69.704%`
average and `73.168%` maximum. That establishes that the spike was transient;
it does not undo the mission's instruction to stop once the ceiling is hit.
No work was admitted while sampling or after the stop trigger.

## Farm coordination state

The read-only farm census had three active rows: two `Q10_NEWS` and one
`OPT_CENSUS`. Supported process discovery saw two paced factory testers:
`T1` running QM5_21507/XAUUSD at `Q10_NEWS`, and `T3` running
QM5_41097/USDJPY at `OPT_CENSUS`. Ten terminal-worker daemons were present,
with no duplicate workers or orphaned terminal processes.

QM5_10513/XAUUSD remained active and claimed by `T6`, but no corresponding
factory process was visible in this point-in-time scan. That observation is
not proof of a stale claim, so it was not reclaimed, repaired, or re-enqueued.
No approved Card was ranked or claimed after the capacity trigger.

## Non-duplicate delta

The preceding immediate receipt, for QM5_41193 at `2026-08-29T06:06:10Z`,
observed five running testers on `T2`, `T3`, `T6`, `T7`, and `T8` and a
`98.011%` average. The current roster had contracted to only `T1` and `T3`,
yet two long-running Q10/optimization workloads still produced a fresh
`100%` peak before falling below the ceiling without intervention. This
changed topology is the new coordination evidence: terminal count alone is
not a safe admission signal.

## Scope and safety boundary

No Card, G0 record, EA source or binary, setfile, basket manifest, registry,
magic row, resolver, build result, queue row, claim, priority, status,
verdict, or pipeline evidence was mutated. No compile, build check, smoke,
backtest, dispatch tick, terminal control, or worker control was started.
The portfolio gate, `T_Live`, AutoTrading, and live/deploy manifests were
untouched. Existing unrelated shared-worktree changes were preserved and
excluded from this commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260829T110003Z_board_advisor.json`.

## Continuation condition

On a later paced wake, take a new five-sample capacity window. Proceed only
when both average and maximum are strictly below `97%`; then rank and claim
one distinct diversity-first unit through the farm DB, prefer an approved
forex, crypto-if-available, non-XNG energy, rates, or market-neutral Card,
keep backtest setfiles at `RISK_FIXED`, and enqueue Q02 without dispatching or
touching portfolio/live surfaces.
