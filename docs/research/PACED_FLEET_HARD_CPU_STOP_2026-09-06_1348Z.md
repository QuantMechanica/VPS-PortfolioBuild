# Paced fleet hard CPU stop

Date: 2026-09-06 13:48 UTC (15:48 Europe/Berlin)

Branch: `agents/board-advisor`

Observation base: `224390d6ac24704337c4fb6ac04cc51a023d65b3`

Status: stopped at the binding host-CPU ceiling before any farm claim,
generated-source write, compile enqueue, smoke, Q02 enqueue, or terminal action.

## Binding admission result

The required five one-second whole-host samples were `69.091546%`,
`73.689669%`, `82.362186%`, `98.090192%`, and `99.235333%`. Their average was
`84.493785%` and their maximum was `99.235333%`.

Admission requires both average and maximum to remain strictly below `97%`.
The maximum bound, so the mission's explicit CPU stop applied.

The read-only farm snapshot concurrently showed six active work items and
11,292 pending rows. The active rows were Q08 `QM5_12935/XAUUSD` on T9, Q04
`QM5_1800/AUDCAD` on T3, Q04 `QM5_11875/GBPJPY` on T2, and three governed
`COMPILE_EA` rows for `QM5_41099`, `QM5_41100`, and `QM5_41101` on T8/T7/T1.

Machine-readable evidence is
`artifacts/paced_fleet_hard_cpu_stop_20260906T1348Z_board_advisor.json`.

## Collision findings preserved

- `QM5_41171_wti-mturnpoint-tr`, identified by the previous stop receipt, is
  no longer available: its build is done, its current lineage has Q02 `PASS`
  and Q04 `PASS_LOWFREQ`, and Q05 row
  `6cc07c90-e235-4d24-8db9-71b51d71fd80` is pending. Its unrelated working-tree
  changes were preserved.
- `QM5_41259_wti-mwasser-shift-tr` already owns pending governed compile row
  `f25a49cf-a237-46f6-92ff-15344fca2844`, created at 13:16:03 UTC. Creating or
  claiming a duplicate would collide with the existing continuation.
- `QM5_41168_xauxag-mcoxstuart-rv` is not a fresh build candidate: the DB has
  one blocked and one stale pending build task plus two failed compile rows;
  the pending task records a prior duplicate-session race.

These findings remove the apparent leading candidates without mutating their
tasks or artifacts. A later wake must repeat the live collision screen rather
than relying on this snapshot.

## Stop and safety boundary

Because CPU admission failed, no farm task or work item was created, claimed,
reprioritized, advanced, released, or enqueued. No EA source, EX5, setfile,
card, registry, magic resolver, build result, or gate evidence was changed.
Since no generated MQ5 was written, the PACER framework-input-pin audit was not
applicable and no compile command was considered.

No smoke, backtest, dispatch tick, process control, terminal reservation,
portfolio-gate change, `T_Live`/deploy-manifest change, or AutoTrading action
occurred. Existing unrelated shared-worktree changes were left untouched.
