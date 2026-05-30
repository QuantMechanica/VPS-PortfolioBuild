# QM5_1185 qp-stress-gold-rebound

## Intent
Quantpedia short-term correlated stress reversal strategy. The EA trades the gold response leg: after a completed D1 bar where both `SP500.DWX` and the oil proxy are negative, it opens long `XAUUSD.DWX` and exits at the next D1 close.

## Framework Alignment
- No-Trade: blocks all symbols except `XAUUSD.DWX`, all timeframes except `D1`, nonzero magic slots, invalid parameters, insufficient history, and optional max-spread breaches.
- Entry: on a new completed D1 bar, computes close-to-close returns for `SP500.DWX` and `XTIUSD.DWX`, falling back to `XBRUSD.DWX` if the primary oil symbol is unavailable. If both returns are below `strategy_stress_threshold_pct`, opens one long gold position.
- Management: no trailing stop or partial close; the card specifies only an initial ATR stop and short scheduled holding period.
- Close: closes once a new D1 bar begins after the entry day; safety exit triggers after the configured maximum hold in D1 bars.

## Data Contract
The EA uses Darwinex MT5/DWX bars only. There are no web calls, external APIs, ML models, or CSV dependencies. `SP500.DWX` is signal-only; `XTIUSD.DWX` is the preferred oil signal and `XBRUSD.DWX` is fallback.

## Symbols and Slots
- slot 0: `XAUUSD.DWX`, magic `11850000`

## Risk
- Backtest default: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Live template: `RISK_PERCENT=0.25`, `RISK_FIXED=0`

## Notes
`SP500.DWX` remains a T6 live-promotion caveat per the Strategy Card. Before live AutoTrading, parallel validation on a routable equity-stress proxy such as `NDX.DWX` or `WS30.DWX` is required.
