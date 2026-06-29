# QM5_12768 USDJPY/EURJPY Cointegration Basket Q02 Enqueue Evidence

Date: 2026-06-29

## Scope

- EA: `QM5_12768_edgelab-usdjpy-eurjpy-cointegration`
- Pair: `USDJPY.DWX` / `EURJPY.DWX`
- Logical basket symbol: `QM5_12768_USDJPY_EURJPY_COINTEGRATION_D1`
- Host symbol/timeframe: `USDJPY.DWX` / `D1`
- Portfolio scope: basket

## Selection

`QM5_12532` and `QM5_12533` were checked first. Both already have
logical-basket Q02 PASS rows in the local farm history, so there was no active
ONINIT or NO_HISTORY repair to prefer. The next non-duplicate unbuilt FX
cointegration tail candidate from the 66-pair scan rerun was `USDJPY~EURJPY`,
after the existing
12532/12533/12624/12712/12723/12728/12731/12732/12735/12739/12747/12749/12751/12756/12758/12760/12762/12764/12765/12766
baskets.

Scan rerun metrics:

| pair | DEV Sharpe | OOS net Sharpe | OOS return | OOS state changes | beta | half-life |
|---|---:|---:|---:|---:|---:|---:|
| USDJPY~EURJPY | 0.4669 | -0.1174 | -1.0184% | 17 | 1.236712 | 137.40d |

This is a very high-risk exploratory tail build. The positive DEV but negative
OOS metric profile is intentionally documented on the card and spec for Q02+
to judge.

## Build Evidence

- Compile: PASS, 0 errors, 0 warnings.
- Compile log: `C:\QM\repo\framework\build\compile\20260629_065010\QM5_12768_edgelab-usdjpy-eurjpy-cointegration.compile.log`
- Build check: PASS, 0 failures, 16 existing shared-framework DWX advisory warnings.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260629_065118.json`
- Spec validation: PASS.
- Card schema lint: OK.
- Symbol scope validation: `BASKET_OK`.
- `.mq5` SHA256: `10cce9169a9422fd07ada2fa769d19bfb6d279fd536d8585436d281b824af05a`
- `.ex5` SHA256: `78d1d5ab9d4cf59e116d6982818c795be3a903331091a2ef33a0f3fc5241149c`

## Q02 Queue Evidence

- Build task: `50b8f15b-11ff-4cf3-ae31-4f8534ce5a82`
- Q02 work item: `93909a80-8ce6-4e95-be28-889f8dc17a7d`
- Q02 status after enqueue: pending
- Q02 row shape: one logical-basket row for
  `QM5_12768_USDJPY_EURJPY_COINTEGRATION_D1`; no per-leg Q02 fanout.
- Setfile:
  `C:\QM\repo\framework\EAs\QM5_12768_edgelab-usdjpy-eurjpy-cointegration\sets\QM5_12768_edgelab-usdjpy-eurjpy-cointegration_QM5_12768_USDJPY_EURJPY_COINTEGRATION_D1_D1_backtest.set`
- Backtest risk settings: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Safety

- No `T_Live` files were edited.
- AutoTrading was not touched.
- `portfolio_admission`, `portfolio_kpi`, and `q08_contribution` artifacts were
  not edited.
- No manual MT5 backtest was launched from this session; Q02 remains queued for
  the paced farm.
