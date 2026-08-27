# Diversity funnel mission — changed-state CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T21:30:20.4149699Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `7fa4293b597fe344573f5db54a79670ca5f9c858`

Status: stopped at the explicit backtest CPU ceiling before backlog ranking,
farm claim, build, infrastructure repair, smoke, or Q02 enqueue.

## Binding capacity result

The required five one-second whole-host CPU samples were `100.000000%`,
`100.000000%`, `99.523391%`, `97.083011%`, and `92.293370%`. Average CPU was
`97.779954%` and maximum CPU was `100.000000%`. The governed tester-admission
ceiling binds when either measure reaches `97%`; both triggered the mission's
stop condition.

The supported read-only `farmctl mt5-slots` snapshot at
`2026-08-27T21:30:15Z` found five governed factory terminals actively testing:
`T1`, `T2`, `T3`, `T8`, and `T10`. Five reservations were active, seven
terminal worker daemons were alive, and no orphaned factory terminal was
reported. `T_Live` and the unrelated FTMO terminal were observed only to
exclude them; neither was controlled.

## Farm coordination and non-duplicate delta

The read-only farm DB snapshot contained seven active rows: one OPT_CENSUS, one
Q03, one Q09, and four Q10_NEWS. The diverse logical metals-pair row
`QM5_20268_XAU_XAG_QTAILRV_D1` remained actively claimed on `T2` at Q03 and
was left undisturbed. The Q09 row claimed by `T5` and the OPT_CENSUS row
claimed by `T6` had no live tester process in this point-in-time snapshot;
those mismatches were observed only and were not treated as authority to
reclaim or duplicate-enqueue either row.

This is changed state relative to the immediately preceding receipt at
`2026-08-27T18:31:00Z`: the Q07 row left the active set, an OPT_CENSUS row
returned, `T7` stopped running, and `T8` resumed Q10_NEWS work. The total
active-row and running-terminal counts both remained seven and five,
respectively. The diverse QM5_20268 Q03 remained bound to its visible tester.
CPU nevertheless remained above the admission ceiling, so the changed farm
state did not permit a fresh build, repair, smoke, or enqueue.

The approved `QM5_41188` source/build path was already present as unrelated
shared-worktree work and was preserved without attribution or modification.
No new EA or work item was claimed, avoiding a collision with another paced
agent.

## Scope and safety boundary

No card, EA, registry row, magic row, resolver, source, binary, setfile, build
result, compile task, smoke run, Q02 row, queue priority, verdict, reservation,
tester, or backtest was created or changed. No terminal or worker was started
or stopped. The portfolio gate, portfolio admission state, `T_Live`,
AutoTrading, and live or deploy manifests were untouched. Existing unrelated
worktree changes were preserved and excluded from this evidence commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260827T213020Z_board_advisor.json`.

## Continuation condition

Run a fresh read-only capacity preflight on the next paced wake. Only after
both the five-sample CPU average and maximum are below `97%` should an agent
rank and claim one distinct diversity candidate, complete its governed build
or infrastructure repair, and enqueue exactly one non-live Q02 work item.
