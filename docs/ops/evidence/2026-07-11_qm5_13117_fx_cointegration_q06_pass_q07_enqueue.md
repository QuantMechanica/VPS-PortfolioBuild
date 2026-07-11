# QM5_13117 FX Cointegration Q06 PASS and Q07 Enqueue

**Date:** 2026-07-11

**Branch:** `agents/board-advisor`

**Scope:** one existing low-frequency EURGBP/AUDJPY D1 basket

## Outcome

`QM5_13117_eurgbp-audjpy` passed Q06 harsh stress and now has exactly one
pending Q07 successor.

- Q06 work item: `25bf4e21-8b84-4386-9cd6-f5aa8b2f4fcf`.
- Q06 verdict: `PASS`.
- Q07 work item: `22eb034c-ec8f-43e5-a695-3f60e5d9e4ba`.
- Q07 state at verification: `pending`, unclaimed, attempt 0.
- Logical symbol: `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`.
- Traded legs: `EURGBP.DWX` and `AUDJPY.DWX`.

Q06 ran through the worker's isolated Factory-OFF path on T1:

```powershell
python tools/strategy_farm/terminal_worker.py --terminal T1 --root D:/QM/strategy_farm --work-item-id 25bf4e21-8b84-4386-9cd6-f5aa8b2f4fcf --timeout-minutes 480
```

After canonical PASS classification, the supported cascade API created one
Q07 row without dispatching it:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_13117 --phase Q07
```

## Why an Existing Basket Was Advanced

The reputable strict all-sign reproduction of the OWNER-requested 66-pair scan
is already fully carded and built. Creating another pair would either duplicate
an existing EA or weaken the documented research threshold. The two published
anchors are not Q02 setup blockers:

- `QM5_12532` has Q02 PASS, Q04 PASS, and Q05 FAIL.
- `QM5_12533` has Q02 PASS and Q04 FAIL.

Neither has an open ONINIT or NO_HISTORY Q02 row. The mission's existing-card
fallback therefore applied. QM5_13117 is the strict sleeve with valid Q02-Q05
PASS evidence and was the one pending non-duplicate continuation.

The empirical lineage remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced with
`analyze_cross_asset_v3.py --include-negative-hedges`. The reputable method
source is Ernest P. Chan, *Quantitative Trading* (Wiley, 2009), Example 3.6 and
Chapter 7.

## Q06 Evidence

Q06 replayed the full available 2018-07-02 through 2024-12-31 history on Model
4 real ticks with harsh stress and a 10% rejection probability.

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

`D:/QM/reports/work_items/25bf4e21-8b84-4386-9cd6-f5aa8b2f4fcf/QM5_13117/Q06/QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1/aggregate.json`

Canonical tester summary:

`D:/QM/reports/work_items/25bf4e21-8b84-4386-9cd6-f5aa8b2f4fcf/QM5_13117/20260711_191737/summary.json`

The runner generated the canonical Q06 setfile at
`framework/EAs/QM5_13117_eurgbp-audjpy/sets/QM5_13117_eurgbp-audjpy_QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1_D1_q06_stress_harsh.set`.
It preserves `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; its file SHA256 is
`9bed0b71a1664da2e3cab90e3521e6cc2fcf02a71b36734b0600f55d5b55b71e`.
Its embedded canonical build hash is
`4d9aee1701ea38dfa655d983b803ecaba51d6d7f0cd2bef59547b53b63f085d3`.

## Pinned Build and Structural Contract

No strategy source, compiled binary, basket manifest, or baseline setfile
changed.

| Artifact | SHA256 |
|---|---|
| MQ5 | `14ddccb7ac7fe8b1c1e9cec4c6a59c7045481de99f15e1728fb38a76cfe6bcd1` |
| EX5 | `aa8ff930a973632b0dbd9b2694ccf20869f441a4fa7c9eac670339800eb199ef` |
| Basket manifest | `e8d1fcf2e2b5cd96258b4c4aef496871c54f247ad671e449a3d2f92a2d186387` |
| Baseline setfile | `c2bb0b0d01f62fe7406bd3cc90dd1a5621b2814b3501213fad8b44377262cb6b` |

The basket remains structural only: fixed beta, closed D1 z-score, ATR hard
stops, package cleanup, and framework Friday flattening. No ML, banned
indicator, adaptive refit, grid, martingale, pyramiding, or live setfile was
introduced.

## Queue, Capacity, and Safety

Online SQLite backups were taken before Q06 execution and Q07 enqueue:

- `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13117_q06_20260711T191728Z.sqlite`
- `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13117_q07_20260711T200217Z.sqlite`

Both backups and the live database returned `PRAGMA quick_check = ok`. The Q07
enqueue created one row and reported no skipped or requeued rows. The open-row
guard found exactly one pending Q07 and no open Q06.

The pre-existing `FACTORY_OFF.flag` remained in place. The mission observed
three pre-existing active database rows and zero factory MT5 processes, then
launched only T1, below the seven-job CPU ceiling. T1 exited after the result;
Q07 was not dispatched.

T_Live was observed only by the read-only process scan. No AutoTrading state,
T_Live/deploy manifest, portfolio gate, `portfolio_admission`, portfolio KPI,
or Q08 contribution path was touched.

Machine-readable evidence:
`artifacts/qm5_13117_q06_pass_q07_enqueue_20260711.json`.
