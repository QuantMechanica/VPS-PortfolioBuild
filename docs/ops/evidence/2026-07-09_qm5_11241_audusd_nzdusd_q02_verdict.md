# QM5_11241 AUDUSD/NZDUSD Q02 Verdict

Date: 2026-07-09 local / 2026-07-08 UTC
Branch: `agents/board-advisor`
Operator: Codex

## Mission Decision

No unbuilt approved FX cointegration card remained after the strict and extended
scan inventory check. The strict scan still names only `QM5_12533`
EURJPY/GBPJPY and `QM5_12532` AUDUSD/NZDUSD as certified 66-pair survivors; both
are already built and no longer blocked at Q02:

| EA | Pair | Current state checked |
|---|---|---|
| `QM5_12532` | AUDUSD.DWX / NZDUSD.DWX | Q02 PASS, Q04 PASS, later Q05 FAIL |
| `QM5_12533` | EURJPY.DWX / GBPJPY.DWX | Q02 PASS, later Q04 FAIL |

The currently approved FX cointegration scan cards in `strategy-seeds/cards/approved`
all have corresponding EA folders and `.ex5` files. The fallback was therefore to
advance the existing forex cointegration work item already repaired for
`QM5_11241_ht-coint-spread` on AUDUSD/NZDUSD.

## Result

Farm work item `d3a12c8f-6853-46e2-871a-ada201c91425` completed Q02 on `T3`.

| Field | Value |
|---|---|
| EA | `QM5_11241_ht-coint-spread` |
| Phase | Q02 |
| Host symbol | `AUDUSD.DWX` |
| Partner symbol | `NZDUSD.DWX` |
| Setfile | `framework/EAs/QM5_11241_ht-coint-spread/sets/QM5_11241_ht-coint-spread_AUDUSD.DWX_D1_backtest.set` |
| Window | 2018-07-02 to 2022-12-31 |
| Risk mode | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Tester currency/deposit | USD / 100000 |
| Verdict | FAIL |
| Reason | `run_smoke_fail:MIN_TRADES_NOT_MET` |
| Trades | 0 |
| Evidence | `D:/QM/reports/work_items/d3a12c8f-6853-46e2-871a-ada201c91425/QM5_11241/20260708_232640/summary.json` |

This is a real strategy no-trade verdict, not an ONINIT, NO_HISTORY, or
tester-history infrastructure block. The MT5 log synchronized both `AUDUSD.DWX`
and `NZDUSD.DWX`, ran model 4 real ticks, and finished normally with final
balance unchanged at 100000.00 USD.

## Boundary Check

- No new card or duplicate work item was created.
- No manual MT5 dispatch was launched.
- No `portfolio_admission`, portfolio KPI, Q08 contribution, deploy manifest,
  `T_Live`, or AutoTrading path was touched.
- The farm finalized the row as `done/FAIL` with `evidence_provenance=real_mt5`
  and `verdict_taxonomy=strategy`.

Machine-readable artifact:
`artifacts/qm5_11241_audusd_nzdusd_q02_verdict_20260708T233337Z.json`.
