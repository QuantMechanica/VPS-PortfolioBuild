# QM5_1058 FX Pair Q07 Timeout Requeue

**Date:** 2026-07-12

**Branch:** `agents/board-advisor`

**Scope:** one existing low-frequency EURUSD/GBPUSD D1 basket

## Outcome

The existing `QM5_1058_gatev-fx-pairs-zscore` EURUSD/GBPUSD logical basket
was requeued at Q07 after an infrastructure-only seed timeout. The operation
reused the sole existing work item; it did not create a duplicate or launch an
MT5 tester.

- Work item: `82c0189f-f4a7-4e3f-ac76-79b38037bacb`.
- Logical symbol: `QM5_1058_EURUSD_GBPUSD_GGR_D1`.
- Prior state: `done / INFRA_FAIL`, attempt 1.
- New state: `pending`, unclaimed, attempt 0, no verdict.
- Queue result: `created=[]`, one in-place `requeued` row, `skipped=[]`.
- Paced priority: `queued_top[0]` at verification.

## Why An Existing Basket Was Advanced

The reputable sign-aware reproduction of the OWNER-requested 66-pair scan has
seven strict rows, and all seven already have approved cards and basket EA
builds. Creating another pair would duplicate an existing build or weaken the
documented DEV/OOS threshold.

The two named anchors are not Q02 setup blockers:

- `QM5_12532` AUDUSD/NZDUSD has Q02 PASS and Q04 PASS followed by Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY has Q02 PASS followed by Q04 FAIL.

`QM5_13117` already has one non-duplicate Q08 successor pending. The mission's
existing-card fallback therefore selected `QM5_1058`, which has a clean
Q02-through-Q06 PASS chain and no competing open Q07 row.

## Structural And Source Contract

The approved farm card cites Gatev, Goetzmann, and Rouwenhorst (2006),
"Pairs Trading: Performance of a Relative-Value Arbitrage Rule," *Review of
Financial Studies* 19(3), 797-827. Its R1-R4 fields are PASS. The implementation
uses rolling OLS and fixed z-score thresholds as ordinary deterministic
statistics; it contains no ML, banned indicator, grid, martingale, or
pyramiding component.

The selected sleeve is deliberately low-frequency:

- Host: `EURUSD.DWX`, D1.
- Traded pair: `EURUSD.DWX` / `GBPUSD.DWX`.
- Logical basket: `QM5_1058_EURUSD_GBPUSD_GGR_D1`.
- Expected frequency in the approved card: approximately two trades per year
  per symbol.
- Canonical setfile: `environment=backtest`, `risk_mode=FIXED`,
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- `basket_manifest.json` declares the logical host, both traded legs, the
  auxiliary AUDUSD/NZDUSD warmup histories, USD tester currency, and USD
  100,000 tester deposit.

No EA source, binary, manifest, strategy parameter, or setfile was changed by
this unit.

## Prior Q07 Infrastructure Failure

Q02 through Q06 are canonical PASS rows:

| Phase | Work item | Verdict |
|---|---|---|
| Q02 | `eeeb44cc-0cc3-4127-8107-18df9f96fa3f` | PASS |
| Q03 | `fe14ff78-4fc7-467b-a54f-80c82d3887a8` | PASS |
| Q04 | `cff1ca51-2d6f-4204-8fac-804ded4a4864` | PASS |
| Q05 | `93bda5b4-793e-4c18-a7ca-677a9f7d146b` | PASS |
| Q06 | `25c0e5ba-1456-4e74-8fb1-20a729ad4cd3` | PASS |

The prior Q07 aggregate was `INVALID`, classified in the database as
`INFRA_FAIL`. Seed 42 exhausted the 5,400-second runner budget and produced
`INCOMPLETE_RUNS,TIMEOUT`; the remaining seed processes returned invalid exit
evidence after that terminal failure. No strategy FAIL was recorded.

The old isolated report root was preserved at:

`D:/QM/reports/work_items/82c0189f-f4a7-4e3f-ac76-79b38037bacb.requeued_20260712T0904540000`

## Guarded Queue Action

A consistent online SQLite backup was taken before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_1058_q07_requeue_20260712T090448Z.sqlite`

Both the source and backup returned `PRAGMA quick_check = ok`. The canonical
cascade command then requeued the existing row:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_1058 --phase Q07
```

A guarded `BEGIN IMMEDIATE` update, conditional on the row being pending and
unclaimed, added only runtime controls:

- `q07_seed_timeout_sec=7200`: bounded two-hour budget per canonical seed.
- `timeout_min=660`: outer worker budget for five seeds plus headroom.
- `avoid_terminals=["T1"]` and `skip_terminals=["T1"]`: do not repeat the
  terminal that produced the timeout.
- `priority_track=true` and `dispatch_mode=paced_fleet_only`.

The live command builder resolves those controls to the D1 host, the logical
basket, and `--timeout-sec 7200`. Post-write guards found exactly one open Q07
row for this EA/phase/logical-symbol tuple, and the live database again returned
`PRAGMA quick_check = ok`.

## Validation

- `CascadePromotionTests.test_q07_runner_cmd_keeps_basket_logical_symbol`:
  PASS (1 test).
- `framework.scripts.tests.test_q05_q07_verdicts`: PASS (23 tests).
- Live command construction: PASS for host `EURUSD.DWX`, logical symbol,
  baseline setfile, terminal routing, and 7,200-second seed timeout.
- Basket manifest JSON parse and canonical risk-set inspection: PASS.
- Static forbidden-term scan of the EA source and spec: no ML library,
  grid, or martingale match.
- Compiled `.ex5` remains present (306,970 bytes).

## Capacity And Safety

`FACTORY_OFF.flag` remained present. The database had three pre-existing active
rows and 3,688 pending rows after the requeue. The process scan observed one
unrelated T4 MetaTester, below the seven-tester ceiling. No worker, terminal,
smoke test, backtest, or dispatch command was started for `QM5_1058`.

An already-running `T_Live` process was observed and left untouched. No
AutoTrading setting, live/deploy manifest, live setfile, portfolio gate,
`portfolio_admission`, portfolio KPI, or Q08-contribution path was touched.
Existing unrelated dirty worktree files, including generated QM5_1058 seed
setfiles, were not staged.

Machine-readable evidence:
`artifacts/qm5_1058_fx_q07_timeout_requeue_20260712T090532Z.json`.
