# Diversity funnel mission — changed-state CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T14:30:37.7721683Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `9eb958efd327c55718f51a489d5c8bd6ca120ac4`

Status: stopped at the explicit backtest CPU ceiling before backlog ranking,
farm claim, build, infrastructure repair, smoke, or Q02 enqueue.

## Binding capacity result

The supported read-only `farmctl mt5-slots` snapshot at
`2026-08-27T14:30:11Z` found five governed factory terminals actively testing:
`T2`, `T3`, `T6`, `T7`, and `T8`. Five reservations were active, six terminal
worker daemons were alive, and no orphaned factory terminal was reported.
`T_Live` and the unrelated FTMO terminal were observed only to exclude them;
neither was controlled.

The required five one-second whole-host CPU samples were:

| Sample | CPU |
|---:|---:|
| 1 | 97.757215% |
| 2 | 98.832939% |
| 3 | 100.000000% |
| 4 | 98.149163% |
| 5 | 95.019498% |

Average CPU was `97.951763%` and maximum CPU was `100.000000%`. The governed
tester-admission ceiling binds when either measure reaches `97%`; both
triggered the mission's stop condition.

## Farm coordination and diversity state

The read-only farm DB snapshot contained six active rows: one Q03, one Q07,
one Q09, and three Q10_NEWS. The diverse logical metals-pair row
`QM5_20263_XAU_XAG_MADRV_D1` remained actively claimed on `T7` at Q03 and was
left undisturbed. The Q09 row claimed by `T5` had no live tester process in
this point-in-time process snapshot; that mismatch was observed only and was
not treated as authority to reclaim or duplicate-enqueue it.

No new EA or work item was claimed. Because the hard stop fired before backlog
selection, this run did not create a collision with another paced agent or
speculate about an identity that could not be advanced safely.

## Non-duplicate observation delta

The preceding receipt at `2026-08-27T13:45:49Z` recorded nine active work
items and running terminals `T2`, `T6`, `T7`, and `T10`. This snapshot recorded
six active work items and running terminals `T2`, `T3`, `T6`, `T7`, and `T8`.
The earlier OPT_CENSUS, Q11, and one Q10_NEWS row had left the active set;
`T10` was no longer visible while `T3` and `T8` became visible. CPU nevertheless
remained above the admission ceiling, so the changed farm state still did not
permit a build or re-enqueue.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260827T143037Z_board_advisor.json`.

## Scope and safety boundary

No card, EA, registry row, magic row, resolver, source, binary, setfile,
build result, compile task, smoke run, Q02 row, queue priority, verdict,
reservation, tester, or backtest was created or changed. No terminal or worker
was started or stopped. The portfolio gate, portfolio admission state,
`T_Live`, AutoTrading, and live or deploy manifests were untouched. Existing
unrelated worktree changes were preserved and excluded from this evidence
commit.

## Continuation condition

Run a fresh read-only capacity preflight on the next paced wake. Only after
both the five-sample CPU average and maximum are below `97%` should the agent
rank and claim one distinct diversity candidate, complete its governed build
or infrastructure repair, and enqueue exactly one non-live Q02 work item.
