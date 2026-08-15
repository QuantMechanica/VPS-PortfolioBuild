# QM5_41014_xtixng-thu-rv

**EA ID:** QM5_41014

**Source strategy:** `MEEK-HOELSCHER-XTIXNG-THU-2026_S01`

## 1. Strategy Logic

On the first executable tick of a synchronized genuine broker-Thursday D1
bar, consume one Monday-anchored weekly attempt and open an approximately
equal-USD-notional basket: BUY `XTIUSD.DWX` and SELL `XNGUSD.DWX`. Close the
complete package at broker Thursday hour 21. Any partial, malformed,
wrong-direction, missing-stop, stale, or materially notional-mismatched
package is flattened immediately.

Meek and Hoelscher report near-zero WTI Thursday coefficients and negative,
significant natural-gas Thursday coefficients across their asymmetric-
variance models. They do not test this pair, covariance, Darwinex CFDs,
equal-notional sizing, or costs. This EA is a locked Q02 falsification, not a
neutrality or performance claim.

## 2. Parameters

- Thursday entry: `day_of_week=4`, opening grace 5 minutes, completed
  predecessor Wednesday.
- Risk stops: completed-bar ATR(20), multiplier 3.5 on each leg.
- Hedge: XTI:XNG absolute USD notional target 1.0, mismatch cap 15%.
- Entry spread caps: 1,500 XTI points and 3,000 XNG points.
- Lifecycle: broker Thursday hour 21, first-non-Thursday repair, and a
  three-calendar-day maximum-hold guard.
- All parameters are locked; no Q02 sweep is authorized.

## 3. Symbol Universe

- Host and slot 0: `XTIUSD.DWX`, BUY, magic `410140000`.
- Foreign leg and slot 1: `XNGUSD.DWX`, SELL, magic `410140001`.
- Logical tester symbol: `QM5_41014_XTI_XNG_THU_RV_D1`.

The `basket_manifest.json` is authoritative for Q02 fanout and combined-PnL
evaluation. Standalone WTI or natural-gas results are invalid.

## 4. Timeframe

The EA runs only on an `XTIUSD.DWX` D1 chart. It requires synchronized current
XTI and XNG D1 bars, at least 20 completed D1 observations, and a completed
Wednesday predecessor. Missing or shifted Thursdays are not substituted.

## 5. Expected Behaviour

Before market/data filters, the EA consumes at most one attempt on each
genuine broker Thursday. It expects roughly 45-52 completed logical packages
per full year, subject to holidays and fail-closed gates. Both legs normally
remain open only for the Thursday session and close together at broker hour
21.

Q02 must retire the strategy below five packages per year, for zero trades,
for invalid timing or basket state, or for governed performance failure.

## 6. Source Citation

Meek, A. C. and Hoelscher, S. A. (2023), "Day-of-the-week effect: Petroleum
and petroleum products," *Cogent Economics & Finance* 11(1), 2213876, DOI
`10.1080/23322039.2023.2213876`.

The governed source packet is
`strategy-seeds/sources/MEEK-HOELSCHER-XTIXNG-THU-2026/source.md`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and weight 1. The two ATR
stops share one aggregate risk budget; the fixed amount is not applied once
per leg. Lots are rounded down and the package is rejected if either minimum
lot or the 15% notional tolerance cannot be satisfied.

This build has no live preset or live authorization. AutoTrading, T_Live,
deploy manifests, portfolio admission, and portfolio-gate changes are outside
scope.
