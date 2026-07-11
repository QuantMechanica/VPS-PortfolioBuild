# QM5_13117 FX Cointegration Q05 PASS and Q06 Enqueue

**Date:** 2026-07-11

**Branch:** `agents/board-advisor`

**Scope:** one existing low-frequency EURGBP/AUDJPY D1 basket

## Outcome

`QM5_13117_eurgbp-audjpy` passed Q05 full-history robustness and now has
exactly one pending Q06 successor.

- Q05 work item: `782c0516-b649-4b3b-87e8-12d76d828b64`.
- Q05 verdict: `PASS`.
- Q06 work item: `25bf4e21-8b84-4386-9cd6-f5aa8b2f4fcf`.
- Q06 state at verification: `pending`, unclaimed, attempt 0.
- Logical symbol: `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`.
- Traded legs: `EURGBP.DWX` and `AUDJPY.DWX`.

The Q05 row was run through the worker's isolated Factory-OFF path on T1:

```powershell
python tools/strategy_farm/terminal_worker.py --terminal T1 --root D:/QM/strategy_farm --work-item-id 782c0516-b649-4b3b-87e8-12d76d828b64 --timeout-minutes 480
```

After PASS classification, the supported cascade API created one Q06 row
without dispatching it:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_13117 --phase Q06
```

## Why an Existing Basket Was Advanced

The fixed sign-aware reproduction of the OWNER-requested 66-pair scan has
exactly seven strict rows. All seven already have approved cards and basket EA
builds, so creating another card would duplicate a pair or weaken the documented
research threshold.

The two published anchors were not Q02 setup blockers:

- `QM5_12532` has Q02 PASS, Q04 PASS, and Q05 FAIL.
- `QM5_12533` has Q02 PASS and Q04 FAIL.

Neither has an open ONINIT or NO_HISTORY Q02 row. The mission fallback therefore
applied. QM5_13117 was the strict sleeve with a valid pending successor after
its repaired Q02/Q03 and Q04 PASS evidence.

The empirical lineage remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced with
`analyze_cross_asset_v3.py --include-negative-hedges`. The reputable method
source is Ernest P. Chan, *Quantitative Trading* (Wiley, 2009), Example 3.6 and
Chapter 7.

## Q05 Evidence

Q05 replayed the full available 2018-07-02 through 2024-12-31 history on Model
4 real ticks.

| Metric | Value |
|---|---:|
| Trades | 176 |
| Profit factor | 1.46 |
| Net profit | 7,593.86 |
| Drawdown money | 3,049.81 |
| Aggregate drawdown | 3.05% |
| Report drawdown | 2.86% |
| Timed out | no |
| ONINIT failure | no |
| Log bomb | no |

Canonical aggregate:

`D:/QM/reports/work_items/782c0516-b649-4b3b-87e8-12d76d828b64/QM5_13117/Q05/QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1/aggregate.json`

Canonical tester summary:

`D:/QM/reports/work_items/782c0516-b649-4b3b-87e8-12d76d828b64/QM5_13117/20260711_175115/summary.json`

The runner generated the canonical Q05 setfile at
`framework/EAs/QM5_13117_eurgbp-audjpy/sets/QM5_13117_eurgbp-audjpy_QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1_D1_q05_stress_medium.set`.
It preserves `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; its file SHA256 is
`c4b2c62130bbe42b9f193b6e1b03d6d329b6b551785fe035d011a0bec886526d`,
and its embedded canonical build hash is
`4d9aee1701ea38dfa655d983b803ecaba51d6d7f0cd2bef59547b53b63f085d3`.

## Pinned Build and Structural Contract

No strategy source, compiled binary, or basket manifest changed.

| Artifact | SHA256 |
|---|---|
| MQ5 | `14ddccb7ac7fe8b1c1e9cec4c6a59c7045481de99f15e1728fb38a76cfe6bcd1` |
| EX5 | `aa8ff930a973632b0dbd9b2694ccf20869f441a4fa7c9eac670339800eb199ef` |
| Basket manifest | `e8d1fcf2e2b5cd96258b4c4aef496871c54f247ad671e449a3d2f92a2d186387` |
| Baseline setfile | `c584bcf5b274ae293ebd0ea60ba9ba7ea0ca5a4afda09da2fb50423322531b83` |

The basket remains structural only: fixed beta, closed D1 z-score, ATR hard
stops, package cleanup, and framework Friday flattening. No ML, banned
indicator, adaptive refit, grid, martingale, pyramiding, or live setfile was
introduced.

## Queue, Capacity, and Safety

Online SQLite backups were taken before Q05 execution and Q06 enqueue:

- `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13117_q05_20260711T175108Z.sqlite`
- `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13117_q06_20260711T184818Z.sqlite`

Both backups and the live database returned `PRAGMA quick_check = ok`. The Q06
enqueue created one row and reported no skipped or requeued rows. The open-row
guard found exactly one pending Q06 and no open Q05.

The pre-existing `FACTORY_OFF.flag` remained in place. This mission launched
one T1 factory terminal, below the seven-job CPU ceiling. Q06 was not
dispatched. Two unrelated terminal jobs (T2 and T3) were observed after the Q05
run; neither was touched.

T_Live was observed only by the read-only slot scan. No AutoTrading state,
T_Live/deploy manifest, portfolio gate, `portfolio_admission`, portfolio KPI,
or Q08 contribution path was touched.

Machine-readable evidence:
`artifacts/qm5_13117_q05_pass_q06_enqueue_20260711.json`.
