# Build-Time Strategy Card — QM5_20192_xauxag-ivol

The complete OWNER-authorized G0 card is
`strategy-seeds/cards/xauxag-ivol_card.md`; the durable approved copy is
`strategy-seeds/cards/approved/QM5_20192_xauxag-ivol_card.md`.

## Hypothesis

Trade the monthly XAU/XAG low-minus-high factor-residual-volatility rank as an
opposite two-leg basket.

## Rules

Use 252 synchronized completed D1 returns, an equal-weight
XTI/XNG/XAU/XAG factor, separate intercept-plus-factor OLS residual standard
deviations, long lower XAU/XAG IVol, short higher, frozen ATR(20) times 3.0
stops, equal-notional risk translation, 20% rounding-mismatch cap, one
persisted attempt per month, next-month close, and 35-day stale close.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`. No live artifact or
portfolio authority is included.
