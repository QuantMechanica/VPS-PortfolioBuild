# Diversity funnel — changed phase mix / hard CPU stop

Date: 2026-08-25 UTC (`2026-08-25T18:33:25Z`)

Branch: `agents/board-advisor`

Observation base: `a531e8bcf450f1dab8195e61b8c22f53e7545015`

Status: stopped before farm claim, candidate ranking, build, repair, compile,
smoke, or Q02/Q03 enqueue because the explicit backtest CPU ceiling is binding

## Outcome

Five fresh one-second whole-host CPU samples were `98.97%`, `100.00%`,
`92.98%`, `94.92%`, and `89.37%`. Their average was `95.248%`, below the
governed `97%` ceiling, but their maximum was `100.00%`. The admission rule
binds when either the average or maximum is at least `97%`, so the maximum
required an immediate stop. The sample was not repeated in search of a lower
reading, and no CPU-consuming or queue-mutating work was admitted.

No approved card, built-but-stuck EA, or new structural edge was selected.
The `qm-build-ea-from-card` workflow therefore did not enter card, registry,
magic, compile, smoke, or handoff stages.

## Read-only coordination snapshot

The supported `farmctl` operator views reported eight active work items: two
`Q07` rows and six `Q10_NEWS` rows. Seven factory terminal processes were
running on T2, T3, T4, T6, T7, T9, and T10. Eight reservations existed, adding
T8 to that set, while seven terminal-worker processes were reported on T2,
T3, T4, T6, T7, T8, and T9. No orphaned factory terminal process was reported.

T8's active reservation lacked a matching terminal process in the scan, and
T10's running terminal lacked a reported terminal-worker process. These are
non-atomic read-only observations, not diagnoses. They were recorded without
reconciliation because the capacity stop forbids further operational work.
`T_Live` and the unrelated FTMO terminal were excluded from the factory count
and were not controlled.

## Non-duplicate delta

The preceding diversity receipt at
`artifacts/diversity_funnel_hard_cpu_stop_20260825T174458Z_board_advisor.json`
observed six active rows, all `Q10_NEWS`; the current snapshot has eight active
rows because two `Q07` runs have joined the six `Q10_NEWS` runs.

The most recent general receipt at
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260825T180053Z_board_advisor.json`
observed five running factory terminals and five reservations. The current
snapshot has seven running factory terminals and eight reservations. Average
CPU fell from `99.83%` to `95.248%`, but maximum CPU remained `100.00%`, so the
maximum-only stop is a changed operational state rather than a duplicate queue
action.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260825T183325Z_board_advisor.json`.

## Safety

- Farm inspection used supported read-only operator commands; no task or work-item row changed.
- No Strategy Card, EA, registry row, magic resolver, binary, or setfile changed.
- No compile, build check, smoke test, backtest, terminal reservation, dispatch, enqueue, requeue, reconciliation, or terminal control ran.
- The portfolio gate, T_Live manifest, T_Live, and AutoTrading were untouched.
- Concurrent unrelated worktree changes were left unstaged and uncommitted.
