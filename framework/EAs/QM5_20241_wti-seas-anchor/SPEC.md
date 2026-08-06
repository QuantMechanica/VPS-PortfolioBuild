# QM5_20241_wti-seas-anchor - Strategy Spec

**EA ID:** QM5_20241

**Slug:** `wti-seas-anchor`

**Source:** `BURAKOV-BIANCHI-WTI-SEAS52W-2026`

**Author:** Research+Development

**Last revised:** 2026-08-06

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of every broker month, read exactly
252 completed D1 closes. Let `C0` be the newest close, `H252` and `L252` the
closing high and low in that window, and `C63` the close exactly 63 D1
intervals before `C0`. Buy only in November-May when `C0/H252 >= 0.94` and
`ln(C0/C63) >= 0.02`. Sell only in June-October when `C0/L252 <= 1.08` and
`ln(C0/C63) <= -0.02`. Season/anchor disagreement consumes the month flat.

Close the prior package before every monthly decision. Persist each calendar
month before fallible gates so a blocked, stopped, failed, or flat attempt
cannot retry after restart. Use a frozen `3.5 * ATR(20,D1)` hard stop, no
target, and a forty-day stale guard. Friday close is disabled because the
monthly hold spans weekends.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_winter_first_month` | 11 | Positive physical-season start |
| `strategy_winter_last_month` | 5 | Positive physical-season end |
| `strategy_anchor_lookback_d1` | 252 | Completed closing-extreme window |
| `strategy_confirm_lookback_d1` | 63 | Exact completed return interval |
| `strategy_anchor_long_min` | 0.94 | Minimum winter high proximity |
| `strategy_anchor_short_max` | 1.08 | Maximum summer low distance |
| `strategy_confirm_min_return_pct` | 2.0 | Absolute log-return threshold, percent |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | Maximum WTI entry spread |

Every value is locked for Q02. No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Exact carrier: `XTIUSD.DWX`.
- Magic slot: 0 (`202410000`).
- No companion symbol, futures curve, conversion history, or external input.

## 4. Timeframe

- Exact timeframe: D1.
- Decision clock: first processed D1 bar of every new broker month.
- Formation: exactly 252 completed D1 closes.
- Confirmation: `ln(C0/C63)` from the same synchronized completed-bar array.

## 5. Expected Behaviour

Maximum cadence is twelve consumed decisions per full post-warm-up year. The
predeclared expectation is five to seven completed packages/year; Q02 retires
below five per full post-warm-up year. Exposure normally spans one broker
month. Principal risks are WTI gaps and rolls, futures-to-CFD basis, financing,
anchor regime failure, seasonality decay, filter under-frequency, and realized
book correlation.

## 6. Source Citation

Burakov, D., Freidin, M., and Solovyev, Y. (2018), "The Halloween Effect on
Energy Markets: An Empirical Study," *International Journal of Energy
Economics and Policy* 8(2), 121-126.

Bianchi, R. J., Drew, M. E., and Fan, J. H. (2016), "Commodities momentum: A
behavioural perspective," *Journal of Banking & Finance*, DOI
`10.1016/j.jbankfin.2016.06.010`.

The governed composite packet is
`strategy-seeds/sources/BURAKOV-BIANCHI-WTI-SEAS52W-2026/source.md`; the
approved card is
`strategy-seeds/cards/approved/QM5_20241_wti-seas-anchor_card.md`. The sources
supply the physical-season direction and commodity 52-week anchor lineage,
not this conjunction or its WTI CFD performance.

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
