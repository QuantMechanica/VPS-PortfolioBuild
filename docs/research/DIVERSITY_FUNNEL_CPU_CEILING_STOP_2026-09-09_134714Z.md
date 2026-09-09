# Diversity funnel — paced CPU-ceiling stop

Date recorded: 2026-09-09 13:47 UTC / 15:47 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `82a78f0a13757b98832d38d83c2bf50e3481b548`

Status: stopped at the explicit backtest CPU ceiling before claim, source
mutation, compile, smoke, Q02 enqueue, or dispatch.

## Binding capacity result

A fresh five-sample whole-host CPU window measured `99.170%`, `98.344%`,
`96.338%`, `87.256%`, and `90.237%`. Average CPU was `94.269%` and maximum
CPU was `99.170%`. Admission requires both values to be strictly below `97%`.
The average passed, but the maximum bound, so this wake refused all build and
pipeline mutations.

The canonical farm database was then opened through a read-only SQLite URI. At
`2026-09-09T13:47:15.192384+00:00` it held two active work items and 9,045
pending items. The active rows were `QM5_41323` `OPT_CENSUS` on `NDX.DWX`
claimed by T4 and `QM5_36002` Q07 on `GBPJPY.DWX` claimed by T9. Queue depth
is context only and is not permission to bypass the CPU gate.

Machine-readable evidence:
`artifacts/diversity_funnel_cpu_ceiling_stop_20260909T134714Z_board_advisor.json`.

## Prior candidate recheck

The 2026-09-05 handoff's leading candidate, `QM5_41171_wti-mturnpoint-tr`, is
no longer an uncompiled build: its tracked EX5 exists with SHA-256
`1eb203082384ddd3212c6eb4f3bda8617a26fa02828db56decb41f73ce5c22f2`.
The current database has no pending/active task or work item for that EA, but
the CPU refusal bound before any attempt to classify or enqueue it as a
built-but-stuck candidate. A later wake must rerank rather than reuse the old
uncompiled-build conclusion.

## Mutation boundary

No task or work item was created, claimed, reprioritized, advanced, or
re-enqueued. No EA source, EX5, setfile, Strategy Card, registry, magic
resolver, build result, pipeline evidence, or verdict was changed. No compile,
smoke, backtest, dispatch tick, terminal control, or worker control was
started.

The framework-input pin audit was therefore not applicable: no generated
source was written and no compile enqueue was attempted. The portfolio gate,
portfolio-admission surfaces, `T_Live`, AutoTrading, live manifests, and deploy
manifests were untouched. Existing unrelated shared-worktree changes were
preserved and excluded from this receipt.

## Continuation condition

On a later paced wake, take a fresh five-sample whole-host CPU window. Proceed
only if both its average and maximum are strictly below `97%`; then rerank the
diversity backlog because `QM5_41171` is no longer an uncompiled candidate.
