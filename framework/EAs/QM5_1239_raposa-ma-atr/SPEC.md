# QM5_1239 Raposa EMA Crossover ATR

## Source Card

- `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1239_raposa-ma-atr.md`
- Local copy: `docs/strategy_card.md`
- Status: APPROVED / G0

## Framework Alignment

- No-Trade: blocks non-H1 host charts and non-H1 strategy timeframe. Framework handles kill-switch, news, Friday close, and risk validation.
- Entry: evaluates the last closed H1 bar. Long requires EMA(20) crossing above EMA(80), close above EMA(200), ATR(14) above 0.50 times MedianATR(240), and acceptable spread. Short mirrors the same rules below EMA(200).
- Management: after unrealized profit exceeds 1.5R, trails the stop by 2.5 ATR(14).
- Close: exits on the opposite EMA(20)/EMA(80) cross or after `strategy_max_hold_bars` H1 bars. Take-profit is set to 2.0R at entry.

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

- `strategy_timeframe=PERIOD_H1`
- `strategy_ema_fast=20`
- `strategy_ema_slow=80`
- `strategy_ema_trend=200`
- `strategy_atr_period=14`
- `strategy_atr_median_bars=240`
- `strategy_min_atr_ratio=0.50`
- `strategy_stop_atr_mult=2.0`
- `strategy_tp_r_mult=2.0`
- `strategy_trail_trigger_r=1.5`
- `strategy_trail_atr_mult=2.5`
- `strategy_max_hold_bars=120`
- `strategy_min_history_bars=260`
- `strategy_spread_days=20`
- `strategy_spread_mult=2.0`

## Build Notes

- Build-only implementation; no backtests or pipeline phases were run.
- Risk sizing is delegated to the V5 framework through the ATR stop distance.
- Opposite entries are blocked on the same H1 bar after a strategy exit.
- News defaults use FW1 temporal pre/post pause and DXZ compliance profile.
