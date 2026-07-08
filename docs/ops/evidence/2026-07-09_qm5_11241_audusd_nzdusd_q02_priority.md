# QM5_11241 AUDUSD/NZDUSD Cointegration Q02 Priority

Date: 2026-07-09 local / 2026-07-08 UTC
Branch: `agents/board-advisor`
Operator: Codex

## Action

Advanced an existing low-frequency FX cointegration fallback without creating a
duplicate queue row or launching MT5 manually:

- EA: `QM5_11241_ht-coint-spread`
- Pair: `AUDUSD.DWX` / `NZDUSD.DWX`
- Logical row label: `QM5_11241_AUDUSD_NZDUSD_COINT_D1`
- Work item: `d3a12c8f-6853-46e2-871a-ada201c91425`
- Phase: `Q02`
- Status after update: `pending`
- New work items inserted: `0`
- DB backup before mutation:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11241_audusd_nzdusd_q02_priority_20260708T224956Z.sqlite`

## Decision Path

The controlling strict scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. It names only
`QM5_12533` and `QM5_12532` as strict 66-pair survivors. Both are already built
and no longer Q02-blocked:

| EA | Pair | Current state |
|---|---|---|
| `QM5_12532` | `AUDUSD.DWX` / `NZDUSD.DWX` | Q02 PASS, Q04 PASS, later Q05 FAIL |
| `QM5_12533` | `EURJPY.DWX` / `GBPJPY.DWX` | Q02 PASS, later Q04 FAIL |

The extended 2026-07-06 screen rows visible in the repo are also already built
and have produced Q02 evidence:

| EA | Pair | Current state |
|---|---|---|
| `QM5_13024` | `AUDCAD.DWX` / `GBPAUD.DWX` | Q02 PASS, Q04 FAIL |
| `QM5_13029` | `GBPCAD.DWX` / `GBPNZD.DWX` | Q02 PASS, Q03 PASS, Q04 FAIL |
| `QM5_13058` | `AUDCAD.DWX` / `GBPNZD.DWX` | Q02 PASS, Q03 PASS, Q04 FAIL |
| `QM5_13062` | `AUDCAD.DWX` / `EURUSD.DWX` | Q02 PASS, Q03 PASS, Q04 FAIL |

With no buildable unbuilt non-duplicate FX cointegration pair remaining,
`QM5_11241` was selected as the existing-forex-card fallback. Its EURUSD/GBPUSD
instance had already run and failed Q02 on strategy evidence (`MIN_TRADES_NOT_MET`);
the AUDUSD host row was still pending and needed pair-scoped payload metadata.

## Queue Repair

The existing pending row was updated in place with:

- `priority_track=true`
- `portfolio_scope=basket`
- `history_check_scope=pair_basket_symbols`
- `logical_symbol=QM5_11241_AUDUSD_NZDUSD_COINT_D1`
- `basket_symbols=["AUDUSD.DWX","NZDUSD.DWX"]`
- `host_symbol=AUDUSD.DWX`
- `host_timeframe=D1`
- `RISK_FIXED=1000`, `RISK_PERCENT=0`
- `from_date=2018.07.02`, `to_date=2022.12.31`
- `tester_currency=USD`, `tester_deposit=100000`

The AUDUSD backtest setfile was verified to bind:

- `strategy_partner_symbol=NZDUSD.DWX`
- `strategy_partner_slot=3`
- `strategy_formation_bars=504`
- `strategy_z_window=60`
- `strategy_entry_z=2.0`
- `strategy_exit_z=0.25`

## Verification

- `pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_11241_ht-coint-spread -SkipCompile`:
  PASS, report `D:/QM/reports/framework/21/build_check_20260708_224852.json`
- `python tools/strategy_farm/validate_symbol_scope.py --ea QM5_11241_ht-coint-spread --json`:
  `BASKET_OK`, `n_violations=0`
- DB check: work item `d3a12c8f-6853-46e2-871a-ada201c91425` remains `Q02`
  `pending`, `attempt_count=0`, with no duplicate insert.

CPU ceiling was active at verification time: factory terminals `T1`, `T2`, `T3`,
`T4`, and `T6` were running MT5 jobs; `terminal64_running_count=7` including
non-pipeline T_Live/FTMO processes. No manual MT5 dispatch was launched.

No `T_Live`, AutoTrading, deploy manifest, portfolio admission gate, portfolio
KPI, or Q08 contribution file was touched.

Machine-readable artifact:
`artifacts/qm5_11241_audusd_nzdusd_q02_priority_20260708T224957Z.json`.
