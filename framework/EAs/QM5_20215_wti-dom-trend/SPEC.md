# QM5_20215_wti-dom-trend - Strategy Spec

**EA ID:** QM5_20215

**Slug:** wti-dom-trend

**Source:** BOROWSKI-MOP-WTI-DOMTREND-2026

**Author:** Research+Development

**Last revised:** 2026-08-04

## 1. Strategy Logic

On an XTIUSD.DWX D1 bar dated exactly broker-calendar day 1, buy only when
the completed 252-D1 log return is strictly positive. On an exact day-26 D1
bar, sell only when that return is strictly negative. Read Close[1] and
Close[253], never the current bar, and never shift a missing date.

Consume each exact-date decision before fallible gates. Close on the first
following D1 bar, with a one-calendar-day stale guard. Freeze a
2.75 times ATR(20,D1) hard stop, use no profit target, and retain the
framework Friday close at broker hour 21.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| strategy_long_day | 1 | Exact positive-trend long date |
| strategy_short_day | 26 | Exact negative-trend short date |
| strategy_momentum_lookback_d1 | 252 | Completed own-return horizon |
| strategy_min_abs_return_pct | 0.0 | Strict sign with no deadband |
| strategy_entry_grace_minutes | 5 | Exact D1-open attachment window |
| strategy_atr_period | 20 | Completed D1 ATR estimator |
| strategy_atr_sl_mult | 2.75 | Frozen hard-stop distance |
| strategy_max_hold_days | 1 | One-day stale guard |
| strategy_max_spread_points | 2500 | Maximum WTI entry spread |

Every value is locked for Q02. No baseline parameter sweep or neighboring
date substitution is authorized.

## 3. Symbol Universe

- Exact carrier: XTIUSD.DWX.
- Magic slot: 0 (202150000).
- No companion symbol, conversion-only history, or external runtime input.

## 4. Timeframe

- Exact timeframe: D1.
- Decision clock: first observed tick within five minutes of an exact day-1
  or day-26 D1 bar.
- Formation: completed D1 Close[1] versus Close[253].
- Lifecycle: first following D1 bar.

## 5. Expected Behaviour

The slow trend normally authorizes one of the two calendar arms per month,
while weekends and holidays remove exact dates. Expected cadence is six to
ten completed packages per full post-warm-up year; Q02 retires below five per
year on average.

The return driver is a sparse physical-crude calendar/trend interaction,
distinct in carrier and clock from the certified XAU, SP500, NDX, and XNG
book. Realized decorrelation is not assumed and remains a downstream gate.

## 6. Source Citation

Borowski, K. (2016), "Analysis of Selected Seasonality Effects in Markets of
Future Contracts," Journal of Management and Financial Sciences 26, 27-44.
Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," Journal of Financial Economics 104(2), 228-250.

The governed composite is
strategy-seeds/sources/BOROWSKI-MOP-WTI-DOMTREND-2026/source.md and the
approved card is
strategy-seeds/cards/approved/QM5_20215_wti-dom-trend_card.md. The papers
supply the numbered-day directions and own-return trend lineage, not this
interaction or any CFD/portfolio performance claim.

## 7. Risk Model

Backtests use RISK_FIXED=1000, RISK_PERCENT=0, and PORTFOLIO_WEIGHT=1. Both
news axes are OFF. Friday close remains enabled at broker hour 21. Every
entry has a server-side ATR hard stop. There is no live/demo/shadow setfile,
live authorization, deploy manifest, portfolio admission, or portfolio-gate
change.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-04 | Initial build from approved G0 card | Q01 strict compile and build check PASS; zero errors and warnings |
