# QM5_1108_unger-gold-bb-breakout SPEC

## Identity
- EA: `QM5_1108_unger-gold-bb-breakout`
- `ea_id`: `1108`
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1108_unger-gold-bb-breakout.md`
- Status at build: `APPROVED`

## Strategy Mapping
- No-Trade: framework kill-switch, two-axis news filter, Friday close, plus EA guards for `XAUUSD.DWX`, slot 0, H1 timeframe, and valid parameters.
- Entry: on each closed H1 bar, enter long when `Close[1] > UpperBand[1]` using Bollinger Bands on close. Baseline parameters are period 40 and 2 standard deviations.
- Compression filter: when enabled, require the previous D1 session range to be below the median of the prior 40 D1 session ranges.
- Stop: hard long ATR stop at `2.0 * ATR(14,H1)` from market entry. Trades are skipped if the stop violates broker minimum stop distance.
- Take profit: baseline fixed `3.0R` target enabled by default, as specified by the card.
- Management: no trailing, partial close, pyramiding, or break-even.
- Exit: close on `Close[1] <= MiddleBand[1]` only once the position has at least two closed H1 bars behind it. Also close after `7` sessions, implemented as seven 24-hour broker sessions from open time. Broker SL/TP handle protective exits.

## DWX Symbol Slots
- Slot 0: `XAUUSD.DWX` primary.

## Parameters
- `strategy_bb_period`: 40, P3 classic variant uses 20.
- `strategy_bb_deviation`: 2.0.
- `strategy_atr_period`: 14.
- `strategy_atr_sl_mult`: 2.0.
- `strategy_use_rr_take_profit`: true.
- `strategy_take_profit_rr`: 3.0.
- `strategy_max_hold_sessions`: 7.
- `strategy_session_median_days`: 40.
- `strategy_use_compression_filter`: true.

## Framework Alignment
- Uses `QM_FrameworkInit`, `QM_IsNewBar`, `QM_BB_Upper`, `QM_BB_Middle`, `QM_ATR`, `QM_EntryMarketPrice`, `QM_StopATRFromValue`, `QM_TakeRR`, `QM_TM_OpenPosition`, and `QM_TM_ClosePosition`.
- Uses V5 grouped inputs: Framework, Risk, News, Friday Close, Stress, Strategy.
- Uses `qm_magic_slot_offset` and the registry magic row for `(1108, 0)`.
- No external data API, no ML, no backtest or pipeline phase executed during build.
