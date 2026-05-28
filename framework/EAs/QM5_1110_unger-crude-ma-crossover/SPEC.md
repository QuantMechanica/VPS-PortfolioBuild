# QM5_1110 Unger Crude MA Crossover

## Source

Approved strategy card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1110_unger-crude-ma-crossover.md`

## Instrument And Timeframe

- Symbol: `XTIUSD.DWX`
- Execution timeframe: `M15`
- Magic slot: `0`
- Magic number: `11100000`

## Framework Alignment

- No-Trade: blocks non-`XTIUSD.DWX`, non-`M15`, invalid parameters, first/last configured session minutes, V5 news, V5 Friday close, and spread cap.
- Entry: closed-bar SMA(30)/SMA(140) crossover; long on fast-above-slow cross, short on fast-below-slow cross.
- Trade Management: no trailing or scale-out, matching card default trend-following design.
- Close: opposite SMA crossover, ATR SL / optional 4R TP, and max 5 D1 sessions held.

## Strategy Parameters

- `strategy_fast_sma_period = 30`
- `strategy_slow_sma_period = 140`
- `strategy_atr_period = 14`
- `strategy_atr_sl_mult = 2.5`
- `strategy_tp_enabled = false`
- `strategy_tp_rr = 4.0`
- `strategy_max_sessions = 5`
- `strategy_session_skip_minutes = 60`
- `strategy_d1_atr_percentile_days = 120`
- `strategy_d1_atr_percentile = 30.0`
- `strategy_spread_median_bars = 120`
- `strategy_spread_mult = 2.0`

## Risk Contract

- Backtest set uses `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live set uses `RISK_PERCENT=0.25`, `RISK_FIXED=0`.
- Position sizing is delegated to `QM_LotsForRisk` via `QM_TM_OpenPosition`.

## Build Notes

- No ML, no external data calls, no custom data import.
- `.DWX` suffix is preserved for research/backtest artifacts.
- No backtest or pipeline phase is run by this build task.
