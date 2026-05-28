# QM5_1188 qp-oil-negshock-rebound

## Intent
Quantpedia oil negative-shock mean-reversion strategy. The EA trades long oil after a completed D1 bar has a close-to-close loss of at least `2 * ATR20%` while the current ATR20% is in the upper volatility regime.

## Framework Alignment
- No-Trade: blocks all symbols except `XTIUSD.DWX` and `XBRUSD.DWX`, all non-D1 charts, mismatched magic slots, invalid parameters, insufficient D1 history, optional spread breaches, and optional Friday signal days.
- Entry: on a new completed D1 bar, computes daily return, ATR(20)% of close, and the trailing 252-session percentile rank of ATR(20)%. If return is less than or equal to `-2 * ATR20%` and ATR percentile is at least 70, opens one long position.
- Management: no trailing stop, averaging, or partial close; the card specifies only an initial ATR stop.
- Close: closes when the next D1 bar begins after entry, with a two-session safety hold variant available through setfiles.

## Data Contract
The EA uses Darwinex MT5/DWX D1 bars only. There are no web calls, external APIs, ML models, or CSV dependencies.

## Symbols and Slots
- slot 0: `XTIUSD.DWX`, magic `11880000`
- slot 1: `XBRUSD.DWX`, magic `11880001`

## Risk
- Backtest default: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Live template: `RISK_PERCENT=0.25`, `RISK_FIXED=0`

## Notes
`XTIUSD.DWX` is the preferred route. `XBRUSD.DWX` is included as the Brent alternate route called out by the Strategy Card. The local card copy is URL-sanitized for build-check compatibility; the approved source card is unchanged.
