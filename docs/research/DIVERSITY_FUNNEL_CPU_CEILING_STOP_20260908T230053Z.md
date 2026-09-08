# Diversity funnel hard CPU stop

Recorded: 2026-09-08T23:00:53.7688405Z (2026-09-09 01:00 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `bfb22f34b51625c737b78b6c6a346e2b12944e30`

## Outcome

The paced diversity-first strategy-farm mission stopped at its binding capacity
gate before backlog ranking, farm claim, EA selection, source generation,
compile, or Q02 enqueue. Five fresh one-second whole-host CPU samples were
`90.0%`, `93.0%`, `91.0%`, `90.0%`, and `100.0%`. The average was `92.8%`, but
the maximum was `100.0%`, so the strict requirement that both values remain
below `97.0%` failed.

The read-only farm view concurrently showed eight active work items: four Q04
rows and four OPT_CENSUS rows. The terminal scan found factory MT5 processes on
T3 through T9 except T10, with T10's active row visible in the farm database.

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T5 | Q04 | QM5_10295 | GBPJPY.DWX | `add6735b-bfda-492f-8045-d1844e215071` |
| T4 | Q04 | QM5_10302 | EURUSD.DWX | `5710f1d3-9397-4217-a61d-f4422b1eab22` |
| T7 | Q04 | QM5_10443 | USDJPY.DWX | `a7f5cbfa-0a15-45ba-8fb1-560eae1875e9` |
| T3 | Q04 | QM5_10554 | GBPUSD.DWX | `2c12c29f-bb82-48b0-90ec-b0d160517547` |
| T8 | OPT_CENSUS | QM5_41163 | USDCAD.DWX | `9fc36567-d563-5730-82fe-ee97312ad4ce` |
| T9 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `ee4f9c15-15db-5c5d-a231-c47e06cfc5b3` |
| T10 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `e6117f96-eef9-5e69-a640-d0a59b48e25d` |
| T6 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `0810c107-22a5-52a5-840c-faed342024ca` |

Machine-readable companion:
`artifacts/diversity_funnel_cpu_ceiling_stop_20260908T230053Z.json`.

## PACER guard and safety boundary

No generated `.mq5` was written, so the mandatory
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile command, compile enqueue, manual backtest, Q02 enqueue, dispatch, or
terminal-control command was issued.

No farm task, work item, queue priority, card, registry, resolver, source, EX5,
setfile, portfolio gate, `T_Live` state, AutoTrading state, deploy manifest, or
live manifest was changed. Existing unrelated shared-worktree changes were
preserved and excluded from this receipt.

## Continuation condition

A later paced wake must begin with a fresh five-sample whole-host CPU window.
Only when both average and maximum are strictly below `97.0%` may it rank the
backlog, atomically claim one distinct highest-diversity unit through the farm
database, and proceed with the requested workflow. If an MQ5 is generated, the
binding source-pin audit must pass before any compile enqueue.
