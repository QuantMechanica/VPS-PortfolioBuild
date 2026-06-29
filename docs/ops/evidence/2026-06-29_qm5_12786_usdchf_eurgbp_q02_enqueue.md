# QM5_12786 USDCHF/EURGBP Cointegration Basket Q02 Enqueue

Date: 2026-06-29

## Scope

- EA: `QM5_12786_edgelab-usdchf-eurgbp-cointegration`
- Logical basket symbol: `QM5_12786_USDCHF_EURGBP_COINTEGRATION_D1`
- Traded legs: `USDCHF.DWX` / `EURGBP.DWX`
- Conversion history declared in basket manifest: `EURUSD.DWX`, `GBPUSD.DWX`

`QM5_12532` and `QM5_12533` were checked first in farm state. Both already had
logical-basket Q02 `PASS` rows, so no ONINIT / NO_HISTORY repair was required.

## Candidate Selection

The published 66-pair scan hard-certified only `QM5_12533` and `QM5_12532`.
All positive-hedge scan tail candidates through rank 27 already had EA folders.
The next unbuilt positive-hedge pair from the same `analyze_cross_asset_v3.py`
logic was:

| rank | pair | DEV Sharpe | OOS net Sharpe | OOS ret | OOS state changes | hedge | half-life |
|---:|---|---:|---:|---:|---:|---:|---:|
| 28 | `USDCHF~EURGBP` | 0.0840 | -0.3881 | -3.8501% | 15 | 0.138258947 | 92.63d |

This is a very high-risk exploratory tail basket, not a hard survivor.

## Build Evidence

- Approved card: `artifacts/cards_approved/QM5_12786_edgelab-usdchf-eurgbp-cointegration.md`
- EA source: `framework/EAs/QM5_12786_edgelab-usdchf-eurgbp-cointegration/QM5_12786_edgelab-usdchf-eurgbp-cointegration.mq5`
- Basket manifest: `framework/EAs/QM5_12786_edgelab-usdchf-eurgbp-cointegration/basket_manifest.json`
- Backtest setfile: `framework/EAs/QM5_12786_edgelab-usdchf-eurgbp-cointegration/sets/QM5_12786_edgelab-usdchf-eurgbp-cointegration_QM5_12786_USDCHF_EURGBP_COINTEGRATION_D1_D1_backtest.set`
- Compile log: `framework/build/compile/20260629_173735/QM5_12786_edgelab-usdchf-eurgbp-cointegration.compile.log`
- Build-check report: `D:/QM/reports/framework/21/build_check_20260629_173751.json`

Commands:

```powershell
python framework/scripts/update_magic_resolver.py
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12786_edgelab-usdchf-eurgbp-cointegration/QM5_12786_edgelab-usdchf-eurgbp-cointegration.mq5 -Strict
python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12786_edgelab-usdchf-eurgbp-cointegration --verbose
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12786_edgelab-usdchf-eurgbp-cointegration -RepoRoot C:\QM\repo -SkipCompile
```

Results:

- `compile_one.result=PASS`, errors `0`, warnings `0`
- `validate_symbol_scope`: `BASKET_OK`, violations `0`
- `build_check.result=PASS`, failures `0`, warnings `16` existing shared-framework DWX advisories

## Q02 Enqueue

`farmctl record-build` accepted build task
`411e7313-e38d-4fe6-85ab-592be19bb290` and auto-enqueued one logical Q02 row:

| field | value |
|---|---|
| work item | `560b4011-c09f-494a-aa8e-a52830f9013e` |
| status | `pending` |
| phase | `Q02` |
| symbol | `QM5_12786_USDCHF_EURGBP_COINTEGRATION_D1` |
| setfile | `framework/EAs/QM5_12786_edgelab-usdchf-eurgbp-cointegration/sets/QM5_12786_edgelab-usdchf-eurgbp-cointegration_QM5_12786_USDCHF_EURGBP_COINTEGRATION_D1_D1_backtest.set` |
| host symbol | `USDCHF.DWX` |
| basket symbol count | `4` |
| tester currency | `USD` |
| priority payload | `priority_track=true`, `timeout_min=120` |

Duplicate guard after enqueue: exactly one pending/active Q02 row exists for
`QM5_12786`.

## Safety

- No manual MT5 backtest was launched from this session.
- Q02 execution is delegated to paced farm workers.
- No `T_Live` files were edited.
- AutoTrading was not touched.
- No `portfolio_admission`, `portfolio_kpi`, or `q08_contribution` artifacts were edited.
