# Diversity funnel mission — changed-state CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T18:31:00.9990175Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `afa900287e7ae01d5895467a7f37b9af15a20dfd`

Status: stopped at the explicit backtest CPU ceiling before backlog ranking,
farm claim, build, infrastructure repair, smoke, or Q02 enqueue.

## Binding capacity result

The required five one-second whole-host CPU samples were `99.707210%`,
`99.806457%`, `100.000000%`, `100.000000%`, and `100.000000%`. Average CPU
was `99.902733%` and maximum CPU was `100.000000%`. The governed
tester-admission ceiling binds when either measure reaches `97%`; both
triggered the mission's stop condition.

The supported read-only `farmctl mt5-slots` snapshot at
`2026-08-27T18:30:22Z` found five governed factory terminals actively testing:
`T1`, `T2`, `T3`, `T7`, and `T10`. Five reservations were active, seven
terminal worker daemons were alive, and no orphaned factory terminal was
reported. `T_Live` and the unrelated FTMO terminal were observed only to
exclude them; neither was controlled.

## Farm coordination and non-duplicate delta

The read-only farm DB snapshot contained seven active rows: one Q03, one Q07,
one Q09, and four Q10_NEWS. The diverse logical metals-pair row
`QM5_20268_XAU_XAG_QTAILRV_D1` remained actively claimed on `T2` at Q03 and
was left undisturbed. The Q10_NEWS row claimed by `T4` and Q09 row claimed by
`T5` had no live tester process in this point-in-time process snapshot; those
mismatches were observed only and were not treated as authority to reclaim or
duplicate-enqueue either row.

This is changed state relative to the immediately preceding receipt at
`2026-08-27T18:25:42Z`: the OPT_CENSUS row left the active set, reducing the
count from eight to seven, and `T4` and `T8` were no longer running. The
diverse QM5_20268 Q03 remained bound to its visible tester. CPU nevertheless
remained above the admission ceiling, so the changed farm state did not permit
a fresh build, repair, smoke, or enqueue.

No new EA or work item was claimed. This avoided collision with the other
paced agents and did not speculate about an identity that could not be
advanced safely.

## Scope and safety boundary

No card, EA, registry row, magic row, resolver, source, binary, setfile, build
result, compile task, smoke run, Q02 row, queue priority, verdict, reservation,
tester, or backtest was created or changed. No terminal or worker was started
or stopped. The portfolio gate, portfolio admission state, `T_Live`,
AutoTrading, and live or deploy manifests were untouched. Existing unrelated
worktree changes were preserved and excluded from this evidence commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260827T183100Z_board_advisor.json`.

## Continuation condition

Run a fresh read-only capacity preflight on the next paced wake. Only after
both the five-sample CPU average and maximum are below `97%` should the agent
rank and claim one distinct diversity candidate, complete its governed build
or infrastructure repair, and enqueue exactly one non-live Q02 work item.
