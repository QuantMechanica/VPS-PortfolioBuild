# QM5_1189 qp-oil-posshock-pullback

## Intent
Quantpedia oil positive-shock pullback strategy. The EA shorts oil after a completed D1 bar with an unusually strong positive daily return during a high-ATR regime, then exits after the next daily holding window.

## Framework Alignment
- No-Trade: blocks all symbols except `XTIUSD.DWX` and `XBRUSD.DWX`, all timeframes except `D1`, mismatched magic slots, invalid parameters, insufficient history, and abnormal spread/bar-quality conditions.
- Entry: on a new D1 bar, evaluates the prior completed D1 bar. It opens short when daily return is at least `strategy_return_atr_mult * ATR20%` and the ATR20% percentile rank over the trailing 252 sessions is at or above `strategy_atr_percentile_min`.
- Management: no trailing stop, averaging, grid, pyramiding, or partial close. The card specifies one initial ATR stop.
- Close: closes after the configured next-D1 holding window; default is one D1 bar after entry.

## Data Contract
The EA uses Darwinex MT5/DWX daily bars only. There are no web calls, external APIs, ML models, or CSV dependencies. `XTIUSD.DWX` is the preferred route; `XBRUSD.DWX` is the alternate oil proxy.

## Symbols and Slots
- slot 0: `XTIUSD.DWX`, magic `11890000`
- slot 1: `XBRUSD.DWX`, magic `11890001`

## Risk
- Backtest default: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Live template: `RISK_PERCENT=0.25`, `RISK_FIXED=0`

## Notes
The approved card is marked `card_body_incomplete` for period metadata, but the body contains enough deterministic mechanics for build scope: D1 bars, short-only positive-shock entry, ATR-percentile filter, ATR stop, and next-close style exit. The `strategy_max_hold_d1_bars` input is present for the card's P1 two-session evaluation note, with default frozen to one bar.
