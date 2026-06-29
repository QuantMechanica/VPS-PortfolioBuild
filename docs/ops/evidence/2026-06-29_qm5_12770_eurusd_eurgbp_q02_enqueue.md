# QM5_12770 EURUSD/EURGBP Cointegration Basket Q02 Enqueue Evidence

Date: 2026-06-29

## Scope

- EA: `QM5_12770_edgelab-eurusd-eurgbp-cointegration`
- Pair: `EURUSD.DWX` / `EURGBP.DWX`
- Logical basket symbol: `QM5_12770_EURUSD_EURGBP_COINTEGRATION_D1`
- Host symbol/timeframe: `EURUSD.DWX` / `D1`
- Portfolio scope: basket

## Selection

`QM5_12532` and `QM5_12533` were checked first. Both already have logical-basket
Q02 PASS rows in `D:/QM/strategy_farm/state/farm_state.sqlite`, so there was no
active ONINIT or NO_HISTORY repair to prefer. The next non-duplicate unbuilt FX
cointegration tail candidate from the 66-pair scan rerun was `EURUSD~EURGBP`,
after the existing
12532/12533/12624/12712/12723/12728/12731/12732/12735/12739/12747/12749/12751/12756/12758/12760/12762/12764/12765/12766/12768
baskets.

Scan rerun metrics:

| pair | DEV Sharpe | OOS net Sharpe | OOS return | OOS state changes | beta | half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD~EURGBP | -0.0833 | -0.1761 | -1.4936% | 17 | 0.601215 | 149.27d |

This is a very high-risk exploratory tail build. Both DEV and OOS Sharpe are
negative, so this is not a survivor claim; Q02+ must reject it if real tester
costs confirm the scan weakness.

## Build Evidence

- Compile: PASS, 0 errors, 0 warnings.
- Compile log: `C:\QM\repo\framework\build\compile\20260629_085420\QM5_12770_edgelab-eurusd-eurgbp-cointegration.compile.log`
- Build check: PASS, 0 failures, 16 existing shared-framework DWX advisory warnings.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260629_085433.json`
- Spec validation: PASS.
- Symbol scope validation: `BASKET_OK`.
- `.mq5` SHA256: `7cc6877882eab4e2e67f5de43948626415588ff28898e16187761f660c9c3290`
- `.ex5` SHA256: `01ffd5eec6cf3c4748e59eee453cb42591f992d396b269eb5618a6af344b5d11`

## Q02 Queue Evidence

- Build task: `dd64c930-550b-41e6-9d3a-807b184f9cb8`
- Q02 work item: `118ab93b-8df8-47a2-85d1-79b4ab0e1eaa`
- Q02 status after enqueue: pending
- Q02 row shape: one logical-basket row for
  `QM5_12770_EURUSD_EURGBP_COINTEGRATION_D1`; no per-leg Q02 fanout.
- Setfile:
  `C:\QM\repo\framework\EAs\QM5_12770_edgelab-eurusd-eurgbp-cointegration\sets\QM5_12770_edgelab-eurusd-eurgbp-cointegration_QM5_12770_EURUSD_EURGBP_COINTEGRATION_D1_D1_backtest.set`
- Backtest risk settings: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Payload repair backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12770_priority_payload_20260629_085713Z.sqlite`
- Duplicate guard after payload repair: exactly one pending/active logical Q02
  row for this EA/symbol.

## Safety

- No `T_Live` files were edited.
- AutoTrading was not touched.
- `portfolio_admission`, `portfolio_kpi`, and `q08_contribution` artifacts were
  not edited.
- No manual MT5 backtest was launched from this session; Q02 remains queued for
  the paced farm.
