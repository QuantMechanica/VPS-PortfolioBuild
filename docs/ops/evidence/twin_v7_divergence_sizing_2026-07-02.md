# T-WIN v7 Divergence Gate + Cluster Sizing Evidence - 2026-07-02

## Scope

OWNER-directed T-WIN v7 implementation for `QM5_12821_twin-csm-basket`.

Factory remained OFF for this change. No work items were enqueued, no backtests were launched, and no running `terminal64` / `metatester` process was touched.

Research evidence base:

- `D:/QM/strategy_farm/artifacts/research/TWIN_SECRET_DIRECTION_CSM_2026-07-02.md`

## Unit Analysis

`framework/include/QM/QM_CurrencyStrength.mqh` computes pair performance as:

```text
perf_pct = ((close - open) / open) * 100
```

`QM_CSM_BuildFromPerf()` then adds that percent value to the base currency and subtracts it from the quote currency for each of the 28 pairs. `reading.raw_strength[c]` is copied directly from this aggregate before normalization.

Therefore the EA raw aggregate unit is:

```text
EA raw strength = sum of 7 cross percent changes
```

It is a sum, not an average. Conversion to the trader's displayed raw cumulative x100 scale is:

```text
trader_x100_sum = EA_raw_sum_percent * 100
EA_raw_sum_percent = trader_x100_sum / 100
avg_cross_percent = EA_raw_sum_percent / 7
```

The research band says tradeable strong-vs-weak spreads are roughly `700..1000` on the trader x100-sum scale:

```text
700..1000 x100-sum = 7.0..10.0 EA raw sum-percent
                  = 1.0..1.4 average percent per cross
```

Chosen sweep thresholds:

- `_v7div_lo`: `strategy_min_divergence_raw=5.10` (`510` x100-sum)
- `_v7div`: `strategy_min_divergence_raw=8.50` (`850` x100-sum)
- `_v7div_hi`: `strategy_min_divergence_raw=12.75` (`1275` x100-sum)

## Formulas

Divergence gate:

```text
divergence_raw = raw_strength[strong_idx] - raw_strength[weak_idx]
reject when strategy_min_divergence_raw > 0 and divergence_raw < strategy_min_divergence_raw
```

Real 1% cluster sizing when `strategy_stop_engage_move_pct > 0`:

```text
risk_money = QM12821_BaseRiskMoney()
move_value_i = (strategy_stop_engage_move_pct / 100) * price_i * (SYMBOL_TRADE_TICK_VALUE_i / SYMBOL_TRADE_TICK_SIZE_i)
total_move_value_per_1lot = sum(move_value_i for all planned legs)
raw_lots_per_leg = risk_money / total_move_value_per_1lot
lots_per_leg = min(raw_lots_per_leg, strategy_max_lots_per_leg), then broker min/step/max normalization per symbol
```

Projected stop-engage move is logged after normalization:

```text
projected_move_pct = configured_move_pct * risk_money / sum(normalized_lots_i * move_value_i)
```

## Diff Summary

Source:

- Added input-gated `strategy_min_divergence_raw=0.0`, default off.
- Added input-gated `strategy_stop_engage_move_pct=0.0`, default legacy `strategy_total_lots_per_1000` behavior.
- Added `strategy_max_lots_per_leg=1.0`.
- Added `BASKET_DIVERGENCE_BLOCK` log when the flat-matrix divergence gate rejects a signal.
- Replaced per-symbol lot calculation at initial open and re-projection with plan-level sizing when the new move-percent input is enabled.
- Added one `BASKET_RISK_SIZING` log line per initial basket cycle with legs, lots, configured move, and projected stop-engage move.

Setfiles:

- `framework/EAs/QM5_12821_twin-csm-basket/sets/QM5_12821_twin-csm-basket_FX8_TWIN_CSM_BASKET_H1_H1_backtest_v7div.set`
- `framework/EAs/QM5_12821_twin-csm-basket/sets/QM5_12821_twin-csm-basket_FX8_TWIN_CSM_BASKET_H1_H1_backtest_v7div_lo.set`
- `framework/EAs/QM5_12821_twin-csm-basket/sets/QM5_12821_twin-csm-basket_FX8_TWIN_CSM_BASKET_H1_H1_backtest_v7div_hi.set`

All three use:

- `strategy_stop_engage_move_pct=0.50`
- `strategy_exhaustion_mode=0`
- `strategy_reverse_direction=false`
- `strategy_max_lots_per_leg=1.0`

## Validation Logs

Guardrails:

```powershell
python tools\strategy_farm\validate_build_guardrails.py framework\EAs\QM5_12821_twin-csm-basket
```

Result:

```json
{
  "files_checked": 41,
  "findings": [],
  "path": "framework\\EAs\\QM5_12821_twin-csm-basket",
  "verdict": "PASS"
}
```

Compile:

```powershell
python tools\strategy_farm\compile_ea.py --ea-label QM5_12821_twin-csm-basket --force --json --fail-on-error
```

Result:

```json
{
  "ea_label": "QM5_12821_twin-csm-basket",
  "verdict": "COMPILED",
  "reason": "fresh build, 0 warnings",
  "ex5_path": "C:\\QM\\repo\\framework\\EAs\\QM5_12821_twin-csm-basket\\QM5_12821_twin-csm-basket.ex5",
  "ex5_size_bytes": 339168,
  "compile_one_exit_code": 0,
  "compile_one_errors": 0,
  "compile_one_warnings": 0,
  "compile_log_path": "C:\\QM\\repo\\framework\\build\\compile\\20260702_164838\\QM5_12821_twin-csm-basket.compile.log",
  "symbol_scope_verdict": "BASKET_OK"
}
```
