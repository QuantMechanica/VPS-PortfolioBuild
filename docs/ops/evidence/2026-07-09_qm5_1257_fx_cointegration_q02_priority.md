# QM5_1257 FX Cointegration Q02 Priority Advance - 2026-07-09

Mission: grow the certified V5 portfolio book with forex sleeves without duplicating the FX cointegration queue.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling 66-pair scan artifact. It names only two strict survivors:

- `QM5_12533` - `EURJPY.DWX` / `GBPJPY.DWX`
- `QM5_12532` - `AUDUSD.DWX` / `NZDUSD.DWX`

Both anchors are already built and no longer Q02-blocked, so I did not create another card or duplicate queue row from that scan.

## Existing FX Fallback Advanced

Selected existing reputable-source FX cointegration fallback:

| Field | Value |
|---|---|
| EA | `QM5_1257_lemishko-fx-cointpair` |
| Logical basket | `QM5_1257_AUDUSD_USDJPY_COINTEGRATION_H1` |
| Legs | `AUDUSD.DWX`, `USDJPY.DWX` |
| Q02 work item | `3e600d24-7536-463e-9c8d-9a57140dbaa1` |
| Setfile | `framework/EAs/QM5_1257_lemishko-fx-cointpair/sets/QM5_1257_lemishko-fx-cointpair_QM5_1257_AUDUSD_USDJPY_COINTEGRATION_H1_H1_backtest.set` |
| Basket manifest | `framework/EAs/QM5_1257_lemishko-fx-cointpair/basket_manifest.json` |

Action taken: updated the existing pending Q02 work item payload with `priority_track=true`, `priority_reason=forex_portfolio_sleeve_gap_existing_logical_basket_no_duplicate`, and a dedupe note. No new work item was inserted.

## Validation

Commands:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_1257_lemishko-fx-cointpair -RepoRoot C:/QM/repo -SkipCompile
python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_1257_lemishko-fx-cointpair --verbose
```

Results:

- `build_check`: PASS, 0 failures, 0 warnings.
- `validate_symbol_scope`: `BASKET_OK`, 0 violations.

## CPU Ceiling

Current live farm state showed 7 active work items and 4 active `metatester64` processes. I did not launch a manual MT5 backtest; the prioritized pending row is left for the paced workers.

Guardrails: no `T_Live`, no AutoTrading, no portfolio admission/KPI/Q08 contribution changes, no T_Live manifest changes.
