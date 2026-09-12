# Diversity funnel hard CPU stop

Recorded: 2026-09-12T09:30:45.1484331Z (11:30 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `b840409f9f7a1dda39932463e71d7388df513aa0`

## Outcome

The paced diversity-first strategy-farm mission stopped at its binding capacity
gate before backlog selection, farm claim, EA build, infrastructure repair,
compile, smoke, or Q02 enqueue. A fresh five-sample whole-host CPU window
returned `100.000000%` for every sample. Both the average and maximum were
therefore `100.000000%`, above the strict `<97.0%` admission ceiling.

The independent read-only farm snapshot contained six active governed rows,
below the paced drain threshold of seven. `D:` had `61.841 GiB` free. Physical
memory had `15.889 GiB` free of `63.120 GiB`. CPU was the binding resource.

The OWNER instruction requires an immediate stop and summary when the backtest
CPU ceiling is hit. No candidate was claimed and no farm state was mutated.

## Read-only active-work snapshot

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T1 | OPT_CENSUS | QM5_41323 | NDX.DWX | `a96ef3cc-81f0-5c5c-acbb-3336f5a678f7` |
| T10 | OPT_CENSUS | QM5_41398 | USDJPY.DWX | `d08254a5-eeb6-5cce-9aac-92418b0350f6` |
| T4 | Q07 | QM5_11563 | GBPUSD.DWX | `eb1cfecc-cb25-4526-81a9-8ed7651ffe40` |
| T6 | Q02 | QM5_10227 | XAUUSD.DWX | `a4342958-c810-481a-a7b9-db7a5055d615` |
| T7 | OPT_CENSUS | QM5_41322 | XAUUSD.DWX | `3ceb4226-02de-5a80-b3d6-a81f92dc8006` |
| T9 | Q05 | QM5_11233 | XAUUSD.DWX | `2420450a-1ab1-49ca-a169-73500aab6e01` |

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
`artifacts/diversity_funnel_hard_cpu_stop_20260912T093045Z_board_advisor.json`.

## Continuation condition

A later paced wake must begin with a fresh five-sample CPU window and read-only
active-work census. It may claim one distinct diversity-first unit only when
both CPU average and maximum are strictly below `97.0%` and the governed active
row count is below seven. After any `.mq5` generation, the binding framework
input-pin audit must pass before any compile enqueue.
