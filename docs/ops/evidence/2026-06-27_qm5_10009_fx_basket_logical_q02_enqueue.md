# QM5_10009 FX Basket Logical Q02 Enqueue - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate or live-manifest edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan artifact. A replay of the scan confirmed the only
strict-threshold survivors are already built:

| Rank | Pair | DEV Sharpe | OOS net Sharpe | OOS trades | Strict survivor |
|---|---:|---:|---:|---:|---|
| 1 | `EURUSD~AUDUSD` | -0.06 | 1.59 | 22 | no - DEV negative |
| 2 | `EURJPY~GBPJPY` | 0.59 | 1.53 | 24 | yes, `QM5_12533` |
| 3 | `AUDUSD~NZDUSD` | 0.13 | 1.29 | 14 | yes, `QM5_12532` |

I did not create a weak duplicate card from the DEV-negative `EURUSD~AUDUSD`
row. Current farm state also shows:

- `QM5_12533` logical-basket Q02: `PASS`
- `QM5_12533` logical-basket Q04: `FAIL`, real low-frequency failure with
  pooled PF 0.432 across 43 pooled trades
- `QM5_12532` logical-basket Q02: `PASS`
- `QM5_12532` logical-basket Q04: `FAIL`

Per the fallback instruction, I advanced an existing approved FX basket card:
`QM5_10009_rw-fx-cointeg-bb`, a D1 AUDUSD/NZDUSD/USDCAD Robot Wealth
cointegration basket. Prior Q02 rows existed only as per-leg work items, which
cannot judge the market-neutral basket spread.

## Repo Changes

- Added `framework/EAs/QM5_10009_rw-fx-cointeg-bb/basket_manifest.json`
  declaring one logical three-leg basket.
- Added `framework/EAs/QM5_10009_rw-fx-cointeg-bb/sets/QM5_10009_rw-fx-cointeg-bb_QM5_10009_AUD_NZD_CAD_COINTEG_D1_D1_backtest.set`
  with `RISK_FIXED=1000`, `RISK_PERCENT=0`, D1 host symbol `AUDUSD.DWX`, and
  explicit strategy inputs.

## Verification

- Compile: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_10009_rw-fx-cointeg-bb/QM5_10009_rw-fx-cointeg-bb.mq5 -Strict`
  -> `PASS`, 0 errors, 0 warnings.
- Set validation: `framework/scripts/build_check.ps1 -EALabel QM5_10009_rw-fx-cointeg-bb -SkipCompile -SkipMagicCheck -SkipLoggerSchema -SkipForbiddenScan -SkipInputGroupCheck -SkipPerfStaticCheck`
  -> `PASS`.
- Symbol scope: `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_10009_rw-fx-cointeg-bb --fail-on-leak --json`
  -> `BASKET_OK`.

## Queue State

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Backup before mutation:
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_10009_logical_basket_q02_20260627_1322.sqlite`

Inserted one non-duplicate logical Q02 row via farmctl basket-aware auto-enqueue:

| Field | Value |
|---|---|
| Work item | `d3b23700-088a-4857-a91e-5f31e8ac6b39` |
| EA | `QM5_10009` |
| Symbol | `QM5_10009_AUD_NZD_CAD_COINTEG_D1` |
| Phase | `Q02` |
| Status | `pending` |
| Host | `AUDUSD.DWX`, `D1` |
| Portfolio scope | `basket` |
| Setfile | `framework/EAs/QM5_10009_rw-fx-cointeg-bb/sets/QM5_10009_rw-fx-cointeg-bb_QM5_10009_AUD_NZD_CAD_COINTEG_D1_D1_backtest.set` |

No manual tester process was launched.
