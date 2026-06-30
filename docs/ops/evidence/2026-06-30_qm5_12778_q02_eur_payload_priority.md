# QM5_12778 Q02 EUR Payload Priority

Date: 2026-06-30
Branch: `agents/board-advisor`

## Scope

- EA: `QM5_12778_edgelab-audusd-eurjpy-cointegration`
- Logical symbol: `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`
- Phase: `Q02`
- Work item: `4dbf18f1-f8c0-4665-beea-778c9ad960c2`

This advances an existing FX cointegration basket without adding a duplicate
queue row. The strict scan survivors `QM5_12532` and `QM5_12533` were checked
first; both already have logical-basket Q02 `PASS` rows. The allocated
positive-hedge scan frontier through `QM5_12803` is already represented in
`framework/EAs`, so this used the mission fallback path.

## Pre-Mutation State

Current farm state had one pending, unclaimed `QM5_12778` logical Q02 row:

| Field | Value |
|---|---|
| work_item_id | `4dbf18f1-f8c0-4665-beea-778c9ad960c2` |
| status | `pending` |
| claimed_by | `NULL` |
| tester_currency | `EUR` |
| tester_deposit | `100000` |
| timeout_min | `120` |

The row was created by the prior EUR-accounting repair but still lacked the
full fixed-risk audit fields, traded/conversion symbol split, scan metadata,
and priority metadata expected on the repaired basket Q02 path.

## Mutation

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12778_q02_eur_payload_priority_20260630T163338Z.sqlite`

Updated the pending row in place:

| Payload field | Value |
|---|---|
| `priority_track` | `true` |
| `tester_currency` | `EUR` |
| `tester_deposit` | `100000` |
| `risk_mode` | `RISK_FIXED` |
| `risk_fixed` | `1000` |
| `risk_percent` | `0` |
| `portfolio_weight` | `1` |
| `timeout_min` | `120` |
| `basket_symbols` | `AUDUSD.DWX`, `EURJPY.DWX`, `EURUSD.DWX` |
| `traded_symbols` | `AUDUSD.DWX`, `EURJPY.DWX` |
| `conversion_symbols` | `EURUSD.DWX` |

No new work item was inserted. Duplicate guard remained exactly one
pending/active Q02 row for `QM5_12778`.

## Card Alignment

Updated all three local card copies to match the actual Q02 handoff:

- `strategy-seeds/cards/edgelab-audusd-eurjpy-cointegration_card.md`
- `strategy-seeds/cards/approved/QM5_12778_edgelab-audusd-eurjpy-cointegration_card.md`
- `artifacts/cards_approved/QM5_12778_edgelab-audusd-eurjpy-cointegration.md`

The card update is documentation only. It does not change entry, exit, beta,
z-score thresholds, ATR stop, magic allocation, setfile risk, or EA source.

`build_check.ps1 -SkipCompile` refreshed the logical backtest setfile's
generated `build_hash` header. The setfile still uses `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Validation

- `python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_12778`: PASS; two terminal Q02 `INFRA_FAIL` rows and one pending Q02 row.
- Direct SQLite duplicate guard: PASS; exactly one pending/active Q02 row for `QM5_12778`, with `priority_track=true`, `tester_currency=EUR`, and `risk_fixed=1000`.
- `python -m json.tool artifacts/qm5_12778_q02_eur_payload_priority_20260630.json`: PASS.
- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12778_edgelab-audusd-eurjpy-cointegration --verbose`: `BASKET_OK`, 0 violations.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12778_edgelab-audusd-eurjpy-cointegration -RepoRoot C:/QM/repo -SkipCompile`: PASS, 0 failures, 16 existing shared-framework DWX advisory warnings; report `D:/QM/reports/framework/21/build_check_20260630_163516.json`.
- Stale conversion text grep: PASS; no `USDJPY` / `tester_currency=USD` text remains in the three local card copies.

## Safety

- No manual MT5 backtest launched.
- Q02 remains delegated to paced farm workers.
- No duplicate Q02 enqueue.
- No `T_Live` files edited.
- AutoTrading was not touched.
- No `portfolio_admission`, `portfolio_kpi`, or `q08_contribution` artifacts edited.
- No deploy manifest edited.
