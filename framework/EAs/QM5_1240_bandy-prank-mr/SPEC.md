# QM5_1240 Bandy Percent-Rank Mean Reversion

## Source Card

- `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1240_bandy-prank-mr.md`
- Local copy: `docs/strategy_card.md`
- Status: APPROVED / G0

## Framework Alignment

- No-Trade: blocks non-D1 host charts and non-D1 strategy timeframe. Framework handles kill-switch, news, Friday close, and risk validation.
- Entry: evaluates the last closed D1 bar. Long when close is above SMA(200), 3-day return percent-rank is at or below 10, and close remains above 94% of SMA(20). Optional short when close is below SMA(200), percent-rank is at or above 90, and close remains below 106% of SMA(20).
- Management: baseline keeps only the initial ATR protective stop; no trailing, averaging, martingale, or pyramiding.
- Close: exits on the next D1 bar when percent-rank normalises, close crosses SMA(5), or `strategy_max_hold_bars` is reached.

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
- `strategy_return_bars=3`
- `strategy_prank_lookback=100`
- `strategy_sma_trend_period=200`
- `strategy_sma_guard_period=20`
- `strategy_sma_exit_period=5`
- `strategy_atr_period=14`
- `strategy_entry_prank_long=10`
- `strategy_entry_prank_short=90`
- `strategy_exit_prank_long=55`
- `strategy_exit_prank_short=45`
- `strategy_long_crash_mult=0.94`
- `strategy_short_extension_mult=1.06`
- `strategy_atr_stop_mult=2.5`
- `strategy_max_hold_bars=8`
- `strategy_min_history_bars=260`
- `strategy_median_tr_period=100`
- `strategy_tr_spike_mult=3.0`
- `strategy_spread_days=60`
- `strategy_spread_mult=2.0`
- `strategy_enable_shorts=true`

## Build Notes

- Build-only implementation; no backtests or pipeline phases were run.
- Risk sizing is delegated to the V5 framework through the ATR stop distance.
- News defaults use FW1 temporal pre/post pause and DXZ compliance profile.
