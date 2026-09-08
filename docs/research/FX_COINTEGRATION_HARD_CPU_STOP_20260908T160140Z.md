# FX cointegration hard CPU stop

Recorded: 2026-09-08T16:01:40.6961099Z (18:01 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `6ec26f030a8a252e815a6372a1ec48e4780d308e`

## Outcome

The mission stopped at its binding backtest-capacity gate before selecting,
claiming, generating, compiling, or enqueueing an EA. The canonical farm had
seven active work items, exactly the paced-fleet ceiling, while five one-second
whole-host CPU samples averaged 97.738250% and peaked at 99.219223%.

The governed 66-pair frontier remains exhausted. Repository evidence and the
current farm database agree that the two anchor baskets are not blocked at
Q02:

- `QM5_12532` has logical-basket Q02 `PASS`, Q04 `PASS`, then Q05 `FAIL`.
- `QM5_12533` has logical-basket Q02 `PASS`, then Q04 `FAIL`.

The mission-authorized existing-card fallback remains
`QM5_12507_pair-coint-z`. Its single logical EURUSD/GBPUSD H1 Q02 work item,
`547c4fd3-f3fd-4c59-b9dc-654e96521251`, remains `pending`, unclaimed, attempt
zero, and without a verdict. It is already the canonical open logical-basket
lineage, so another enqueue would be duplicate work.

## Binding capacity evidence

`farmctl work-items --status active` returned seven rows:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T4 | Q08 | QM5_10163 | USDJPY.DWX | `ba9aaa36-ff00-4099-be42-2c5473325926` |
| T10 | Q10_NEWS | QM5_11167 | XAUUSD.DWX | `6797ed1c-597a-4d44-82f9-7379d45b5e06` |
| T3 | Q02 | QM5_41167 | XTIUSD.DWX | `c3d110a3-8739-46ac-a29b-ddb5724f1778` |
| T6 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `a618b834-9262-54db-bdcf-6342fd204d2c` |
| T1 | OPT_CENSUS | QM5_41305 | XTIUSD.DWX | `6016c4d5-ea70-5715-908c-de77b6a6076b` |
| T2 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `78623d09-5177-5849-9310-e1d876862dd5` |
| T7 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `fe12242b-f998-5c70-983a-53741fcf8506` |

The path-aware process scan observed six factory terminals (`T1`, `T2`, `T3`,
`T4`, `T7`, and `T10`) and reported no duplicate workers or orphaned factory
terminal processes. The lower instantaneous process count does not override
the seven active governed rows or the measured host saturation. `T_Live` and
the external FTMO terminal were observed only to exclude them and were not
controlled.

CPU samples were 97.171110%, 99.219223%, 98.929755%, 97.954470%, and
95.416692%. Free physical memory was 37.303 GiB of 63.120 GiB.

## PACER guard and safety boundary

No generated `.mq5` source was written or edited, so the mandatory
post-write `audit_framework_input_pins.py --check-source` boundary was not
entered. No compile or compile enqueue was attempted.

No Strategy Card, EA source or EX5, registry or magic row, resolver, setfile,
basket manifest, farm task or work item, priority, hold, claim, terminal,
tester, verdict, portfolio-admission/KPI/Q08-contribution surface, portfolio
gate, `T_Live` manifest or terminal, deploy artifact, or AutoTrading state was
changed. The unrelated shared-worktree changes present before this mission
were preserved and excluded from this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_hard_cpu_stop_20260908T160140Z_board_advisor.json`.
