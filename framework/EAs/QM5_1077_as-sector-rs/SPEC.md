# QM5_1077_as-sector-rs SPEC

## Identity
- EA: `QM5_1077_as-sector-rs`
- `ea_id`: `1077`
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1077_as-sector-rs.md`
- Status at build: `APPROVED`

## Strategy Mapping
- No-Trade: framework defaults plus symbol/slot guard. The EA only trades the declared DWX proxy universe and requires `qm_magic_slot_offset` to match the symbol slot.
- Entry: on the first D1 session of a new month, rank the universe by trailing total return over `strategy_lookback_months`.
- Selection: buy symbols that are in the top `strategy_top_n` after the optional long-term SMA filter. If no symbol passes the filter, hold cash/flat.
- Management: no intramonth strategy management beyond framework catastrophic stop, Friday close, kill-switch and the risk-sizing ATR SL.
- Exit: on monthly rebalance, close if the chart symbol is no longer selected or fails the SMA filter.

## DWX Proxy Universe
- Slot 0: `NDX.DWX`
- Slot 1: `WS30.DWX`
- Slot 2: `GDAXI.DWX`
- Slot 3: `UK100.DWX`
- Slot 4: `XAUUSD.DWX`
- Slot 5: `XTIUSD.DWX`
- Slot 6: `SP500.DWX`

## Parameters
- `strategy_top_n`: 3
- `strategy_lookback_months`: 12
- `strategy_use_sma_filter`: true
- `strategy_sma_months`: 10
- `strategy_atr_period`: 20
- `strategy_atr_sl_mult`: 3.0
- `PORTFOLIO_WEIGHT`: 0.333333 in canonical backtest sets for equal-weight top-3 sleeve sizing.

## Framework Alignment
- Uses `QM_FrameworkInit`, `QM_IsNewBar`, `QM_SMA`, `QM_StopATR`, `QM_TM_OpenPosition`, `QM_TM_ClosePosition`.
- Uses V5 grouped inputs: Framework, Risk, News, Friday Close, Strategy.
- Uses `qm_magic_slot_offset` and registry magic rows for slots 0-6.
- No external data API, no ML, no backtest or pipeline phase executed during build.

## Implementation Notes
- The source strategy uses monthly rotation exits rather than intramonth stops. V5 entry sizing requires a non-zero SL distance, so the EA applies a 20-day ATR x 3.0 stop as a framework risk stop, not as a ranking or rotation rule.
- The original sector ETF universe is not DWX-routable. This implementation follows the approved Card's DWX broad index, metals and oil proxy universe.
