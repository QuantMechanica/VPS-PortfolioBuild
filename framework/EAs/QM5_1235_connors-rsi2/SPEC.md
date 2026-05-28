# QM5_1235 Connors RSI-2 Mean Reversion

## Source Card

- `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1235_connors-rsi2.md`
- Local copy: `docs/strategy_card.md`
- Status: APPROVED / G0

## Framework Alignment

- No-Trade: blocks non-D1 host charts and non-D1 strategy timeframe. Framework handles kill-switch, news, Friday close, and risk validation.
- Entry: evaluates the last closed D1 bar. Long when close is above SMA(200) and RSI(2) is below `strategy_entry_rsi_long`; optional short when close is below SMA(200) and RSI(2) is above `strategy_entry_rsi_short`.
- Management: baseline keeps only the initial ATR protective stop; no trailing, averaging, martingale, or pyramiding.
- Close: exits on the next D1 bar when close crosses SMA(5), RSI(2) normalises, or `strategy_max_hold_bars` is reached.

## Symbols And Slots

| Slot | Symbol |
|---:|---|
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | USDJPY.DWX |
| 3 | AUDUSD.DWX |
| 4 | USDCAD.DWX |
| 5 | NZDUSD.DWX |
| 6 | XAUUSD.DWX |
| 7 | XTIUSD.DWX |
| 8 | NDX.DWX |
| 9 | WS30.DWX |
| 10 | GDAXI.DWX |
| 11 | UK100.DWX |

## Inputs

- `strategy_timeframe=PERIOD_D1`
- `strategy_rsi_period=2`
- `strategy_sma_trend_period=200`
- `strategy_sma_exit_period=5`
- `strategy_atr_period=14`
- `strategy_entry_rsi_long=10`
- `strategy_entry_rsi_short=90`
- `strategy_exit_rsi_long=70`
- `strategy_exit_rsi_short=30`
- `strategy_atr_stop_mult=3.0`
- `strategy_max_hold_bars=10`
- `strategy_min_history_bars=220`
- `strategy_enable_shorts=true`
- `strategy_use_sma_slope=false`
- `strategy_spread_days=60`
- `strategy_spread_mult=2.0`

## Build Notes

- Build-only implementation; no backtests or pipeline phases were run.
- Risk sizing is delegated to the V5 framework through the ATR stop distance.
- News defaults use FW1 temporal pre/post pause and DXZ compliance profile.
