# QM5_9184 FX Cointegration Q02 Manifest Priority - 2026-07-09

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate or live-manifest edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
strict 66-pair FX cointegration scan artifact. Its only strict survivors,
`QM5_12533` EURJPY/GBPJPY and `QM5_12532` AUDUSD/NZDUSD, are already built and
not Q02-blocked. The extended frontier siblings already built from the same
method (`QM5_13024`, `QM5_13029`, `QM5_13058`, `QM5_13062`) have also reached
later terminal gates.

Per the mission fallback, this pass advanced an existing forex cointegration
card rather than creating a duplicate weaker card/build.

## Target

`QM5_9184_jstm-pair-cointegration-fx`

- Logical basket: `QM5_9184_AUDUSD_NZDUSD_COINTEGRATION_D1`
- Host/timeframe: `AUDUSD.DWX`, `D1`
- Basket legs: `AUDUSD.DWX`, `NZDUSD.DWX`
- Existing pending Q02 work item: `3bb02373-5f50-496e-9558-8590a25837db`
- Setfile:
  `framework/EAs/QM5_9184_jstm-pair-cointegration-fx/sets/QM5_9184_jstm-pair-cointegration-fx_AUDUSD.DWX_D1_backtest.set`
- Manifest added:
  `framework/EAs/QM5_9184_jstm-pair-cointegration-fx/basket_manifest.json`

## Prior State

- AUDUSD-host Q02 had repeated infra failures on `NO_HISTORY` /
  `INCOMPLETE_RUNS`.
- NZDUSD-host Q02 reached a strategy verdict, `MIN_TRADES_NOT_MET`.
- The current AUDUSD row was already pending after a history-adjusted Q02 refeed.
- No pending/active duplicate existed before the payload update.

## Validation

```powershell
python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_9184_jstm-pair-cointegration-fx --verbose
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_9184_jstm-pair-cointegration-fx -RepoRoot C:/QM/repo -SkipCompile
```

Results:

- Symbol scope: `BASKET_OK`, 0 violations.
- Build check: `PASS`, 0 failures, 0 warnings.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260709_082156.json`
- Build check refreshed only the canonical `build_hash` headers on the
  `AUDUSD.DWX` and `NZDUSD.DWX` backtest setfiles.

## Queue Action

Backup before DB mutation:
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_9184_basket_manifest_q02_20260709T081952Z.sqlite`

Updated the existing pending Q02 row in place:

| Field | Value |
|---|---|
| Work item | `3bb02373-5f50-496e-9558-8590a25837db` |
| EA | `QM5_9184` |
| Phase | `Q02` |
| Symbol | `AUDUSD.DWX` |
| Status after update | `pending` |
| Claimed by | `NULL` |
| Basket manifest | `C:/QM/repo/framework/EAs/QM5_9184_jstm-pair-cointegration-fx/basket_manifest.json` |
| Basket symbols | `AUDUSD.DWX`, `NZDUSD.DWX` |
| Payload scope | `portfolio_scope=basket` |
| Tester currency/deposit | `USD`, `100000` |
| Priority marker | `priority_track=true` |
| Duplicate guard | exactly one pending/active `QM5_9184` / `AUDUSD.DWX` / `Q02` row |

No new work item was inserted. No manual MT5 run was launched. At final
verification the farm already had 7 active worker-owned backtests and 4,987
pending rows, so execution is left to the paced worker under the CPU-ceiling
discipline.

## Safety

- `T_Live` touched: no
- AutoTrading touched: no
- Portfolio gate touched: no
- `portfolio_admission` / `_kpi` / `_q08_contribution` touched: no
- T_Live manifest touched: no
