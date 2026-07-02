# e9b3a63d - QM5_12821 v3-faithful exits

Date: 2026-07-02
Task: e9b3a63d-56e1-436e-aaa1-f2970aec01c1
EA: QM5_12821_twin-csm-basket

## Spec Inputs

- Farm DB goal read from `D:/QM/strategy_farm/state/farm_state.sqlite`.
- Video-evidence spec read from `D:/QM/strategy_farm/artifacts/research/TWIN_EXIT_MECHANICS_RECHECK_2026-07-02.md`.
- Factory remained off: no terminal64 start, no work-item enqueue, compile-only validation.

## Diff Summary

Changed:

- `framework/EAs/QM5_12821_twin-csm-basket/QM5_12821_twin-csm-basket.mq5`
- `framework/include/QM/QM_BasketEquityStop.mqh`
- `framework/EAs/QM5_12821_twin-csm-basket/sets/QM5_12821_twin-csm-basket_FX8_TWIN_CSM_BASKET_H1_H1_backtest_v3faithful.set`

Implementation:

- Added `strategy_exit_signal_mode` with default `0` preserving legacy full entry-stack exit behavior. Mode `1` uses only closed-bar D1 CSM ranking: active strong baskets stay open only while the active currency remains `strong_idx`; active weak baskets stay open only while it remains `weak_idx`. `strategy_close_on_signal_decay` remains honored only by legacy mode.
- Added `strategy_basket_tp_units_per_lot` with default `0.0`. When positive, the basket take-profit threshold is `units_per_lot * SUM(open lots)` for the owned magic group. Percent TP remains the default path.
- Extended `QM_BasketEquityStop.mqh` with owned open-lot aggregation and `QM_BasketEquityStop_EnforceUnitsPerLot()` so P&L remains centralized in the existing basket stop helper.
- Added default-off `strategy_pending_reproject`. When enabled, active unfilled basket limit legs are evaluated on each new M30 closed bar during entry sessions before flat time, canceled/replaced at recomputed pullback boundaries, and permanently stopped when price has moved beyond `strategy_pullback_max_chase_atr` from the boundary in the entry direction.
- Created v3faithful set with `strategy_exit_signal_mode=1`, `strategy_basket_tp_units_per_lot=400`, `strategy_pending_reproject=true`, `strategy_pending_expiration_minutes=30`, `strategy_flat_hhmm=2100`, and `strategy_close_on_signal_decay=true`.

Preserved:

- Entry signal stack, sizing formula, DL-081 stop behavior, news gate order, and `OnTick()` ordering.
- Base backtest set and v2exit set were not modified.

## Validation Logs

Strict compile:

```text
Command:
python tools/strategy_farm/compile_ea.py --ea-label QM5_12821_twin-csm-basket --force --json --fail-on-error

Result:
verdict: COMPILED
reason: fresh build, 0 warnings
compile_one_exit_code: 0
compile_one_errors: 0
compile_one_warnings: 0
compile_log_path: C:\QM\repo\framework\build\compile\20260702_114147\QM5_12821_twin-csm-basket.compile.log
symbol_scope_verdict: BASKET_OK
```

Compiler terminal log ended with:

```text
Result: 0 errors, 0 warnings, 3844 ms elapsed, cpu='X64 Regular'
```

Guardrails:

```text
Command:
python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_12821_twin-csm-basket

Result:
verdict: PASS
files_checked: 32
findings: []
max_news_stale_hours: 336
```
