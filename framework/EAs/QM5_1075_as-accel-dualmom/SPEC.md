# QM5_1075_as-accel-dualmom SPEC

## Identity
- EA: `QM5_1075_as-accel-dualmom`
- `ea_id`: `1075`
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1075_as-accel-dualmom.md`
- Status at build: `APPROVED`

## Strategy Mapping
- No-Trade: framework defaults plus symbol/slot guard. The EA only trades supported DWX proxy symbols and requires `qm_magic_slot_offset` to match the symbol slot.
- Entry: on the first D1 session of a new month, compute accelerating momentum score as `1M return + 3M return + 6M return`.
- Selection: if the best US proxy score and international proxy score are both below zero, select cash and open no position. Otherwise select the higher score.
- Management: no intramonth strategy management beyond framework catastrophic stop, Friday close and kill-switch.
- Exit: on monthly rebalance, close if the selected symbol changes or the strategy moves to cash.

## DWX Proxy Mapping
- US stock proxies: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`
- International small-cap proxy: `GER40.DWX`
- Defensive bond/Treasury leg: flat/cash by default, per card R3 note.

## Parameters
- `strategy_m1_bars`: 22 D1 bars
- `strategy_m3_bars`: 63 D1 bars
- `strategy_m6_bars`: 126 D1 bars
- `strategy_atr_period`: 20
- `strategy_atr_sl_mult`: 3.0

## Framework Alignment
- Uses `QM_FrameworkInit`, `QM_IsNewBar`, `QM_SMA`, `QM_StopATR`, `QM_TM_OpenPosition`, `QM_TM_ClosePosition`.
- Uses V5 grouped inputs: Framework, Risk, News, Friday Close, Strategy.
- Uses `qm_magic_slot_offset` and registry magic rows for slots 0-3.
- No external data API, no ML, no backtest or pipeline phase executed during build.
