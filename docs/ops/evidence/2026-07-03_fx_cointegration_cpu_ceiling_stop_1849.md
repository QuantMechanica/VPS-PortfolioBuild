# FX Cointegration CPU Ceiling Stop - 2026-07-03 18:49 Europe/Berlin

Mission: grow the certified V5 portfolio book with new forex sleeves, preferring market-neutral FX cointegration baskets from the 66-pair scan and fixing QM5_12532 / QM5_12533 first if Q02-blocked.

## Findings

- Source check: `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` says only two of 66 FX cointegration pairs cleared the strict scan bar: EURJPY~GBPJPY and AUDUSD~NZDUSD.
- QM5_12533 EURJPY~GBPJPY is not Q02-blocked: latest state is Q02 PASS, Q04 FAIL (`ff2cb183-8269-4e63-abaf-27ba79afdb62`).
- QM5_12532 AUDUSD~NZDUSD is not Q02-blocked: latest state is Q02 PASS, Q04 PASS, Q05 FAIL (`82cab3d1-bf05-4aa4-8278-86c8064b16e7`).
- Registered EdgeLab FX cointegration map is exhausted for new builds: 30 active registry rows, 30 EA folders, no unbuilt registered pair found.
- Existing nonduplicate continuation QM5_12712 EURGBP~EURAUD has already passed Q02 through Q06 and is active at Q07 (`1b9fa7a5-48a7-4e57-a699-9e55dfb0cb19`, claimed by T1).
- Recent tail QM5_12978 GBPUSD~USDCAD is already advanced through Q02 PASS and Q03 PASS, with Q04 FAIL (`bf98a2c5-0ed2-4410-abbe-7e66fe97e843`).

## CPU Ceiling

Current factory state has five active work items:

| Terminal | EA | Phase | Symbol | Work item |
|---|---|---|---|---|
| T4 | QM5_10004 | Q02 | EURJPY.DWX | 916b4b0c-eebc-422a-9136-2734218ea326 |
| T2 | QM5_10014 | Q02 | GBPJPY.DWX | bb55fa91-245d-4615-9e4a-46ba5a812fed |
| T5 | QM5_10440 | Q05 | NDX.DWX | fcde2acb-515d-49da-bd2b-3ddddf72cdf2 |
| T3 | QM5_10939 | Q07 | XAUUSD.DWX | 3a4a9c20-7378-4822-a1f6-089f9ef9c2cd |
| T1 | QM5_12712 | Q07 | QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1 | 1b9fa7a5-48a7-4e57-a699-9e55dfb0cb19 |

No Q02 enqueue or other database mutation was made, because the mission explicitly says to stop when the backtest CPU ceiling is hit.

## Safety

- No T_Live access.
- No AutoTrading change.
- No portfolio gate / portfolio admission / KPI / Q08 contribution file touched.
- No deploy manifest touched.
- Machine-readable artifact: `artifacts/fx_cointegration_cpu_ceiling_stop_20260703T1849_board_advisor.json`.
