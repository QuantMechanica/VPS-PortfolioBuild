# Diverse Basket Q02 Enqueue - 2026-06-26

Scope: branch `agents/board-advisor`; no T_Live or AutoTrading actions.

## Built / Repaired

- `QM5_10024_rw-fx-comm-basket`
  - Added/validated basket manifest host routing through `AUDUSD.DWX`.
  - Brought `SPEC.md` into the current seven-section Q01 validator format.
  - Added logical basket setfile:
    `QM5_10024_rw-fx-comm-basket_QM5_10024_RW_FX_COMM_BASKET_D1_D1_backtest.set`.
  - Strict compile: PASS, 0 errors, 0 warnings.

- `QM5_12533_edgelab-eurjpy-gbpjpy-cointegration`
  - Added logical basket Q02 setfile:
    `QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set`.
  - Strict compile: PASS, 0 errors, 0 warnings.

- `QM5_12532_edgelab-audnzd-cointegration`
  - Added logical basket Q02 setfile:
    `QM5_12532_edgelab-audnzd-cointegration_QM5_12532_AUDNZD_COINTEGRATION_D1_D1_backtest.set`.
  - Strict compile: PASS, 0 errors, 0 warnings.

## Farm Queue Actions

Inserted logical basket Q02 work items in `D:/QM/strategy_farm/state/farm_state.sqlite`:

| EA | Logical symbol | Work item | Parent task | Host |
|---|---|---:|---:|---|
| `QM5_10024` | `QM5_10024_RW_FX_COMM_BASKET_D1` | `9874a456` | `fe3f3ecc` | `AUDUSD.DWX` |
| `QM5_12533` | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` | `fe14e345` | `1ca1c629` | `EURJPY.DWX` |
| `QM5_12532` | `QM5_12532_AUDNZD_COINTEGRATION_D1` | `e4890d77` | `5865e8c0` | `AUDUSD.DWX` |

Retired 32 stale pending `QM5_10024` standalone-leg Q02 rows as `INVALID` / `basket_manifest_logical_q02`
so the factory does not burn CPU testing the four legs as independent directional systems.

## Diversity Gained

- `QM5_10024`: commodity-linked FX stat-arb basket: `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`, `AUDNZD.DWX`.
- `QM5_12533`: JPY-cross FX market-neutral cointegration: `EURJPY.DWX` / `GBPJPY.DWX`.
- `QM5_12532`: Antipodean FX market-neutral cointegration: `AUDUSD.DWX` / `NZDUSD.DWX`.

These are all non-index, non-metal, non-energy directional sleeves and should be materially less correlated
to the current Q12 book if they survive Q02 onward.

## Blockers / Not Built

- The prior 66-pair FX scan did not provide 3-4 further buildable pair cards: only `EURJPY~GBPJPY` and
  `AUDUSD~NZDUSD` cleared the DEV/OOS and trade-count filters in
  `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.
- `QM5_1457_as-predict-bonds` and `QM5_1459_as-lumber-gold` are approved cards but are not buildable under
  `qm-build-ea-from-card` preflight yet: no active magic rows, and their required bond/lumber/ETF proxy data
  is not DWX-native.
- No BTC/ETH `.DWX` symbols were found in `framework/registry/dwx_symbol_matrix.csv`; `XTIUSD.DWX` is present,
  but available XTI cards are directional single-symbol candidates rather than new market-neutral sleeves.
