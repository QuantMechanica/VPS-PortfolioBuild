# QM5_1183 qp-boxppi-sp500-risk

## Intent
Quantpedia Box Manufacturing PPI SP500 risk-switch strategy. The EA opens or keeps a long `SP500.DWX` position when the lagged monthly corrugated-box PPI is below its moving average, and exits to cash when the monthly condition turns off.

## Framework Alignment
- No-Trade: blocks all symbols except `SP500.DWX`, all timeframes except `D1`, nonzero magic slots, invalid strategy parameters, insufficient D1 history, and optional max-spread breaches.
- Entry: on the first D1 bar of a new month, reads the local deterministic PPI CSV, applies the configured publication lag, computes the PPI SMA, and opens one long position when lagged PPI is below the SMA.
- Management: no trailing stop or partial close; the card specifies an initial ATR stop and monthly signal control.
- Close: re-evaluates monthly only; closes when the lagged PPI value is greater than or equal to its SMA.

## Data Contract
`strategy_ppi_csv_path` must point to a local or terminal-common CSV. Expected minimal columns: `date,ppi`, where the PPI series is `PCU3222113222110`. Rows with invalid dates or non-positive PPI values are ignored. The EA never performs web or external API calls.

## Symbols and Slots
- slot 0: `SP500.DWX`, magic `11830000`

## Risk
- Backtest default: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Live template: `RISK_PERCENT=0.25`, `RISK_FIXED=0`

## Notes
`SP500.DWX` remains a T6 live-promotion caveat per the Strategy Card. Before live AutoTrading, parallel validation on a routable proxy such as `NDX.DWX` or `WS30.DWX` is required by the card.
