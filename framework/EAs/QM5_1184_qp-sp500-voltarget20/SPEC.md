# QM5_1184 qp-sp500-voltarget20

## Intent
Quantpedia / Harvey et al. SP500 volatility-targeting strategy. The EA stays long `SP500.DWX` and scales the base framework risk by a deterministic 20-day-half-life realized-volatility exposure multiplier.

## Framework Alignment
- No-Trade: blocks all symbols except `SP500.DWX`, all timeframes except `D1`, nonzero magic slots, invalid parameters, insufficient D1 history, disabled trading, and optional max-spread breaches.
- Entry: on each completed D1 bar, computes exponentially weighted realized volatility from daily log returns, converts it to annualized volatility, clamps `target_annual_vol / realized_annual_vol` to `[0.25, 1.00]`, configures the V5 RiskSizer with the scaled base risk, and opens one long position with ATR(20) * 3.0 initial stop.
- Management: updates the ATR(20) * 3.0 trailing stop once per completed D1 bar.
- Close: closes if annualized realized volatility exceeds 40% for three consecutive completed D1 bars, or when the current target exposure differs from the stored position exposure by at least 25%; the next entry pass can then reopen at the updated risk scale.

## Data Contract
Uses only native Darwinex/MT5 `SP500.DWX` D1 OHLC bars. No external files, web calls, ML models, or APIs are required.

## Symbols and Slots
- slot 0: `SP500.DWX`, magic `11840000`

## Risk
- Backtest default: `RISK_FIXED=1000`, `RISK_PERCENT=0`, multiplied by the clamped exposure.
- Live template: `RISK_PERCENT=0.25`, `RISK_FIXED=0`, multiplied by the clamped exposure.

## Notes
`SP500.DWX` remains a T6 live-promotion caveat per the Strategy Card. If the EA passes the pipeline on `SP500.DWX`, live deployment requires parallel validation on a routable proxy such as `NDX.DWX` or `WS30.DWX`.
