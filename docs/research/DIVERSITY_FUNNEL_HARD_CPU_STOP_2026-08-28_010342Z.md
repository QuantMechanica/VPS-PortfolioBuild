# Diversity funnel mission — saturated-fleet CPU ceiling stop

Date: 2026-08-28 UTC (`2026-08-28T01:03:42.0794112Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `36f0539789a037748a72fbfb3ed51e223a53d5b6`

Status: stopped at the explicit backtest CPU ceiling before backlog ranking,
farm claim, build, infrastructure repair, smoke, or Q02 enqueue.

## Binding capacity result

The required five one-second whole-host CPU samples were `100.000000%`,
`99.808457%`, `99.806554%`, `98.538244%`, and `99.902896%`. Average CPU was
`99.611230%` and maximum CPU was `100.000000%`. The governed tester-admission
ceiling binds when either measure reaches `97%`; both triggered the mission's
stop condition.

The supported read-only `farmctl mt5-slots` snapshot at
`2026-08-28T01:03:54Z` found seven governed factory terminals actively testing:
`T1`, `T2`, `T4`, `T6`, `T8`, `T9`, and `T10`. Seven reservations were active,
all ten terminal-worker daemons were alive, and no orphaned factory terminal
was reported. The paced launch gate was `1`, so the visible fleet alone was
also beyond fresh launch capacity. `T_Live` and the unrelated FTMO terminal
were observed only to exclude them; neither was controlled.

## Farm coordination and non-duplicate delta

The read-only farm snapshot contained ten active rows: two `OPT_CENSUS`, one
`Q03`, three `Q09`, and four `Q10_NEWS`. The diverse market-neutral metals row
`QM5_20294_XAU_XAG_LOWMAX_D1` remained actively claimed on `T6` at `Q03`, with
its tester and reservation visible, and was left undisturbed.

Three claimed rows on `T3`, `T5`, and `T7` had no matching tester process in
the point-in-time slot snapshot. That mismatch was observed only; it does not
establish stale work or authorize reclaim, repair, or duplicate enqueue.

This is materially changed state relative to the latest diversity receipt at
`2026-08-27T21:30:20Z`: active rows increased from seven to ten, visible factory
testers increased from five to seven, and the phase mix rotated to two
`OPT_CENSUS`, one `Q03`, three `Q09`, and four `Q10_NEWS`. The new snapshot is
therefore non-duplicate capacity evidence, but it does not permit a fresh Q01
build or Q02 handoff.

## Scope and safety boundary

No card, EA, registry row, magic row, resolver, source, binary, setfile, build
result, compile task, smoke run, Q02 row, queue priority, verdict, reservation,
tester, or backtest was created or changed. No terminal or worker was started
or stopped. The portfolio gate, portfolio admission state, `T_Live`,
AutoTrading, and live or deploy manifests were untouched. Existing unrelated
shared-worktree changes were preserved and excluded from this evidence commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260828T010342Z_board_advisor.json`.

## Continuation condition

Run a fresh read-only capacity preflight on the next paced wake. Only after
both the five-sample CPU average and maximum are below `97%` should an agent
rank and claim one distinct diversity candidate, complete its governed build
or infrastructure repair, and enqueue exactly one non-live Q02 work item.
