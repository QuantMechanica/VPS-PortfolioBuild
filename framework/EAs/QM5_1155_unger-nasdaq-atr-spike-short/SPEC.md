# QM5_1155 Unger Nasdaq ATR Spike Short

## Strategy Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1155_unger-nasdaq-atr-spike-short.md`
- Status: G0 APPROVED
- Build scope: V5 framework EA only. No backtests or pipeline phases.

## Framework Alignment

- No-Trade: V5 kill switch, news compliance, Friday close, symbol-slot guard, M5 timeframe guard, weekday/session checks, spread limit, one-position-per-magic guard.
- Entry: short-only market entry on completed M5 bearish downside spike where body exceeds `BODY_MULT * AVG_BODY20`, body exceeds `ATR_MULT * ATR14`, and close breaks the prior completed bar low.
- Management: no trailing or scale logic in first build.
- Close: ATR stop loss, ATR take profit, US index session pre-close flatten, optional EMA20 momentum exit.

## Symbols and Magic Slots

| Slot | Symbol | Purpose |
| --- | --- | --- |
| 0 | `NDX.DWX` | primary |
| 1 | `WS30.DWX` | robustness/live port |
| 2 | `SP500.DWX` | backtest-only robustness port |

Magic formula follows V5 registry: `magic = ea_id * 10000 + symbol_slot`.

## Risk Contract

- Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Live setfiles use `RISK_PERCENT=0.25` and `RISK_FIXED=0`.

## Notes

- `SP500.DWX` remains a T6 live caveat from the card; live deployment requires parallel validation on broker-routable `NDX.DWX` or `WS30.DWX`.
- The local card copy removes external URL syntax for build-check compliance. The approved source card is unchanged.
