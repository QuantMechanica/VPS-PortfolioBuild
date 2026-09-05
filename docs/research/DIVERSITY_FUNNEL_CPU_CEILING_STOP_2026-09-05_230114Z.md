# Diversity funnel — paced CPU-ceiling stop

Date: 2026-09-05 UTC (`2026-09-05T23:01:14.5379081Z`); 2026-09-06
01:01 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `ef33ef18eee919aa1af30002d4653e34cc75de33`

Status: stopped at the explicit factory CPU ceiling before claim, compile,
smoke, Q02 enqueue, or dispatch.

## Binding capacity result

A fresh five-sample whole-host CPU window measured `100.000%`, `100.000%`,
`100.000%`, `99.952%`, and `99.951%`. Average CPU was `99.981%` and maximum
CPU was `100.000%`. The paced admission rule requires both measures to remain
strictly below `97%`, so both dimensions bound.

The canonical farm DB concurrently held seven active rows: three
`OPT_CENSUS`, two `Q04`, one `Q07`, and one `Q08`. They occupied T1, T2, T4,
T6, T7, T8, and T9. The database also held 12,915 pending rows; that count is
reported as queue context, not as permission to dispatch.

Machine-readable evidence:
`artifacts/diversity_funnel_cpu_ceiling_stop_20260905T230114Z_board_advisor.json`.

## Selection result preserved for the next paced wake

The leading collision-free approved build is
`QM5_41171_wti-mturnpoint-tr` on `XTIUSD.DWX` D1. It is a deterministic
monthly WTI turning-point persistence rule with an expected six trades/year,
peer-reviewed WTI and statistical-method lineage, and explicit `R1` through
`R4` passes. Its approved card, EA source, SPEC, `RISK_FIXED=1000` setfile,
active EA registry row, and active magic row already exist and are clean. The
current branch has no EX5, and the canonical farm DB has no open agent task or
pending/active work item for `QM5_41171`.

That makes it a better diversity contribution than the remaining apparent
Q02-Q03 repairs. The strict infrastructure screen found no collision-free
low-frequency FX or rates lane still blocked solely by infrastructure:
several apparent candidates had later economic verdicts or active successors,
while legacy payload trade-frequency fields contradicted higher-frequency card
truth. The only strict current-binary residue was an XAU lane, which does not
advance the requested frontier beyond the existing XAU-heavy book.

The next wake must repeat the exact `QM5_41171` collision check and take a
fresh five-sample CPU window before creating a build claim. If both CPU average
and maximum are strictly below `97%`, it may claim this one EA and run the
standard `codex_build_ea` compile, worker-bound smoke, and Q02 handoff.

## Collision and mutation boundary

Because the ceiling bound, no task or work item was created, claimed,
reprioritized, advanced, or re-enqueued. No EA source, EX5, setfile, Strategy
Card, registry, magic resolver, build result, pipeline evidence, or verdict was
changed. No compile, smoke, backtest, dispatch tick, terminal control, or
worker control was started.

The portfolio gate, portfolio-admission surfaces, `T_Live`, AutoTrading, live
manifests, and deploy manifests were untouched. Existing unrelated shared-
worktree changes were preserved and excluded from this receipt.
