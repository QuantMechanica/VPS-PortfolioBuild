# QM5_13117 FX Cointegration Q07 PASS and Q08 Enqueue

**Date:** 2026-07-12

**Branch:** `agents/board-advisor`

**Scope:** one existing low-frequency EURGBP/AUDJPY D1 basket

## Outcome

`QM5_13117_eurgbp-audjpy` passed Q07 multi-seed validation and now has
exactly one pending Q08 statistical-validation successor.

- Q07 work item: `22eb034c-ec8f-43e5-a695-3f60e5d9e4ba`.
- Q07 verdict: `PASS`.
- Q08 work item: `d9f360d4-6fa3-47ab-bddb-6a33a616f540`.
- Q08 state at verification: `pending`, unclaimed, attempt 0.
- Logical symbol: `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`.
- Traded legs: `EURGBP.DWX` and `AUDJPY.DWX`.

The already-running Factory-OFF Q07 row was monitored to its canonical
verdict on T1:

```powershell
python tools/strategy_farm/terminal_worker.py --terminal T1 --root D:/QM/strategy_farm --work-item-id 22eb034c-ec8f-43e5-a695-3f60e5d9e4ba --timeout-minutes 480
```

After PASS classification, the guarded cascade API created one Q08 row
without dispatching it:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_13117 --phase Q08
```

## Why an Existing Basket Was Advanced

The reputable strict all-sign reproduction of the OWNER-requested 66-pair
scan has seven survivors, and all seven already have approved cards and basket
EA builds. Creating another pair would duplicate an existing EA or weaken the
documented research threshold.

The two published anchors are not Q02 setup blockers:

- `QM5_12532` has Q02 PASS, Q04 PASS, and Q05 FAIL.
- `QM5_12533` has Q02 PASS and Q04 FAIL.

Neither has an open ONINIT or NO_HISTORY Q02 row. The mission's existing-card
fallback therefore applied. `QM5_13117` was the strongest strict sleeve with
valid Q02-Q06 PASS evidence and exactly one active Q07 continuation.

The empirical lineage remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced with
`analyze_cross_asset_v3.py --include-negative-hedges`. The reputable method
source is Ernest P. Chan, *Quantitative Trading* (Wiley, 2009), Example 3.6
and Chapter 7.

## Q07 Evidence

Q07 replayed the full 2018-07-02 through 2024-12-31 history on Model 4 real
ticks for the five canonical seeds on top of Q06 harsh stress.

| Seed | Trades | PF | Drawdown | Evidence |
|---:|---:|---:|---:|---|
| 42 | 176 | 1.46 | 3.05% | `20260711_203229/summary.json` |
| 17 | 176 | 1.46 | 3.05% | `20260711_212425/summary.json` |
| 99 | 176 | 1.46 | 3.05% | `20260711_221922/summary.json` |
| 7 | 176 | 1.46 | 3.05% | `20260711_231831/summary.json` |
| 2026 | 176 | 1.46 | 3.05% | `20260712_001109/summary.json` |

All five summaries are deterministic, report real-tick Model 4 execution, and
contain no ONINIT failure, history fault, log bomb, retry, or timeout. PF
variance is 0.00%, below the 20% hard limit, and the minimum seed PF is 1.46,
above the 1.0 floor.

Canonical aggregate:

`D:/QM/reports/work_items/22eb034c-ec8f-43e5-a695-3f60e5d9e4ba/QM5_13117/Q07/QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1/aggregate.json`

## Pinned Build and Risk Contract

No strategy source, compiled binary, basket manifest, or strategy parameter
changed.

| Artifact | SHA256 |
|---|---|
| MQ5 | `14ddccb7ac7fe8b1c1e9cec4c6a59c7045481de99f15e1728fb38a76cfe6bcd1` |
| EX5 | `aa8ff930a973632b0dbd9b2694ccf20869f441a4fa7c9eac670339800eb199ef` |
| Basket manifest | `e8d1fcf2e2b5cd96258b4c4aef496871c54f247ad671e449a3d2f92a2d186387` |

The five generated seed setfiles preserve `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Their runtime inputs differ only
in the canonical `qm_rng_seed`; each file's generated `build_hash` metadata
changes accordingly. No live, demo, or shadow token is present. The basket
remains structural: fixed beta, closed-D1 z-score, ATR hard stops, package
cleanup, and framework Friday flattening. No ML, banned indicator, adaptive
refit, grid, martingale, or pyramiding was introduced.

Three generated-hash header rewrites already present in the shared working
tree for the baseline, Q05, and Q06 setfiles were deliberately not staged by
this unit. The Q07-generated seed files and the new evidence are the only
repository artifacts in scope.

## Queue, Capacity, and Safety

A consistent online SQLite backup was taken before Q08 enqueue:

`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13117_q08_20260712T010640Z.sqlite`

The live and backup databases both returned `PRAGMA quick_check = ok`. The
enqueue created one Q08 row, requeued none, skipped none, and reported no
missing setfile or history dependency. A post-write guard found exactly one
open Q08 row.

`FACTORY_OFF.flag` remained in place. Q07 used one mission T1 tester; the peak
system-wide observation was two factory testers because of one unrelated T8
smoke job, below the seven-job CPU ceiling. No tester remained after Q08 was
enqueued, and Q08 was not dispatched.

No AutoTrading setting, `T_Live` path or manifest, live setfile, portfolio
gate, `portfolio_admission`, portfolio KPI, or Q08 contribution path was
touched.

Machine-readable evidence:
`artifacts/qm5_13117_q07_pass_q08_enqueue_20260712.json`.
