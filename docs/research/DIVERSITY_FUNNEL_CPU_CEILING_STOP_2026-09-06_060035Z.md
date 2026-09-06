# Diversity funnel — paced CPU-ceiling stop

Date: 2026-09-06 UTC (`2026-09-06T06:00:35.4836697Z`); 08:00
Europe/Berlin

Branch: `agents/board-advisor`

CPU observation base: `0ecc2dd174f0328577437a8e281e85c6aff146cf`

Farm reconciliation base: `f1f40c85d0d8f0246734c5b7c9911fc6327174c7`

Status: stopped at the explicit factory CPU ceiling before claim, compile,
smoke, Q02 enqueue, or dispatch.

## Binding capacity result

A fresh five-sample whole-host CPU window measured `95.2171%`, `93.5210%`,
`95.9503%`, `95.7067%`, and `100.0000%`. Average CPU was `96.0790%`, but
maximum CPU was `100.0000%`. The paced admission rule requires both measures
to remain strictly below `97%`, so the maximum-side gate bound.

The canonical farm DB snapshot then held eight active work items across T1,
T3, T5, T6, T7, T8, T9, and T10: six `OPT_CENSUS`, one `Q07`, and one `Q08`.
The DB also held 28 pending compile rows, 775 pending Q02 rows, 142 pending Q03
rows, and 1,116 pending Q04 rows. These counts are queue context, not authority
to dispatch.

Machine-readable evidence:
`artifacts/diversity_funnel_cpu_ceiling_stop_20260906T060035Z_board_advisor.json`.

## Farm-DB collision reconciliation

The read-only reconciliation prevents duplicate work against the fleet's
movement since the preceding stop receipt:

- `QM5_41171_wti-mturnpoint-tr`, previously the leading uncompiled WTI card,
  has now completed `COMPILE_EA`, passed Q02, passed Q04 as `PASS_LOWFREQ`,
  passed Q05, and reached a Q06 `INFRA_FAIL`. It is no longer an unbuilt
  candidate. Its Q06 issue is outside this mission's Q02-Q03 infrastructure
  fallback.
- `QM5_41364_xtixng-wclv-div-rv` was committed as a new XTI/XNG structural
  basket at `0ecc2dd174` and already owns pending compile work item
  `c406f0c2-a24e-4fde-a7e8-4b686bf6b271`.
- The forex lane `QM5_41143_gbpusd-month-end-benchmark-fix-hedge-flow`
  already owns pending logical Q02 row
  `2ed1bb9e-cec7-4929-b23f-8fe1ab7dbf75`.
- Four other build tasks remain active in the canonical task table:
  `QM5_38005`, `QM5_41197`, `QM5_38006`, and `QM5_41185`.

Accordingly, no EA was claimed or advanced. This is a new observation rather
than a duplicate of the 02:00 UTC receipt: the earlier WTI candidate has moved
through Q05, a fresh XTI/XNG build now owns the compile lane, the active tester
roster has expanded to eight terminals, and the new CPU window failed only on
its 100% maximum sample.

## Mutation boundary

Because the ceiling bound, no task or work item was created, claimed,
reprioritized, advanced, or re-enqueued. No EA source, EX5, setfile, Strategy
Card, registry, magic resolver, build result, pipeline evidence, or verdict was
changed. No compile, smoke, backtest, dispatch tick, terminal control, or
worker control was started.

The portfolio gate, portfolio-admission surfaces, `T_Live`, AutoTrading, live
manifests, and deploy manifests were untouched. Existing unrelated shared-
worktree changes were preserved and excluded from this receipt.

## Resume condition

On a later paced wake, take a new five-sample whole-host CPU window and repeat
the canonical farm-DB collision check. Claim exactly one diverse EA only when
both average and maximum CPU are strictly below `97%`.
