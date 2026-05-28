# QM5_1167_qp-inflation-gold-bond

## Card Mapping
- Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1167_qp-inflation-gold-bond.md`
- Status: APPROVED
- Tradeable symbol: `XAUUSD.DWX`
- Timeframe: D1
- Runtime macro source: local versioned CSV only, default `QM5_1167_inflation_gold_bond.csv`.

## Strategy
- Monthly rebalance after the configured CPI publication lag.
- Read the latest non-lookahead inflation regime from local CSV.
- Compute 12-month D1 momentum on `XAUUSD.DWX`.
- Enter or maintain long gold only when inflation is accelerating and gold momentum is positive.
- If inflation is decelerating and Treasury-proxy momentum is positive, log `BOND_SIGNAL_ON` for research reporting only; no bond/rates leg is traded in this build.
- Exit gold at monthly rebalance when the accelerating-inflation plus positive-gold-momentum condition is no longer true.

## Risk And Stops
- Backtest default: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live default in live set: `RISK_PERCENT=0.25`, `RISK_FIXED=0`.
- Initial hard stop: `5.0 * ATR(20)` on D1.

## Framework Alignment
- No-Trade: symbol, timeframe, parameter, spread, framework kill-switch/news/Friday-close checks.
- Entry: monthly CPI-regime plus 12M gold momentum.
- Management: no trailing, scale-out, pyramiding, or stop mutation.
- Close: monthly signal failure.

## Notes
- No web or external API access is used.
- The CSV parser expects at least three fields per row: date, inflation regime, Treasury momentum. Regime accepts deterministic values such as `ACCELERATING` or `DECELERATING`.
- No backtests or pipeline phases are part of this build.
