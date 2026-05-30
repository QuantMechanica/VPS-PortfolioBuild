# QM5_1147 Unger DAX False-Break Reversal

## Scope

- `ea_id`: 1147
- `slug`: `unger-dax-false-break-reversal`
- Primary symbol: `GDAXI.DWX`
- Execution timeframe: `M15`
- Build status: V5 build artifact only; no backtests or pipeline phases executed.

## Strategy Mapping

### No-Trade

- Blocks new entries outside `strategy_session_start_hhmm` to `strategy_session_end_hhmm`.
- Blocks new entries when current spread exceeds `strategy_max_spread_points`.
- Blocks days where the current D1 open gap versus previous D1 close exceeds `strategy_open_gap_atr_mult * ATR(14,D1)`.
- V5 news, Friday close, kill-switch, risk, and magic handling remain framework-owned.

### Trade Entry

- Uses previous D1 high and low as the false-break reference levels.
- Marks a long setup only after an M15 close below previous-day low.
- Enters long at market only on a later M15 close back above previous-day low.
- Marks a short setup only after an M15 close above previous-day high.
- Enters short at market only on a later M15 close back below previous-day high.
- Enforces maximum one entry per day per magic.

### Trade Management

- No trailing stop, break-even shift, partial close, pyramiding, grid, martingale, or ML logic.
- Initial stop uses `strategy_sl_atr_mult * ATR(14,M15)`.
- Initial take-profit uses `strategy_tp_atr_mult * ATR(14,M15)`.

### Trade Close

- Positions are flattened at `strategy_session_end_hhmm`.
- Broker-side SL/TP remains active through V5 trade management.

## Setfiles

- `QM5_1147_GDAXI.DWX_M15_backtest.set`: baseline `SL=1.5 ATR`, `TP=1.0 ATR`.
- `QM5_1147_GDAXI.DWX_M15_backtest_sl10_tp075.set`: P3 low SL/TP sweep point.
- `QM5_1147_GDAXI.DWX_M15_backtest_sl20_tp15.set`: P3 high SL/TP sweep point.
- `QM5_1147_GDAXI.DWX_M15_live.set`: live risk mode with `RISK_PERCENT=0.25` and `RISK_FIXED=0`.

## Registry

- `magic_numbers.csv`: `1147, unger-dax-false-break-reversal, slot 0, GDAXI.DWX, 11470000`.
- `ea_id_registry.csv`: existing row was already present and correct.
