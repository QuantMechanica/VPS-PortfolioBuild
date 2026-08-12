# QM5_20048 — WTI Pre-Holiday Sentiment Sleeve

**EA ID:** QM5_20048

## 1. Strategy Logic

Buy WTI on the last tradable D1 session before observed New Year, Presidents
Day, Good Friday, Memorial Day, Independence Day, Labor Day, Thanksgiving, and
Christmas. Exit on the first subsequent D1 bar. One attempt is allowed per
holiday; there is no retry, pyramid, grid, martingale, or ML logic.

## 2. Parameters

ATR period 20, ATR stop multiplier 3.0, maximum hold four calendar days, and
maximum entry spread 1,200 points. Holiday set, long direction, and timing are
locked. Declared research ranges live in the approved card.

## 3. Symbol Universe

Only `XTIUSD.DWX`, magic slot 0.

## 4. Timeframe

`D1`; all calendar decisions occur once per new broker D1 bar.

## 5. Expected Behaviour

Approximately eight completed packages per year before framework exclusions.
Q02 retires the strategy below five packages/year or on governed economics.

## 6. Source Citation

Qadan, M., Aharon, D. Y., and Eichel, R. (2019), “Seasonal patterns and
calendar anomalies in the commodity market for natural resources,” Resources
Policy 63, 101435, DOI `10.1016/j.resourpol.2019.101435`.

## 7. Risk Model

Backtest mode uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A frozen ATR hard stop protects each package. No live set
or deployment artifact is part of this build.
