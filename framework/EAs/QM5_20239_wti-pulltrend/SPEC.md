# QM5_20239_wti-pulltrend - Strategy Spec

**EA ID:** QM5_20239

**Slug:** `wti-pulltrend`

**Source:** `MOP-TSMOM-2012`

**Author:** Research+Development

**Last revised:** 2026-08-06

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of every broker month, reconstruct
fourteen consecutive completed month-end closes. Calculate a twelve-month log
return ending before the newest completed month and the separate newest
one-month log return. Buy only when the older trend is positive and the newest
month is negative; sell only when the older trend is negative and the newest
month is positive. Equal signs, exact zero, or invalid endpoints remain flat
for the consumed month.

Close the prior package before every monthly decision. Persist each calendar
month before fallible gates so a blocked, stopped, failed, or flat attempt
cannot retry after restart. Use a frozen `3.5 * ATR(20,D1)` hard stop, no
target, and a forty-day stale guard. Friday close is disabled because the
monthly hold spans weekends.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_trend_months` | 12 | Older non-overlapping trend interval |
| `strategy_pullback_months` | 1 | Newest completed counter-move interval |
| `strategy_history_bars` | 500 | Bounded D1 month-end reconstruction |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | Maximum WTI entry spread |

Every value is locked for Q02. No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Exact carrier: `XTIUSD.DWX`.
- Magic slot: 0 (`202390000`).
- No companion symbol, conversion history, or external runtime input.

## 4. Timeframe

- Exact timeframe: D1.
- Decision clock: first processed D1 bar of every new broker month.
- Formation: fourteen consecutive completed broker-month endpoints.
- Signal intervals: `ln(M1/M13)` for the older trend and `ln(M0/M1)` for the
  newest pullback.

## 5. Expected Behaviour

Maximum cadence is twelve decisions per full post-warm-up year. The
predeclared expectation is five to eight opposite-sign packages/year; Q02
retires below five completed packages/year. Exposure normally spans one
broker month. Principal risks are false pullbacks, filter under-frequency,
WTI gaps and rolls, futures-to-CFD basis, financing, stop-outs, month-end
history quality, and realized book correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The governed source is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the approved card is
`strategy-seeds/cards/approved/QM5_20239_wti-pulltrend_card.md`. The source
supplies the twelve-month own-return trend and monthly cadence, not the
newest-month counter-move conjunction or WTI CFD performance.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes and Friday close are OFF. Every trade has
a server-side ATR hard stop. There is no manual backtest, live/demo/shadow
setfile, live authorization, deploy manifest, portfolio admission, or
portfolio-gate change.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-06 | Initial build from approved G0 card | Q01 strict compile/build PASS; 0 errors, warnings, failures, or build warnings |
