# FX Cointegration CPU Ceiling Stop - 2026-07-04 01:18 Europe/Berlin

Branch: `agents/board-advisor`

Mission: grow the certified V5 book with new forex sleeves, preferring
market-neutral FX cointegration baskets from the 66-pair scan and fixing
`QM5_12532` / `QM5_12533` first if either is Q02-blocked.

## Findings

- Source check: `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
  documents only two strict 66-pair FX cointegration survivors:
  `EURJPY~GBPJPY` and `AUDUSD~NZDUSD`.
- Fresh rerun of `python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`
  still returns only those two strict survivors. Triangular mispricing remains
  dead net of cost.
- `QM5_12533` (`EURJPY~GBPJPY`) is not Q02-blocked. Latest state is Q02
  `PASS`, then Q04 `FAIL`.
- `QM5_12532` (`AUDUSD~NZDUSD`) is not Q02-blocked. Latest state is Q02
  `PASS`, Q04 `PASS`, then Q05 `FAIL`.
- Registered EdgeLab FX cointegration build map is exhausted: 31 active
  registry rows and 31 matching EA folders.
- Visible local EdgeLab cointegration card map is also exhausted: 45 card
  files checked and 0 without matching EA folders.
- Existing nonduplicate FX continuation `QM5_12778`
  (`AUDUSD~EURJPY`) has progressed through Q06 `PASS` and is already pending
  Q07 as work item `fc554e0c-e66e-486a-a83d-c7301e67c615`.

## CPU Ceiling

`framework/scripts/mt5_queue_status.py` showed five active factory work items:

| Terminal | EA | Phase | Symbol | Work item |
|---|---|---|---|---|
| T1 | `QM5_10557` | Q02 | `GBPJPY.DWX` | `2bcc0882-a38c-47d6-80f6-41c673258781` |
| T2 | `QM5_1567` | Q04 | `NZDCAD.DWX` | `9551e23a-933d-4cbd-ad5d-359d68cd35b9` |
| T3 | `QM5_10142` | Q05 | `NDX.DWX` | `94c74d83-69d5-483c-9ba5-a55c1e6ca8e1` |
| T4 | `QM5_1567` | Q02 | `EURGBP.DWX` | `f0269d38-d4f0-45ee-afca-d77f75267419` |
| T5 | `QM5_10718` | Q02 | `QM5_10718_FX8_BASKET_D1` | `92ba2ca6-1147-4432-af19-929a45993f4a` |

No Q02/Q07 enqueue, database mutation, or manual MT5 backtest was made because
the mission explicitly says to stop when the backtest CPU ceiling is hit.

## Safety

- No `T_Live` access.
- No AutoTrading change.
- No portfolio gate, portfolio admission, KPI, Q08 contribution, or deploy
  manifest file touched.
- Machine-readable artifact:
  `artifacts/fx_cointegration_cpu_ceiling_stop_20260704T0118_board_advisor.json`.
