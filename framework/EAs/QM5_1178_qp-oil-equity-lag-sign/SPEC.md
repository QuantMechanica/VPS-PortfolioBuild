# QM5_1178 qp-oil-equity-lag-sign

## Strategy

Quantpedia Oil-Lag Equity Timing Sign Rule. On the first tradable day of a new month, the EA reads the previous completed month's crude-oil return. If oil return is below the configured threshold, it holds a long equity-index position for the next month; otherwise it remains flat or exits.

## Framework Alignment

- No-Trade: blocks wrong symbol, non-D1 timeframe, magic-slot mismatch, invalid strategy inputs, missing oil/equity symbols, and optional spread cap.
- Entry: first D1 bar of each new month, previous-month `XTIUSD.DWX` return or local CSV fallback, long-only when oil return is below threshold.
- Management: no trailing or discretionary management; the card specifies fixed ATR stop and monthly/safety exits.
- Exit: close on next monthly rebalance when the oil signal is no longer bullish for equities, or when equity loses `strategy_safety_stop_pct` from entry.
- Risk: framework risk contract, backtest fixed cash risk and live percent risk through setfiles.
- Magic: slots `0..2` for `SP500.DWX`, `NDX.DWX`, `WS30.DWX`.

## Data Contract

Primary oil signal uses MT5 monthly bars for `XTIUSD.DWX`. If monthly bars are unavailable, the EA attempts to read `QM5_1178_oil_monthly_returns.csv` from terminal Files/Common Files. Expected CSV columns are:

```text
date,oil_return
2026-04-30,-0.0123
```

No web/API calls are used.

## Caveats

`SP500.DWX` is the canonical trade leg from the card but remains a T6 live-promotion caveat. `NDX.DWX` and `WS30.DWX` setfiles exist for later parallel validation before any live deployment decision.

No backtests or pipeline phases were run during build.
