# QM5_1192 qp-stress-oil-rebound

## Intent
Quantpedia short-term correlated stress reversal strategy. After a completed D1 bar where both `SP500.DWX` and `XAUUSD.DWX` are negative, the EA opens long the approved oil proxy and exits at the next D1 close.

## Framework Alignment
- No-Trade: blocks all symbols except the slot's oil proxy (`XTIUSD.DWX` for slot 0, `XBRUSD.DWX` for slot 1), all timeframes except `D1`, invalid parameters, insufficient history, and optional max-spread breaches.
- Entry: on a new completed D1 bar, computes close-to-close returns for `SP500.DWX` and `XAUUSD.DWX`. If both returns are below `strategy_stress_threshold_pct`, opens one long oil position for the current magic slot.
- Management: no trailing stop or partial close; the card specifies only an initial ATR stop and short scheduled holding period.
- Close: closes once a new D1 bar begins after the entry day; safety exit triggers after the configured maximum hold in D1 bars.

## Data Contract
The EA uses Darwinex MT5/DWX bars only. There are no web calls, external APIs, ML models, or CSV dependencies. `SP500.DWX` and `XAUUSD.DWX` are signal-only; `XTIUSD.DWX` is the preferred oil trade proxy and `XBRUSD.DWX` is the fallback oil trade proxy.

## Symbols and Slots
- slot 0: `XTIUSD.DWX`, magic `11920000`
- slot 1: `XBRUSD.DWX`, magic `11920001`

## Risk
- Backtest default: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Live template: `RISK_PERCENT=0.25`, `RISK_FIXED=0`

## Notes
`SP500.DWX` remains a T6 live-promotion caveat per the Strategy Card. Before live AutoTrading, parallel validation on a routable equity-stress proxy such as `NDX.DWX` or `WS30.DWX` is required.
