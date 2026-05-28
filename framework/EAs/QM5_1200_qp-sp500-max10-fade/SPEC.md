# QM5_1200 qp-sp500-max10-fade

## Intent
Quantpedia / Hanicova SP500 10-day maximum fade. The EA shorts `SP500.DWX` after a completed D1 close equals the highest D1 close of the last 10 completed bars, then exits after one trading day near the regular-session close.

## Framework Alignment
- No-Trade: blocks all symbols except `SP500.DWX`, all timeframes except `D1`, nonzero magic slots, disabled trading, invalid parameters, and insufficient D1 history.
- Entry: on the first tick of the next D1 bar after the signal, checks that the latest completed D1 close is the rolling 10-day maximum, verifies current spread is not above `3x` the previous 20-day M30 median spread, and opens one short with ATR(20) * 2.0 initial stop.
- Management: no trailing or partial close; the card specifies fixed holding and hard ATR stop only.
- Close: closes after one trading day once the broker-time session-close threshold is reached. A P3 toggle can instead close on first completed D1 close below SMA(10).

## Data Contract
Uses only native Darwinex/MT5 `SP500.DWX` D1 and M30 bars. No external files, web calls, ML models, or APIs are required.

## Symbols and Slots
- slot 0: `SP500.DWX`, magic `12000000`

## Risk
- Backtest default: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live template: `RISK_PERCENT=0.25`, `RISK_FIXED=0`.

## Notes
`SP500.DWX` remains a T6 live-promotion caveat per the Strategy Card. If the EA passes the pipeline on `SP500.DWX`, live deployment requires parallel validation on a routable proxy such as `NDX.DWX` or `WS30.DWX`.
