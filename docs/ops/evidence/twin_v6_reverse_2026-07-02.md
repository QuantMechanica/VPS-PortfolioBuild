# T-WIN v6 Reverse Experiment Evidence - 2026-07-02

## Scope

OWNER-directed reverse-mode experiment for `QM5_12821_twin-csm-basket`.

Factory remained OFF for this change: no work items were enqueued and no T5 process was touched.

## Geometry

The existing T-WIN continuation basket computes each leg's pullback fair-price boundary from the original plan side:

- Original buy leg: boundary is below market, placed as `QM_BUY_LIMIT`.
- Original sell leg: boundary is above market, placed as `QM_SELL_LIMIT`.

The reverse experiment must preserve the same boundary-crossing fill timing while flipping exposure. A sell at the original buy boundary is below market, so a sell limit would be invalid geometry and would not model the same crossing. The input-gated reverse mapping is therefore:

- `QM_BUY_LIMIT` continuation geometry -> `QM_SELL_STOP` at the same boundary price.
- `QM_SELL_LIMIT` continuation geometry -> `QM_BUY_STOP` at the same boundary price.

`g_active_currency_idx` and `g_active_direction` remain the original non-reversed plan values. Ranking-decay exit mode and strength-shift semantics therefore continue to evaluate the original exhaustion thesis; for the fade, normalization/decay of that thesis closes the basket.

`QM_OrderTypes.mqh` and `QM_BasketOrder.mqh` already support `QM_BUY_STOP` / `QM_SELL_STOP` through `ORDER_TYPE_BUY_STOP` / `ORDER_TYPE_SELL_STOP`, with the same pending action and expiration/GTC handling as limits.

## Diff

Touched source behavior:

- Added `input bool strategy_reverse_direction = false;`.
- Updated `QM12821_LegPendingOrderType()`:
  - default `false`: original buy -> `QM_BUY_LIMIT`, original sell -> `QM_SELL_LIMIT`.
  - reverse `true`: original buy -> `QM_SELL_STOP`, original sell -> `QM_BUY_STOP`.
- Initial basket placement now uses `QM12821_LegPendingOrderType(plan.legs[i])`.
- Pending re-projection already routes replacement, find, and cancel logic through `QM12821_LegPendingOrderType(...)`, so the same reverse mapping applies on re-place.
- Added log fields for `reverse` and `placement_type`.

New set files:

- `framework/EAs/QM5_12821_twin-csm-basket/sets/QM5_12821_twin-csm-basket_FX8_TWIN_CSM_BASKET_H1_H1_backtest_v6rev.set`
  - `strategy_exhaustion_mode=1`
  - `strategy_exhaustion_abs_pct=2.00`
  - `strategy_reverse_direction=true`
- `framework/EAs/QM5_12821_twin-csm-basket/sets/QM5_12821_twin-csm-basket_FX8_TWIN_CSM_BASKET_H1_H1_backtest_v6rev15.set`
  - `strategy_exhaustion_mode=1`
  - `strategy_exhaustion_abs_pct=1.50`
  - `strategy_reverse_direction=true`

Compiled artifact updated:

- `framework/EAs/QM5_12821_twin-csm-basket/QM5_12821_twin-csm-basket.ex5`

## Validation Logs

Compile:

```powershell
python tools/strategy_farm/compile_ea.py --ea-label QM5_12821_twin-csm-basket --force --json --fail-on-error
```

Result:

```json
{
  "ea_label": "QM5_12821_twin-csm-basket",
  "verdict": "COMPILED",
  "reason": "fresh build, 0 warnings",
  "compile_one_exit_code": 0,
  "compile_one_errors": 0,
  "compile_one_warnings": 0,
  "compile_log_path": "C:\\QM\\repo\\framework\\build\\compile\\20260702_160106\\QM5_12821_twin-csm-basket.compile.log",
  "symbol_scope_verdict": "BASKET_OK"
}
```

Guardrails:

```powershell
python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_12821_twin-csm-basket
```

Result:

```json
{
  "files_checked": 38,
  "findings": [],
  "path": "framework\\EAs\\QM5_12821_twin-csm-basket",
  "verdict": "PASS"
}
```
