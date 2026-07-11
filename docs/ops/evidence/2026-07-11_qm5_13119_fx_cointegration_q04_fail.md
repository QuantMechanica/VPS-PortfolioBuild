# QM5_13119 USDJPY/EURAUD Cointegration Q04 FAIL

Date: 2026-07-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Scope: one existing low-frequency FX cointegration basket. No live,
deployment, or portfolio-gate action.

## Outcome

`QM5_13119_usdjpy-euraud` completed its unique Q04 walk-forward row and
received a strategy `FAIL`:

- Work item: `addea337-31f5-4267-b002-1281eaf9f94c`.
- Logical symbol: `QM5_13119_USDJPY_EURAUD_COINTEGRATION_D1`.
- Traded legs: `USDJPY.DWX` and `EURAUD.DWX`.
- Verdict reason: `F1:pf_net=1.437;F2:pf_net=0.872`.
- Canonical aggregate:
  `D:/QM/reports/work_items/addea337-31f5-4267-b002-1281eaf9f94c/QM5_13119/Q04/QM5_13119_USDJPY_EURAUD_COINTEGRATION_D1/aggregate.json`.

Both folds were valid real-tick tests with enough trades and no ONINIT,
NO_HISTORY, report, or log-bomb failure. The second fold's net PF below 1.0 is
therefore a strategy result, not an infrastructure classification. No Q05 row
was created.

## Selection and De-duplication

The source-qualified frontier is exhausted. The positive-hedge 66-pair scan
has two survivors, both already built and beyond Q02:

- `QM5_12532` AUDUSD/NZDUSD: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY: Q02 PASS, Q04 FAIL.

Neither anchor has an open ONINIT or NO_HISTORY Q02 blocker. The sign-aware
reproduction has seven strict rows and all seven have approved cards and EA
builds. Creating an eighth pair would duplicate the built frontier or weaken
the documented threshold. The mission fallback therefore applied: advance
`QM5_13119`, the final strict row, through its already pending Q04 gate.

Its empirical lineage remains the OWNER-requested scan at
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced with
`analyze_cross_asset_v3.py --include-negative-hedges`. The reputable method
source remains Ernest P. Chan, *Quantitative Trading* (Wiley, 2009), Example
3.6 and Chapter 7.

## Q04 Result

The repository-supported targeted worker ran the one pre-existing row on T1
while `FACTORY_OFF.flag` remained asserted:

```powershell
python tools/strategy_farm/terminal_worker.py --terminal T1 --work-item-id addea337-31f5-4267-b002-1281eaf9f94c --timeout-minutes 180
```

| Fold | OOS year | Trades | Report PF | Net PF | Net profit | Drawdown | Setup |
|---|---:|---:|---:|---:|---:|---:|---|
| F1 | 2023 | 40 | 1.44 | 1.4372 | +1,723.00 | 2,006.82 (1.94%) | OK |
| F2 | 2024 | 30 | 0.87 | 0.8719 | -558.24 | 2,234.34 (2.20%) | OK |

The gate used the `worst_case_dxz_ftmo_notional (DL-073)` commission model.
The tester history scope covered both traded legs and the two manifest-declared
conversion dependencies, `AUDUSD.DWX` and `EURUSD.DWX`.

## Build and Risk Integrity

The repaired Q02/Q03-tested build was unchanged:

| Artifact | SHA256 |
|---|---|
| MQ5 | `7aacf8d12b90d3838c70d18984556df5060864c182281e31a1bafbfac6a947f1` |
| EX5 | `a3988df814790762be229b84e3483ae460128f6e6a056a673a74edd544834a5e` |
| Basket manifest | `718150ded145287458aed5f0376ca5fe22377949cc00f2941f1a1604f59f6e90` |
| Backtest setfile | `5dfdda38d1a2edf21cb78ab4174c5c75300160d87f91d8271e4673c384b008c5` |

The setfile retained `environment=backtest`, `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No beta, threshold, symbol, filter,
ML component, banned indicator, grid, martingale, or adaptive rule changed.

All three canonical card copies now record the repaired Q02 PASS, deterministic
Q03 PASS, and terminal Q04 FAIL instead of the stale Q02-pending state.

## Capacity and Safety

A consistent SQLite backup was taken before the targeted worker claimed the
row. The backup and post-run live database both passed `PRAGMA quick_check`.
Exactly one matching Q04 row exists and none remains open.

The run used one factory terminal, below the seven-job CPU ceiling. T1 and its
tester agent exited after classification; factory terminal/tester count is now
zero and `FACTORY_OFF.flag` remains present.

No `T_Live` path, AutoTrading state, live/deploy manifest, portfolio gate,
`portfolio_admission`, portfolio KPI, or Q08 contribution path was changed.

Machine-readable evidence:
`artifacts/qm5_13119_fx_cointegration_q04_fail_20260711.json`.
