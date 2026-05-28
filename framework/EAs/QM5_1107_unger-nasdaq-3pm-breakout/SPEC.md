# QM5_1107 Unger Nasdaq 3PM Breakout

## Card

- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1107_unger-nasdaq-3pm-breakout.md`
- Local copy: `docs/strategy_card.md`
- EA id: `1107`
- Slug: `unger-nasdaq-3pm-breakout`

## Framework Alignment

- No-Trade: V5 framework kill-switch, two-axis news filter, Friday-close, spread cap, weekday check.
- Entry: on M5 only, capture the 15:00 New York M5 bar close when the bar closes at 15:05, then place stop orders until 15:55 New York.
- Weekday rules: long entries skipped on Friday; short entries skipped on Monday.
- Stop: hard stop at `1.25 * ATR(14, M5)` from pending entry price.
- Take-profit: optional `2.0R`, disabled by default.
- Management: first filled position cancels the opposite pending order; one trade per day per magic.
- Exit: strategy close at 02:00 New York on the next session day when SL/TP has not already closed the trade.

## Symbol Slots

| slot | symbol | purpose |
|---:|---|---|
| 0 | NDX.DWX | primary |
| 1 | SP500.DWX | optional backtest-only robustness |
| 2 | WS30.DWX | robustness port |

## Default Parameters

| input | default |
|---|---:|
| `strategy_long_pct` | `0.0008` |
| `strategy_short_pct` | `0.0008` |
| `strategy_atr_period` | `14` |
| `strategy_atr_sl_mult` | `1.25` |
| `strategy_use_rr_take_profit` | `false` |
| `strategy_take_profit_rr` | `2.0` |
