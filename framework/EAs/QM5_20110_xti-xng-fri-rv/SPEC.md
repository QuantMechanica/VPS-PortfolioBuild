# QM5_20110_xti-xng-fri-rv

**EA ID:** QM5_20110

**Source strategy:** `MEEK-HOELSCHER-ENERGY-DOW-2023_S04`

## 1. Strategy Logic

On the first executable tick of a synchronized broker-Friday D1 bar, consume
one daily attempt and open an equal-USD-notional basket: BUY `XTIUSD.DWX` and
SELL `XNGUSD.DWX`. Close the complete package at broker Friday hour 21. Any
partial, malformed, wrong-direction, missing-stop, stale, or materially
notional-mismatched package is flattened immediately.

Meek and Hoelscher report positive, significant WTI Friday coefficients and
negative, insignificant natural-gas Friday coefficients across their five
conditional-variance models. They do not test this pair, its covariance,
Darwinex CFDs, equal-notional sizing, or transaction-cost profitability. This
EA is therefore a locked Q02 falsification candidate, not a neutrality or
performance claim.

## 2. Parameters

- Friday entry: `day_of_week=5`, opening grace 5 minutes.
- Risk stops: completed-bar ATR(20), multiplier 3.0 on each leg.
- Hedge: XTI:XNG absolute USD notional target 1.0, mismatch cap 20%.
- Entry spread caps: 1000 XTI points and 2500 XNG points.
- Lifecycle: broker Friday hour 21, first-following-D1 stale repair, and a
  three-calendar-day maximum-hold guard.
- All parameters are locked; no Q02 sweep is authorized.

## 3. Symbol Universe

- Host and slot 0: `XTIUSD.DWX`, BUY.
- Foreign leg and slot 1: `XNGUSD.DWX`, SELL.
- Logical tester symbol: `QM5_20110_XTI_XNG_FRI_RV_D1`.

The `basket_manifest.json` is authoritative for Q02 fanout and combined-PnL
evaluation. Standalone WTI or natural-gas results are invalid.

## 4. Timeframe

The EA runs only on an `XTIUSD.DWX` D1 chart. It requires synchronized current
XTI and XNG D1 bars, at least 20 completed D1 observations, and no completed
bar gap longer than three calendar days.

## 5. Expected Behaviour

Before market/data filters, the EA consumes at most one attempt on each
genuine broker Friday. It expects roughly 45-52 completed packages per full
year, subject to holidays and fail-closed gates. Both legs normally remain
open for the Friday session and close together at broker hour 21.

Q02 must retire the strategy below five packages per year, for zero trades,
for invalid timing or basket state, or for governed performance failure.

## 6. Source Citation

Meek, A. C. and Hoelscher, S. A. (2023), "Day-of-the-week effect: Petroleum
and petroleum products," *Cogent Economics & Finance* 11(1), 2213876, DOI
`10.1080/23322039.2023.2213876`.

The complete reviewed source record is
`strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and weight 1. The two ATR
stops share one aggregate risk budget; the fixed amount is not applied once
per leg. Lots are rounded down and the package is rejected if either minimum
lot or the notional tolerance cannot be satisfied.

This build has no live preset or live authorization. AutoTrading, T_Live,
deploy manifests, portfolio admission, and portfolio-gate changes are outside
scope.
