# FX cointegration hard CPU stop

Recorded: 2026-09-08T17:30:35Z (19:30 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `8d84c43564edb2fc989fd9716318b822092c41da`

## Outcome

The mission stopped at its binding backtest CPU gate before selecting,
claiming, generating, compiling, or enqueueing an EA. Five two-second
whole-host CPU samples were 100%, 94%, 96%, 90%, and 99%: average 95.8% and
maximum 100%. The maximum crossed the 97% hard ceiling. The canonical farm
also had seven active work items, exactly the paced-fleet ceiling.

The same-day cross-ledger reconciliation remains authoritative: all 66
relationships in the frozen FX cointegration scan and all approved runtime
cointegration Cards already have EA directories. The two anchor baskets are
not blocked at Q02: `QM5_12532` has logical-basket Q02 `PASS`, Q04 `PASS`,
then Q05 `FAIL`; `QM5_12533` has logical-basket Q02 `PASS`, then Q04 `FAIL`.

The mission-authorized existing-card fallback remains
`QM5_12507_pair-coint-z`, a concrete EURUSD/GBPUSD basket. Its single logical
H1 Q02 work item, `547c4fd3-f3fd-4c59-b9dc-654e96521251`, remains `pending`,
unclaimed, attempt zero, and without a verdict. It is already the canonical
open logical-basket lineage, so another enqueue would duplicate work.

## Binding capacity evidence

`farmctl work-items --status active` returned seven rows:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T10 | Q10_NEWS | QM5_11167 | XAUUSD.DWX | `6797ed1c-597a-4d44-82f9-7379d45b5e06` |
| T8 | Q07 | QM5_41159 | XTIUSD.DWX | `4605e1f7-7a2d-44c8-9989-5451faf4902a` |
| T7 | OPT_CENSUS | QM5_41163 | USDCAD.DWX | `99af32eb-728d-59d3-b836-331a349aded6` |
| T4 | Q07 | QM5_41167 | XTIUSD.DWX | `869da083-b271-4ce6-a054-966163939a6c` |
| T3 | Q04 | QM5_41182 | XTIUSD.DWX | `ec7c0ade-bcb7-4eeb-abba-e84955deff49` |
| T6 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `3d318bce-78a7-53bc-8c78-f552099ac6ea` |
| T5 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `2d5d9869-c512-5063-a2bb-04f7d93d3b42` |

The path-aware process scan observed six running factory terminals (`T4`,
`T5`, `T6`, `T7`, `T8`, and `T10`) and reported no duplicate workers or
orphaned factory terminal processes. All ten terminal-worker daemons were
present. `T_Live` and the external FTMO terminal were observed only to exclude
them and were not controlled.

Free physical memory was 19.770 GiB of 63.120 GiB.

## PACER guard and safety boundary

No generated `.mq5` source was written or edited, so the mandatory post-write
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile or compile enqueue was attempted, and no Q02 row was enqueued.

No Strategy Card, EA source or EX5, registry or magic row, resolver, setfile,
basket manifest, farm task or work item, priority, hold, claim, terminal,
tester, verdict, portfolio-admission/KPI/Q08-contribution surface, portfolio
gate, `T_Live` manifest or terminal, deploy artifact, or AutoTrading state was
changed. The unrelated shared-worktree changes present before this mission
were preserved and excluded from this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_hard_cpu_stop_20260908T173035Z_board_advisor.json`.
