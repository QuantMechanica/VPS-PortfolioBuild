# FX cointegration frontier: five-terminal hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T10:16:30Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `dde2026dfd52c337237fba4f7b1d906d2862f576`

Status: no reputable, non-duplicate unbuilt frozen-scan pair; both preferred
anchors are past Q02; the selected existing fallback is already queued; stopped
at the explicit backtest CPU ceiling before any card, build, queue, dispatch,
compile, or tester action

## Governed pair decision

The bounded OWNER-requested source
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` was read completely. It
admits only two strict survivors from the original 66-pair scan:
`AUDUSD.DWX` / `NZDUSD.DWX` and `EURJPY.DWX` / `GBPJPY.DWX`. Both are already
approved and built as `QM5_12532` and `QM5_12533`. The source rejects or
declines to card the other tested FX, triangular, and cross-asset forms.

The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 frozen relationships: 66 covered and zero uncovered. A new
scan identity would duplicate governed work, while promoting a rejected or weak
row would fail the reputable-source criterion.

The preferred anchors require no Q02 repair. `QM5_12532` has Q02 PASS and Q04
PASS before Q05 FAIL (`pf=0.950`, floor `1.0`). `QM5_12533` has Q02 PASS before
Q04 FAIL (pooled net PF `0.432`). Neither has a current Q02 ONINIT or NO_HISTORY
blocker.

## Existing-pair fallback reconciliation

The last selected structural D1 basket, `QM5_20219_usdjpy-nzdusd`
(`USDJPY.DWX` / `NZDUSD.DWX`), already has Q02 PASS. A fresh read-only query of
`farm_state.sqlite` found its current next-gate Q03 row
`4514a6c7-0a2e-4523-a756-b63a232dd8aa` pending and an older Q04 row
`b721ce82-2d53-46db-b2d0-f20b561a1513` also pending. No enqueue, requeue, or
priority mutation was appropriate: another successor would be duplicate work,
and the capacity stop prohibited dispatch or tester activity.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-26T10:16:07Z`
observed five governed factory terminals actively testing: T2, T3, T4, T7, and
T9. `T_Live` was observed only to exclude it and was not controlled. The paced
launch gate remained `1`.

Five fresh one-second whole-host CPU readings were `99.62%`, `90.83%`,
`85.84%`, `75.62%`, and `96.19%`. Their average was `89.62%` and their maximum
was `99.62%`. The explicit ceiling binds when either the average or maximum is
at least `97%`; the maximum triggered the stop. Four `metatester64` processes
were present at sample completion.

Per the mission stop condition, no further Strategy Card or EA creation,
registry or magic mutation, compile, build check, queue mutation, dispatch tick,
tester launch, terminal reservation, terminal control, or backtest followed.
Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T101630Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt recorded seven active factory terminals and seven
tester processes. This observation records a contraction to five terminals and
four testers while still catching a hard-ceiling spike; it also freshly
reconciles the fallback basket's pending Q03 and Q04 rows. It therefore avoids
duplicating a pair, card, EA, or pipeline enqueue.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this
  receipt.
