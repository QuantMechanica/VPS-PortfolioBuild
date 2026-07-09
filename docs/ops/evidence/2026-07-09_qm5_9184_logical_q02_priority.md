# QM5_9184 Logical Q02 Priority Track - 2026-07-09

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
deploy-manifest, portfolio-admission, portfolio KPI, or Q08 contribution edits.

## Decision

The strict 66-pair scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` still has only two
card-worthy formal survivors:

| EA | Pair | Current state |
|---|---|---|
| `QM5_12532` | `AUDUSD.DWX` / `NZDUSD.DWX` | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | `EURJPY.DWX` / `GBPJPY.DWX` | Q02 PASS, Q04 FAIL |

The July 6 extension scan's card-worthy/borderline FX pairs are already built
locally (`QM5_13024`, `QM5_13029`, `QM5_13058`, `QM5_13062`) and have already
produced Q02 evidence. Creating another card/build/work item would be duplicate
queue work.

Fallback action: advance the existing `QM5_9184` AUDUSD/NZDUSD FX
cointegration basket by priority-tracking its existing logical Q02 row.

## Queue Change

DB backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_9184_priority_20260709T190221Z.sqlite`

Updated existing work item only:

| Field | Value |
|---|---|
| Work item | `f10fcf97-b4fb-4286-9188-d51415c8fb60` |
| EA | `QM5_9184` |
| Phase | `Q02` |
| Symbol | `QM5_9184_AUDUSD_NZDUSD_COINTEGRATION_D1` |
| Setfile | `framework/EAs/QM5_9184_jstm-pair-cointegration-fx/sets/QM5_9184_jstm-pair-cointegration-fx_QM5_9184_AUDUSD_NZDUSD_COINTEGRATION_D1_D1_backtest.set` |
| Status after | `pending` |
| `priority_track` before | `false` |
| `priority_track` after | `true` |
| Priority reason | `forex_portfolio_sleeve_gap_qm5_9184_logical_basket_q02` |
| Evidence path | `docs/ops/evidence/2026-07-09_qm5_9184_logical_q02_priority.md` |

No new work item was inserted. `farmctl work-items --status pending --ea
QM5_9184` returns exactly one pending Q02 row for the logical basket symbol.

## Validation

Commands:

```powershell
python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q
python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_9184_jstm-pair-cointegration-fx --verbose
python framework/scripts/validate_spec_doc.py framework/EAs/QM5_9184_jstm-pair-cointegration-fx
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_9184_jstm-pair-cointegration-fx -RepoRoot C:/QM/repo -SkipCompile
python framework/scripts/mt5_queue_status.py --sqlite D:/QM/strategy_farm/state/farm_state.sqlite --limit 12
```

Results:

- Manifest regression tests: PASS, 14 tests.
- Symbol scope: `BASKET_OK`, 0 violations.
- SPEC validation: PASS.
- Build check: PASS, 0 failures, 0 warnings.
- Build-check report: `D:/QM/reports/framework/21/build_check_20260709_190357.json`.
- Queue snapshot after update: 3 active, 4,888 pending.
- `QM5_9184` appears as a priority-tracked pending logical Q02 row.

No manual MT5 backtest or dispatch tick was launched. Active tester processes
were already running on `T3`, `T4`, and `T6`; `T_Live` was observed but not
touched.

Machine-readable companion:
`artifacts/qm5_9184_logical_q02_priority_20260709T190239Z.json`.
