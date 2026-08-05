# QM5_20226 wti-seas-dow - Strategy Spec

**EA ID:** QM5_20226

**Slug:** `wti-seas-dow`

**Source:** `BURAKOV-GORSKA-WTI-SEASDOW-2026`

**Author:** Research+Development

**Last revised:** 2026-08-05

## 1. Strategy Logic

At the first observed `XTIUSD.DWX` D1 tick, buy a genuine Friday during the
positive November-May physical season or sell a genuine Monday during the
negative June-October physical season. A genuine Friday follows a Thursday
D1 bar; a genuine Monday follows a Friday D1 bar. Entry must occur within five
minutes of broker D1 open, and the broker day is consumed before history and
fallible entry gates so an attempt cannot retry after restart.

Close a Friday long using the framework broker-hour-21 Friday control. Close a
Monday short at the first following D1 boundary. Close a wrong-side position
immediately and retain a three-calendar-day stale guard. Use a frozen
`3.0 * ATR(20,D1)` server-side hard stop, no target, and no price filter.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_winter_first_month` | 11 | Positive-season start |
| `strategy_winter_last_month` | 5 | Positive-season end |
| `strategy_summer_first_month` | 6 | Negative-season start |
| `strategy_summer_last_month` | 10 | Negative-season end |
| `strategy_long_weekday` | 5 | Friday BUY event |
| `strategy_short_weekday` | 1 | Monday SELL event |
| `strategy_entry_grace_minutes` | 5 | Maximum broker-open delay |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.0 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 3 | Missed-exit stale guard |
| `strategy_max_spread_points` | 1500 | Maximum entry spread |

Every value is locked for Q02. No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Exact carrier: `XTIUSD.DWX`.
- Magic slot: 0 (`202260000`).
- No companion symbol, conversion history, or external runtime input.

## 4. Timeframe

- Exact timeframe: D1.
- Long clock: genuine Friday in November-May.
- Short clock: genuine Monday in June-October.
- Ordinary exposure: one broker session.

## 5. Expected Behaviour

The predeclared expectation is 42-50 completed packages/year after holidays;
Q02 retires below five completed packages/year. Principal risks are omitted
overnight return, broker weekday/session mapping, WTI gaps and rolls,
futures-to-CFD basis, financing, source and interaction decay, and realized
book correlation. This build makes no profitability, decorrelation,
certification, or portfolio-admission claim.

## 6. Source Citation

Burakov, D., Freidin, M., and Solovyev, Y. (2018), "The Halloween Effect on
Energy Markets: An Empirical Study," *International Journal of Energy
Economics and Policy* 8(2), 121-126. Gorska, A., and Krawiec, M. (2015),
"Calendar Effects in the Market of Crude Oil," *Problems of World
Agriculture* 15(4), 62-70, DOI `10.22630/PRS.2015.15.4.54`.

The governed composite is
`strategy-seeds/sources/BURAKOV-GORSKA-WTI-SEASDOW-2026/source.md`; the
approved execution contract is
`strategy-seeds/cards/approved/QM5_20226_wti-seas-dow_card.md`. The sources
supply the two parent calendar directions, not this conjunction's WTI CFD or
portfolio performance.

## 7. Risk Model

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes and legacy news mode are OFF; framework
Friday close is enabled at broker hour 21. There is no manual backtest,
live/demo/shadow setfile, live authorization, deploy manifest, portfolio
admission, or portfolio-gate change.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-05 | Initial build from approved G0 card | Q01 strict compile/build PASS; 0 errors, warnings, failures, or build warnings |
