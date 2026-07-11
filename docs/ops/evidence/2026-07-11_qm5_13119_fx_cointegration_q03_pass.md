# QM5_13119 USDJPY/EURAUD Cointegration Q03 PASS

Date: 2026-07-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Scope: one existing low-frequency FX cointegration basket. No live or
portfolio-gate action.

## Outcome

The repaired `QM5_13119_usdjpy-euraud` binary passed its canonical Q03
determinism screen on the logical USDJPY/EURAUD basket.

- Logical symbol: `QM5_13119_USDJPY_EURAUD_COINTEGRATION_D1`.
- Traded legs: `USDJPY.DWX` and `EURAUD.DWX`.
- Conversion/history dependencies: `AUDUSD.DWX` and `EURUSD.DWX`.
- Q03 work item: `e786ef7d-aaf8-4813-aae1-1e2f34f62ccb`.
- Parent task: `490a1cbf-1d27-4109-b324-158e44c18500`.
- Final state: work item `done/PASS`; parent `done` with the logical basket
  listed as its sole surviving symbol.

## Selection and De-duplication

The positive-hedge 66-pair scan has two hard survivors, both already built
and past Q02:

- `QM5_12532` AUDUSD/NZDUSD: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY: Q02 PASS, Q04 FAIL.

Neither anchor has an open ONINIT or NO_HISTORY Q02 blocker. Reproducing the
OWNER-requested sign-aware scan yielded exactly seven strict rows:

| Rank | Pair | EA | Built |
|---:|---|---|---|
| 1 | GBPUSD/USDCAD | `QM5_12978` | yes |
| 2 | EURJPY/GBPJPY | `QM5_12533` | yes |
| 3 | AUDUSD/NZDUSD | `QM5_12532` | yes |
| 4 | USDCAD/NZDUSD | `QM5_13003` | yes |
| 5 | AUDUSD/EURGBP | `QM5_13106` | yes |
| 6 | EURGBP/AUDJPY | `QM5_13117` | yes |
| 7 | USDJPY/EURAUD | `QM5_13119` | yes |

The command was:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

Creating another pair would duplicate the built frontier or weaken the
documented research threshold. The mission fallback therefore applied:
advance the final strict sleeve with a legitimate open handoff, `QM5_13119`,
rather than create another card or EA.

The scan records DEV net Sharpe `0.5059`, OOS net Sharpe `0.8837`, OOS return
`16.0148%`, 23 OOS state changes, fixed beta `-1.4182482311707278`, and a
77.46-day half-life. The negative beta puts both traded legs in the same
direction, so regression neutrality does not imply currency, carry,
directional, or portfolio neutrality. Q03 is not portfolio admission.

## Build and Risk Preflight

The Q02-tested repaired build from commit `b92667599` was unchanged:

| Artifact | SHA256 |
|---|---|
| MQ5 | `7aacf8d12b90d3838c70d18984556df5060864c182281e31a1bafbfac6a947f1` |
| EX5 | `a3988df814790762be229b84e3483ae460128f6e6a056a673a74edd544834a5e` |
| Basket manifest | `718150ded145287458aed5f0376ca5fe22377949cc00f2941f1a1604f59f6e90` |
| Q03 source/T3 setfile | `5dfdda38d1a2edf21cb78ab4174c5c75300160d87f91d8271e4673c384b008c5` |
| Prior Q02 T2 deployed setfile | `b4ad75aa7e65a22e57e384d1a7841880bac1bddc317d5c193bacc747be4750c4` |

The two setfile byte hashes differ only because the prior T2 profile copy and
the repository/T3 copy use different line endings; line-wise comparison found
zero text differences. Both carry build hash
`f081167251a3130fe084abde2191f61cd658e378033f19b61c9d6fa1f8f1941d`
and retain `environment=backtest`, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No strategy parameter, filter, beta, threshold, symbol,
or structural rule changed.

## Q03 Result

The repository-supported targeted worker claimed exactly the pre-existing
Q03 row on T3 while `FACTORY_OFF.flag` remained asserted. It ran two full
Model-4 passes over 2018-07-02 through 2022-12-31.

| Field | Run 1 | Run 2 |
|---|---:|---:|
| Status | OK | OK |
| Approx. elapsed | 30m 45.881s | 28m 32.438s |
| Trades | 136 | 136 |
| Profit factor | 1.06 | 1.06 |
| Net profit | 966.39 | 966.39 |
| Drawdown | 3,033.82 (2.92%) | 3,033.82 (2.92%) |
| Report bytes | 318,030 | 318,030 |
| Real-tick marker | true | true |
| ONINIT failure | false | false |

Both requested runs completed on their first attempt. The aggregate reported
`deterministic=true`, zero non-OK attempts, no log bomb, and `PASS`.

Canonical evidence:
`D:/QM/reports/work_items/e786ef7d-aaf8-4813-aae1-1e2f34f62ccb/QM5_13119/20260711_103353/summary.json`.

The live SQLite database passed `PRAGMA quick_check`. Exactly one Q03 PASS row
exists for the logical basket, no Q03 row remains open, and no duplicate Q04
row was created. Normal pipeline orchestration can create the Q04 handoff when
the globally paused factory resumes.

## Capacity and Safety

The observed maximum was three factory terminals including T3, below the
seven-job CPU ceiling. T3 exited cleanly after classification; this mission
did not launch a second backtest. `FACTORY_OFF.flag` remained present.

No `T_Live` path, AutoTrading state, deploy/live manifest, portfolio gate,
`portfolio_admission`, portfolio KPI, or Q08 contribution path was changed.
No ML, banned indicator, grid, martingale, pyramiding, or adaptive-refit logic
was introduced.

Machine-readable evidence:
`artifacts/qm5_13119_fx_cointegration_q03_pass_20260711.json`.
