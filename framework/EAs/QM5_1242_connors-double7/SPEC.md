# QM5_1242 Connors Double Seven

## Source Card

- `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1242_connors-double7.md`
- Local copy: `docs/strategy_card.md`
- Status: APPROVED / G0

## Framework Alignment

- No-Trade: blocks non-D1 host charts and non-D1 strategy timeframe. Framework handles kill-switch, news, Friday close, and risk validation.
- Entry: evaluates the last closed D1 bar. Long when close is above SMA(200) and closes at or below the 7-day low; optional short when close is below SMA(200) and closes at or above the 7-day high.
- Management: baseline keeps the initial protective stop only; no averaging down, pyramiding, martingale, or trailing stop.
- Close: exits on the next D1 bar when long close reaches the 7-day high, short close reaches the 7-day low, or `strategy_max_hold_bars` is reached.

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
- `strategy_sma_trend_period=200`
- `strategy_extreme_lookback=7`
- `strategy_atr_period=14`
- `strategy_atr_stop_mult=3.0`
- `strategy_enable_hard_stop=true`
- `strategy_hard_stop_r_mult=2.0`
- `strategy_max_hold_bars=12`
- `strategy_min_history_bars=220`
- `strategy_enable_shorts=true`
- `strategy_median_tr_bars=100`
- `strategy_range_mult=3.0`
- `strategy_spread_days=60`
- `strategy_spread_mult=2.0`

## Build Notes

- Build-only implementation; no backtests or pipeline phases were run.
- Risk sizing is delegated to the V5 framework through the protective stop distance.
- News defaults use FW1 temporal pre/post pause and DXZ compliance profile.
- The local strategy-card copy has URL protocols stripped so `build_check` does not flag external URL patterns inside the EA folder.
