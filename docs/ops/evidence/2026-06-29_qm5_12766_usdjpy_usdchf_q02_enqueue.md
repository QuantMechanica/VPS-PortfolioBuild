# QM5_12766 USDJPY/USDCHF Cointegration Basket Q02 Enqueue Evidence

Date: 2026-06-29

## Scope

- EA: `QM5_12766_edgelab-usdjpy-usdchf-cointegration`
- Pair: `USDJPY.DWX` / `USDCHF.DWX`
- Logical basket symbol: `QM5_12766_USDJPY_USDCHF_COINTEGRATION_D1`
- Host symbol/timeframe: `USDJPY.DWX` / `D1`
- Portfolio scope: basket

## Selection

`QM5_12532` and `QM5_12533` were not Q02-blocked; both already had Q02 PASS
state in the local farm history. The next non-duplicate unbuilt FX
cointegration tail candidate from the 66-pair scan rerun was
`USDJPY~USDCHF`, after the existing
12532/12533/12624/12712/12723/12728/12731/12732/12735/12739/12747/12749/12751/12756/12758/12760/12762/12764/12765
baskets.

Scan rerun metrics:

| pair | DEV Sharpe | OOS net Sharpe | OOS return | OOS state changes | beta | half-life |
|---|---:|---:|---:|---:|---:|---:|
| USDJPY~USDCHF | -0.2817 | -0.0884 | -1.0114% | 15 | 0.435197 | 511.50d |

This is a very high-risk exploratory tail build; the negative DEV and OOS
metrics are intentionally documented on the card and spec for Q02+ to judge.

## Build Evidence

- Compile: PASS, 0 errors, 0 warnings.
- Compile log: `C:\QM\repo\framework\build\compile\20260629_055117\QM5_12766_edgelab-usdjpy-usdchf-cointegration.compile.log`
- Build check: PASS, 0 failures, 16 existing shared-framework DWX advisory warnings.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260629_055135.json`
- Spec validation: PASS.
- Card schema lint: OK.
- Symbol scope validation: `BASKET_OK`.
- `.mq5` SHA256: `fd2bc6ab4b8a0aa1cc31cb9d8d056d8669931bb6850268a5540253a7a70dbb33`
- `.ex5` SHA256: `2a3f1830bf1947b87e35ebe99d051d686b2dd30adf4a2f67773e51ec47c0985e`

## Q02 Queue Evidence

- Build task: `2e99cc4b-453a-4b75-84a7-81ea844c8ff0`
- Q02 work item: `c097d38d-f428-4c8b-a90c-104d1e072c0d`
- Q02 status after enqueue: pending
- Q02 row shape: one logical-basket row for
  `QM5_12766_USDJPY_USDCHF_COINTEGRATION_D1`; no per-leg Q02 fanout.
- Setfile:
  `C:\QM\repo\framework\EAs\QM5_12766_edgelab-usdjpy-usdchf-cointegration\sets\QM5_12766_edgelab-usdjpy-usdchf-cointegration_QM5_12766_USDJPY_USDCHF_COINTEGRATION_D1_D1_backtest.set`
- Backtest risk settings: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Safety

- No `T_Live` files were edited.
- AutoTrading was not touched.
- `portfolio_admission`, `portfolio_kpi`, and `q08_contribution` artifacts were
  not edited.
- No manual MT5 backtest was launched from this session; Q02 remains queued for
  the paced farm.
