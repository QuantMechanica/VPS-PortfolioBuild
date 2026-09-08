# FX cointegration hard CPU stop

Recorded: 2026-09-08T16:46:36.3712058Z (18:46 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `ca81e2b2b41bfad7692e535dc3a061605f2f626b`

## Outcome

The mission stopped at its binding backtest-capacity gate before selecting,
claiming, generating, compiling, or enqueueing an EA. The canonical farm had
eight active work items, above the paced-fleet ceiling of seven. Five
one-second whole-host CPU samples averaged 83.274345% and peaked at
91.623445%.

The same-day cross-ledger reconciliation remains authoritative: all 66
relationships in the frozen FX cointegration scan and all approved runtime
cointegration Cards already have EA directories. The two anchor baskets are
not blocked at Q02: `QM5_12532` has logical-basket Q02 `PASS`, Q04 `PASS`,
then Q05 `FAIL`; `QM5_12533` has logical-basket Q02 `PASS`, then Q04 `FAIL`.

The mission-authorized existing-card fallback remains
`QM5_12507_pair-coint-z`. Its single logical EURUSD/GBPUSD H1 Q02 work item,
`547c4fd3-f3fd-4c59-b9dc-654e96521251`, remains `pending`, unclaimed, attempt
zero, and without a verdict. It is already the canonical open logical-basket
lineage, so another enqueue would be duplicate work.

## Binding capacity evidence

`farmctl work-items --status active` returned eight rows:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T10 | Q10_NEWS | QM5_11167 | XAUUSD.DWX | `6797ed1c-597a-4d44-82f9-7379d45b5e06` |
| T9 | Q06 | QM5_41159 | XTIUSD.DWX | `db2b0b58-9ecf-49d8-96ff-e53e01bd95ef` |
| T5 | OPT_CENSUS | QM5_41163 | USDCAD.DWX | `c19d8c7d-a194-5871-b0e9-9246f9c8e2e6` |
| T1 | Q02 | QM5_41169 | XTIUSD.DWX | `84a8e285-7785-40c4-9b4f-aa8295c7a288` |
| T8 | Q04 | QM5_41170 | XTIUSD.DWX | `d63acf17-06d2-494e-a5e7-3ff62746bd94` |
| T2 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `38ee6089-a366-52e7-8072-81a200dbb925` |
| T3 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `ea7aa84a-b0d1-5a26-b1f0-1e5a8ddcd35f` |
| T4 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `b8cbe6f9-0447-591d-ab6f-1ee7a89cacb9` |

The path-aware process scan observed five currently running factory terminals
(`T2`, `T3`, `T4`, `T9`, and `T10`) and reported no duplicate workers or
orphaned factory terminal processes. The lower transient process count does
not override the eight active governed rows. `T_Live` and the external FTMO
terminal were observed only to exclude them and were not controlled.

CPU samples were 91.623445%, 87.029319%, 91.610841%, 78.127294%, and
67.980827%. Free physical memory was 25.945 GiB of 63.120 GiB.

## PACER guard and safety boundary

No generated `.mq5` source was written or edited, so the mandatory post-write
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile or compile enqueue was attempted.

No Strategy Card, EA source or EX5, registry or magic row, resolver, setfile,
basket manifest, farm task or work item, priority, hold, claim, terminal,
tester, verdict, portfolio-admission/KPI/Q08-contribution surface, portfolio
gate, `T_Live` manifest or terminal, deploy artifact, or AutoTrading state was
changed. The unrelated shared-worktree changes present before this mission
were preserved and excluded from this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_hard_cpu_stop_20260908T164636Z_board_advisor.json`.
