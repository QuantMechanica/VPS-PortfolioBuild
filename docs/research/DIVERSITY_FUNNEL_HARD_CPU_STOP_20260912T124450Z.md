# Diversity funnel hard CPU stop

Recorded: 2026-09-12T12:44:50.3000507Z (14:44 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `9437ddbb93cd5d444cb23970763a02a4f0318af6`

## Outcome

The paced diversity-first strategy-farm mission stopped at its binding capacity
gate before backlog selection, farm claim, EA build, infrastructure repair,
compile, smoke, or Q02 enqueue. A fresh five-sample whole-host CPU window
returned `93.0%`, `97.0%`, `97.0%`, `94.0%`, and `93.0%`. The average was
`94.8%`, but the maximum was exactly `97.0%`, which fails the strict `<97.0%`
admission rule.

The independent read-only farm snapshot contained three active governed rows,
below the paced drain threshold of seven. `D:` had `72.207 GiB` free. Physical
memory had `43.599 GiB` free of `63.120 GiB`. CPU was the binding resource.

The OWNER instruction requires an immediate stop and summary when the backtest
CPU ceiling is hit. No candidate was claimed and no farm state was mutated.

## Read-only active-work snapshot

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T3 | Q04 | QM5_11265 | XAUUSD.DWX | `0b525a65-6e35-4a89-b03d-5dc3f1e8dd9d` |
| T4 | Q02 | QM5_10600 | XAUUSD.DWX | `7ae83f94-e6b5-4ff5-bdc2-3e64f8c92001` |
| T9 | OPT_CENSUS | QM5_41323 | NDX.DWX | `b7db2dd6-3f6b-5bef-a41c-d7f88340fa1e` |

## PACER guard and safety boundary

No generated `.mq5` was written, so the mandatory
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile or Q02 enqueue command was issued. No manual tester was started or
controlled.

No source/card, identity, registry, resolver, EA, setfile, basket manifest,
pipeline verdict, portfolio gate, deploy/T_Live manifest, `T_Live` state, or
AutoTrading state was changed. Existing unrelated shared-worktree changes were
preserved and excluded from this receipt's commit.

Machine-readable companion:
`artifacts/diversity_funnel_hard_cpu_stop_20260912T124450Z_board_advisor.json`.

## Continuation condition

A later paced wake must begin with a fresh five-sample CPU window and read-only
active-work census. It may claim one distinct diversity-first unit only when
both CPU average and maximum are strictly below `97.0%` and the governed active
row count is below seven. After any `.mq5` generation, the binding framework
input-pin audit must pass before any compile enqueue.
