# Diversity funnel — hard CPU-ceiling stop

Date: 2026-08-21 UTC

Branch: `agents/board-advisor`

Status: stopped before farm claim, card selection, build, smoke, or Q02 enqueue

## Outcome

The mandatory capacity preflight bound before candidate selection. No EA or
task was claimed, and no build-backlog row was advanced. This avoids colliding
with the paced fleet and avoids starting a standard build whose required
Model-4 smoke cannot be admitted safely.

The canonical farm controller reported nine active work items: one Q03, one
Q05, two Q06, and five Q07. Their claims occupied T1, T2, T3, T4, T5, T7, T8,
T9, and T10. The nearby `mt5-slots` census saw the same nine governed tester
processes, with no duplicate terminal workers and no orphaned terminal
processes. Codex had no `IN_PROGRESS` or `TODO` agent task, and this wake took
no new farm or agent claim.

## Binding capacity stop

Five two-second whole-host CPU samples from
`2026-08-21T11:02:12.3363546Z` through
`2026-08-21T11:02:22.9823440Z` were all `100.00%`. Average and maximum CPU
were therefore both `100.00%`, above the explicit 97% hard ceiling.

This is a non-duplicate fleet observation 59.56 minutes after the nearby
`10:02:49Z` diversity stop. Active work increased from eight to nine, the
path-filtered factory process count increased from seven to nine, T3 and T10
and the previously claim-only T9 process arrived, T6 departed, and the phase
mix changed from one Q02 plus three Q07 to five Q07 with no active Q02. The
ceiling nevertheless remains binding.

Per the mission stop condition, no farm claim, Strategy Card selection, EA or
registry mutation, resolver regeneration, build check, compile, smoke,
backtest, Q02 enqueue/requeue, dispatch, terminal reservation, priority
mutation, or process-control action was performed.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260821T110212Z_board_advisor.json`.

## Safety

No portfolio gate, portfolio KPI, deploy manifest, T_Live file/state, or
AutoTrading state was changed. The T_Live process appeared only in the
read-only host census and was excluded from the governed T1-T10 count.
Concurrent unrelated worktree changes were left unstaged and untouched.

## Continuation

After sustained whole-host CPU remains below 97% with maximum headroom, rerun
the farm ownership preflight and claim exactly one highest-diversity eligible
build or diverse Q02-Q03 infrastructure repair.
