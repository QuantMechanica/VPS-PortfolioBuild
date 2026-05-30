# QM5_1106_unger-nasdaq-pullback-tf SPEC

## Identity
- EA: `QM5_1106_unger-nasdaq-pullback-tf`
- `ea_id`: `1106`
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1106_unger-nasdaq-pullback-tf.md`
- Status at build: `APPROVED`

## Strategy Mapping
- No-Trade: framework kill-switch, news, Friday close, plus EA guards for supported DWX symbols, matching magic slot, M5 timeframe, NY weekday cash session, and valid parameters.
- Entry: on each closed M5 bar in the U.S. cash session after the first 15 minutes and before the final 10 minutes, require setup bar `High[2] > Highest(High[3..LOOKBACK+2])`, then pullback bar `Close[1] < Close[2]`.
- Volatility filter: require current `ATR(14,D1) / Close(D1)` to be above the median of the prior 60 daily ATR ratios.
- Stop: hard long ATR stop at `1.5 * ATR(14,M5)` from market entry. If the stop is tighter than broker minimum stop distance, the trade is skipped.
- Management: no trailing, partial close, pyramiding, or break-even by default.
- Exit: force flat at the last M5 bar of the U.S. cash session. Broker SL handles the protective ATR close. Optional `2.5R` TP exists as disabled input for first build.

## DWX Symbol Slots
- Slot 0: `NDX.DWX` primary.
- Slot 1: `SP500.DWX` optional backtest-only robustness port.
- Slot 2: `WS30.DWX` live-routable robustness port.

## Parameters
- `strategy_lookback_bars`: 12, P3 sweep candidates `{6, 12, 18, 24}`.
- `strategy_atr_period`: 14.
- `strategy_atr_sl_mult`: 1.5.
- `strategy_use_rr_take_profit`: false.
- `strategy_take_profit_rr`: 2.5.
- `strategy_session_open_hhmm`: 930 NY.
- `strategy_session_close_hhmm`: 1600 NY.
- `strategy_skip_open_minutes`: 15.
- `strategy_skip_close_minutes`: 10.
- `strategy_daily_atr_median_days`: 60.

## Framework Alignment
- Uses `QM_FrameworkInit`, `QM_IsNewBar`, `QM_ATR`, `QM_StopATRFromValue`, `QM_TakeRR`, `QM_TM_OpenPosition`, `QM_TM_ClosePosition`.
- Uses V5 grouped inputs: Framework, Risk, News, Friday Close, Stress, Strategy.
- Uses `qm_magic_slot_offset` and registry magic rows for slots 0-2.
- No external data API, no ML, no backtest or pipeline phase executed during build.
