# Diversity funnel — CPU-ceiling stop after collision-safe preflight

Date: 2026-08-31 UTC (`2026-08-31T07:37:05.9349067Z`); 2026-08-31
09:37 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `faf6489a17d01b05858e516551e61e10ac4a18bd`

Status: stopped at the explicit backtest CPU ceiling before farm claim, source
mutation, compile, smoke, Q02 enqueue, or dispatch.

## Binding capacity result

The fresh five-sample whole-host CPU window measured `95.61%`, `94.49%`,
`91.90%`, `99.85%`, and `99.41%`. Average CPU was `96.25%` and maximum CPU was
`99.85%`. The paced admission rule requires both measures to remain strictly
below `97%`; the maximum side of the rule therefore bound.

No confirmation window was used to reopen this wake. Once the OWNER's explicit
stop condition bound, no backtest-capable work was admitted.

## Diversity-first selection and collision audit

The approved-card preflight used both approved reservoirs, the active EA and
magic registries, EA directories, and the live farm DB. It found no new card
that simultaneously had an approved G0 record, exact active EA identity,
preallocated active magic rows, an existing EA directory, and a missing MQ5 or
EX5. The strongest unbuilt structural FX cards remain outside the build skill's
admission boundary because their magic rows have not been allocated. In
particular, `QM5_41141_gbpusd-quarter-end-benchmark-fix-hedge-flow` retains
blocked build task `66329779-aa43-4905-97da-7fabc11823d3` and zero magic rows;
Development did not bypass that gate.

The farm DB also showed the market-neutral `QM5_41185_xauxag-fracd-rv` build
already claimed and `IN_PROGRESS` as task
`9ec2e69a-1163-4e64-9566-1646154bafd6`, so it was excluded as a collision.

The next non-duplicate priority-2 continuation was the already diagnosed
`QM5_11463_goodwin-j-session-high-breakout-usdjpy / EURUSD.DWX / H1` Q02
infrastructure row. Its preserved predecessor
`b0c9b4f2-64e1-4043-8c97-c2e767c0f991` failed before EA execution with
`NO_HISTORY;INCOMPLETE_RUNS` on T3, while the same authenticated MQ5/EX5
identity passed Q02 on GBPUSD. Current repository hashes still match the
diagnostic:

- MQ5: `e747f80b8b1b6d940f0b2c8c21dcc4f251bdfc6e8f6f78808c66226df0993c10`;
- EX5: `07a308a50e00283b2f11dced99a4b840024c7a3d6fbdcbea3816140e0a53f834`;
- EURUSD H1 backtest setfile: `511b98cd2e1fdcc14755c2e3ffc913959bcc0bcccb890da1ab1aa76223079a9a`.

The setfile remains `RISK_FIXED=1000` and `RISK_PERCENT=0`. No pending or active
Q02/Q03 row and no competing live task claim existed for this EA at preflight.
The CPU wall fired before a new atomic claim or append-only successor was
created.

## Farm load at the stop

At `2026-08-31T07:37:55Z`, `farm_state.sqlite` recorded seven active and 9,334
pending work items. The active rows occupied T1, T3, T4, T5, T7, T8, and T10
across Q07, Q10_NEWS, and OPT_CENSUS. This materially differs from the earlier
`2026-08-31T00:02:51Z` CPU-stop receipt, which observed four process-bound
factory rows and 64 pending build tasks. The changed load topology, fresh
candidate audit, and new CPU window make this a distinct coordination receipt.

## Scope and safety boundary

The `qm-build-ea-from-card` procedure and standard `codex_build_ea` contract
were used only for deterministic preflight. No Strategy Card, G0 decision, EA
source or binary, setfile, registry, resolver, build result, task claim, work
item, priority, verdict, or pipeline evidence was changed. No compile, smoke,
backtest, enqueue, dispatch tick, terminal control, or worker control was
started.

The portfolio gate, portfolio-admission surfaces, `T_Live`, AutoTrading, live
manifests, and deploy manifests were untouched. Existing unrelated shared-
worktree changes were preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260831T073705Z_board_advisor.json`.

## Continuation condition

A later paced wake must take a fresh five-sample capacity window and proceed
only when both average and maximum are strictly below `97%`. If the build
preconditions are still absent, atomically claim the distinct QM5_11463 EURUSD
infrastructure continuation, preserve the terminal predecessor, append exactly
one authenticated Q02 rerun, and steer it away from T3 without dispatching it
manually.
