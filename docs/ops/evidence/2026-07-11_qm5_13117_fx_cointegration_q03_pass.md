# QM5_13117 EURGBP/AUDJPY Cointegration Q03 PASS

Date: 2026-07-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Scope: one existing low-frequency FX cointegration basket. No live or
portfolio-gate action.

## Outcome

The repaired `QM5_13117_eurgbp-audjpy` binary passed its canonical Q03
determinism screen on the logical EURGBP/AUDJPY basket.

- Logical symbol: `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`.
- Traded legs: `EURGBP.DWX` and `AUDJPY.DWX`.
- Conversion/history dependencies: `GBPUSD.DWX` and `USDJPY.DWX`.
- Q03 work item: `dc01fd4d-0f8f-414a-a6b1-80441204fefc`.
- Parent task: `caf51649-e9fa-4db9-ba79-53632a514992`.
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
advance the highest-ranked strict sleeve with a legitimate open handoff,
`QM5_13117`, rather than create another card or EA.

The scan records DEV net Sharpe `0.4168`, OOS net Sharpe `0.8919`, OOS return
`4.4752%`, 20 OOS state changes, fixed beta `-0.12202869296345396`, and a
36.84-day half-life. The negative, small hedge and cross-bloc directional
exposure remain explicit caveats; Q03 is not portfolio admission.

## Build and Risk Preflight

The Q02-tested repaired build from commit `72237d508` was unchanged:

| Artifact | SHA256 |
|---|---|
| MQ5 | `14ddccb7ac7fe8b1c1e9cec4c6a59c7045481de99f15e1728fb38a76cfe6bcd1` |
| EX5 | `aa8ff930a973632b0dbd9b2694ccf20869f441a4fa7c9eac670339800eb199ef` |
| Basket manifest | `e8d1fcf2e2b5cd96258b4c4aef496871c54f247ad671e449a3d2f92a2d186387` |
| Backtest setfile | `c584bcf5b274ae293ebd0ea60ba9ba7ea0ca5a4afda09da2fb50423322531b83` |

The setfile build hash remained
`4d9aee1701ea38dfa655d983b803ecaba51d6d7f0cd2bef59547b53b63f085d3`.
It retained `environment=backtest`, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No strategy parameter, filter, beta, threshold, symbol,
or structural rule changed.

## Q03 Result

The repository-supported targeted worker claimed exactly the pre-existing
Q03 row on T3 while `FACTORY_OFF.flag` remained asserted. It ran two full
Model-4 passes over 2018-07-02 through 2022-12-31.

| Field | Run 1 | Run 2 |
|---|---:|---:|
| Status | OK | OK |
| Duration | 39m 19.918s | 44m 23.850s |
| Trades | 112 | 112 |
| Profit factor | 1.46 | 1.46 |
| Net profit | 4,991.52 | 4,991.52 |
| Drawdown | 3,049.81 (2.86%) | 3,049.81 (2.86%) |
| Report bytes | 267,090 | 267,090 |
| Real-tick marker | true | true |
| ONINIT failure | false | false |

Both requested runs completed on their first attempt. The aggregate reported
`deterministic=true`, zero non-OK attempts, no log bomb, and `PASS`.

Canonical evidence:
`D:/QM/reports/work_items/dc01fd4d-0f8f-414a-a6b1-80441204fefc/QM5_13117/20260711_081957/summary.json`.

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
`artifacts/qm5_13117_fx_cointegration_q03_pass_20260711.json`.
