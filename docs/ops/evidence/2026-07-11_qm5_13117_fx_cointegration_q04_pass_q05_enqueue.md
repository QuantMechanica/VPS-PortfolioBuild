# QM5_13117 FX Cointegration Q04 PASS and Q05 Enqueue

**Date:** 2026-07-11
**Branch:** `agents/board-advisor`
**Scope:** one existing low-frequency EURGBP/AUDJPY D1 basket

## Outcome

`QM5_13117_eurgbp-audjpy` passed Q04 walk-forward and now has exactly one
pending Q05 successor.

- Q04 work item: `82736cf7-2124-4e92-a54d-3102247f73ef`.
- Q04 verdict: `PASS`.
- Q05 work item: `782c0516-b649-4b3b-87e8-12d76d828b64`.
- Q05 state at verification: `pending`, unclaimed, attempt 0.
- Logical symbol: `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`.
- Traded legs: `EURGBP.DWX` and `AUDJPY.DWX`.

The Q04 row was run through the worker's isolated factory-off path on T1:

```powershell
python tools/strategy_farm/terminal_worker.py --terminal T1 --work-item-id 82736cf7-2124-4e92-a54d-3102247f73ef --timeout-minutes 180
```

The supported cascade API then created the Q05 successor without dispatching
it:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_13117 --phase Q05
```

## Why This Existing Basket Was Advanced

The fixed sign-aware reproduction of the OWNER-requested 66-pair scan has
exactly seven strict survivors. All seven already have approved cards and EA
builds, so creating another card would either duplicate a build or weaken the
documented research threshold.

The two anchors were not Q02 setup blockers:

- `QM5_12532` has Q02 PASS, Q04 PASS, and Q05 FAIL.
- `QM5_12533` has Q02 PASS and Q04 FAIL.

Neither has an open ONINIT or NO_HISTORY Q02 row. The mission fallback therefore
applied. QM5_13117 was the oldest unique pending successor after repaired Q02
and Q03 passes.

The empirical lineage remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced with
`analyze_cross_asset_v3.py --include-negative-hedges`. The approved method
source is Ernest P. Chan, *Quantitative Trading* (Wiley, 2009), Example 3.6 and
Chapter 7.

## Q04 Evidence

Q04 used the repository's worst-case DXZ/FTMO notional commission model. Both
real-tick OOS folds passed:

| Fold | OOS year | Trades | Report PF | Net PF | Net profit | Drawdown |
|---|---:|---:|---:|---:|---:|---:|
| F1 | 2023 | 30 | 1.41 | 1.4099 | 1,116.07 | 1.91% |
| F2 | 2024 | 34 | 1.53 | 1.5400 | 1,486.28 | 1.66% |

Both fold summaries recorded Model 4 real ticks, deterministic execution,
non-empty reports, and no ONINIT, history, or log-bomb failure. Canonical
aggregate:

`D:/QM/reports/work_items/82736cf7-2124-4e92-a54d-3102247f73ef/QM5_13117/Q04/QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1/aggregate.json`

## Pinned Build and Risk Contract

No strategy or build artifact changed. The Q03/Q04-tested files remain pinned:

| Artifact | SHA256 |
|---|---|
| MQ5 | `14ddccb7ac7fe8b1c1e9cec4c6a59c7045481de99f15e1728fb38a76cfe6bcd1` |
| EX5 | `aa8ff930a973632b0dbd9b2694ccf20869f441a4fa7c9eac670339800eb199ef` |
| Basket manifest | `e8d1fcf2e2b5cd96258b4c4aef496871c54f247ad671e449a3d2f92a2d186387` |
| Backtest setfile | `c584bcf5b274ae293ebd0ea60ba9ba7ea0ca5a4afda09da2fb50423322531b83` |

The logical setfile remains `environment=backtest`, `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No ML, banned indicator, adaptive
refit, grid, martingale, pyramiding, or live setfile was introduced.

## Queue and Capacity Safety

An online SQLite backup was taken before Q05 enqueue:

`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13117_q05_20260711T150545Z.sqlite`

The live and backup databases both returned `PRAGMA quick_check = ok`. The
enqueue created one Q05 row and reported no skipped or requeued rows.

`FACTORY_OFF.flag` remained in place. Q04 used one T1 slot, below the seven-job
CPU ceiling, and no factory terminal remained after the run. Q05 was not
dispatched.

T_Live was only observed by the read-only slot scan. No AutoTrading state,
T_Live/deploy manifest, portfolio gate, `portfolio_admission`, portfolio KPI,
or Q08 contribution path was touched.

Machine-readable evidence:
`artifacts/qm5_13117_q04_pass_q05_enqueue_20260711.json`.
