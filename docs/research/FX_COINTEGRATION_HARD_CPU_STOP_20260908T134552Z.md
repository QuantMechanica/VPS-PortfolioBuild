# FX cointegration hard CPU stop

Recorded: 2026-09-08T13:45:52.7827805Z (15:45 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `51c069fd1b6547b77f04234cb09db757ca0908ff`

## Outcome

The mission stopped at its binding backtest-capacity gate before selecting,
claiming, generating, compiling, or enqueueing an EA. All ten factory terminals
`T1` through `T10` were occupied by ten governed active work items. This exceeds
the paced-fleet saturation threshold of seven active tester rows, so the lower
instantaneous host-CPU reading did not provide admission capacity.

The most recent complete cross-ledger reconciliation, recorded earlier on the
same branch and day in
`FX_COINTEGRATION_QM5_12507_Q02_DRAIN_WINDOW_STOP_20260908T122159Z.md`, found
that all 66 scan relationships and all approved runtime cointegration Cards
already had EA directories. It also confirmed that the anchor baskets do not
need Q02 repair: `QM5_12532` has logical-basket Q02 PASS and later Q05 FAIL,
while `QM5_12533` has logical-basket Q02 PASS and later Q04 FAIL.

The mission-authorized existing-card fallback remains
`QM5_12507_pair-coint-z`, whose logical EURUSD/GBPUSD H1 Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` was reread as pending, unclaimed,
attempt zero, and without a verdict. It is already the canonical open logical
Q02 lineage, so no duplicate row was appended.

## Binding capacity evidence

Five one-second whole-host CPU samples were `63.873902%`, `62.223800%`,
`58.012252%`, `59.383155%`, and `57.078609%` (average `60.114344%`, maximum
`63.873902%`). The process and work-item census nevertheless showed ten active
factory rows and ten path-attributed factory terminal processes:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T1 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `945832b9-41be-586a-849e-1d4c06502968` |
| T2 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `a50a0f1e-2d14-5a0e-af3b-ed3869309947` |
| T3 | Q04 | QM5_11182 | GBPUSD.DWX | `14b04e51-fe83-48b8-b3f9-9002d6518b16` |
| T4 | OPT_CENSUS | QM5_41163 | USDCAD.DWX | `f203872e-74a2-5ba7-b3be-75d7ade1e231` |
| T5 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `a3d38366-b734-58cb-9a27-f0e2cc71256e` |
| T6 | Q04 | QM5_41134 | XTIUSD.DWX | `7cc74af7-9da6-4aa8-84a0-e26d3edf800d` |
| T7 | Q02 | QM5_10269 | GBPUSD.DWX | `138e5d99-97e1-4d75-83ff-5ef8bea16940` |
| T8 | OPT_CENSUS | QM5_41305 | XTIUSD.DWX | `9638572a-f886-520c-98a9-52a12bb90d7f` |
| T9 | Q04 | QM5_41137 | XTIUSD.DWX | `cae12fd1-a131-43ad-a324-1a6aa2e70d5f` |
| T10 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `3239d5e7-010a-5e5f-b4e6-bb80d2a921f9` |

Free physical memory was 25.110 GiB of 63.120 GiB. `farmctl mt5-slots` reported
no duplicate workers and no orphaned terminal processes. `T_Live` and the FTMO
terminal were observed only by the read-only census and were not counted as
factory capacity or controlled.

## PACER guard and safety boundary

No generated `.mq5` source was written or edited, so the mandatory post-write
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile or compile enqueue was attempted, and therefore no un-audited source
could reach the compile queue.

No Strategy Card, EA source or EX5, registry or magic row, resolver, setfile,
basket manifest, farm task or work item, priority, hold, claim, terminal,
tester, verdict, portfolio-admission/KPI/Q08-contribution surface, portfolio
gate, `T_Live` manifest or terminal, deploy artifact, or AutoTrading state was
changed. The unrelated shared-worktree changes present before this mission
were preserved and excluded from this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_hard_cpu_stop_20260908T134552Z_board_advisor.json`.
