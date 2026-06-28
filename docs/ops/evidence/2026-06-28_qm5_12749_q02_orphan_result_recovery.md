# QM5_12749 Q02 Orphan Result Recovery - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

The original strict FX cointegration baskets `QM5_12532` and `QM5_12533` are no
longer Q02-blocked; both have logical-basket Q02 PASS evidence and have already
moved to later gates. The next exploratory EdgeLab baskets through `QM5_12751`
are already built, so this pass advanced an existing forex basket instead of
creating a duplicate card/build.

Chosen basket: `QM5_12749` NZDUSD/AUDJPY cointegration,
`QM5_12749_NZDUSD_AUDJPY_COINTEGRATION_D1`.

## Recovery

Work item `ed3dada9-d657-4b85-b5ba-28d2c64bf788` was still `pending`, but its
worker log and report tree already contained a completed T2 Q02 summary:

`D:/QM/reports/work_items/ed3dada9-d657-4b85-b5ba-28d2c64bf788/QM5_12749/20260628_155201/summary.json`

The existing summary classified as:

| Field | Value |
|---|---|
| Result | `FAIL` |
| Reason | `MIN_TRADES_NOT_MET` |
| Terminal | `T2` |
| Host symbol | `NZDUSD.DWX` |
| Logical symbol | `QM5_12749_NZDUSD_AUDJPY_COINTEGRATION_D1` |
| Trades | `0` |
| Q02 trade floor | `35` |

Using the worker's normal `terminal_worker._finish_work_item()` classifier, I
recovered the existing summary into the farm DB:

| Field | Value |
|---|---|
| Status | `done` |
| Verdict | `FAIL` |
| Evidence provenance | `real_mt5` |
| Verdict taxonomy | `strategy` |
| Evidence path | summary JSON above |

No duplicate Q02 row was inserted and no manual MT5 run was launched.

## Validation

- `build_check.ps1 -EALabel QM5_12749_edgelab-nzdusd-audjpy-cointegration -SkipCompile`: `PASS`, 0 failures, 16 existing framework advisory warnings.
- `farmctl work-items --ea QM5_12749`: one Q02 row, `done/FAIL`, evidence path set to the recovered summary.
- Refreshed `D:/QM/reports/pipeline/QM5_12749/Q02/report.csv` with the recovered `FAIL`.
