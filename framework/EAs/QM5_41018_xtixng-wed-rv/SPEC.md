# QM5_41018_xtixng-wed-rv

**EA ID:** QM5_41018

**Source strategy:** `LI-BOROWSKI-XTIXNG-WED-2026_S01`

## 1. Strategy Logic

On the first executable tick of a synchronized genuine broker-Wednesday D1
bar, consume one Monday-anchored weekly attempt and open an approximately
equal-USD-notional basket: BUY `XTIUSD.DWX` and SELL `XNGUSD.DWX`. Close the
complete package at broker Wednesday hour 21. Any partial, malformed,
wrong-direction, missing-stop, stale, or materially notional-mismatched
package is flattened immediately.

Li et al. report positive WTI Wednesday behavior; Borowski reports negative
natural-gas Wednesday behavior. Meek and Hoelscher's newer natural-gas
Wednesday results have the opposite sign and are insignificant, so source
conflict is a binding Q02 kill risk. No source tests this pair, covariance,
Darwinex CFDs, equal-notional sizing, or costs. This EA is a locked
falsification, not a neutrality or performance claim.

## 2. Parameters

- Wednesday entry: `day_of_week=3`, opening grace 5 minutes, completed
  predecessor Tuesday.
- Risk stops: completed-bar ATR(20), multiplier 3.5 on each leg.
- Hedge: XTI:XNG absolute USD notional target 1.0, mismatch cap 10%.
- Entry spread caps: 2,500 points on both XTI and XNG.
- Lifecycle: broker Wednesday hour 21, first-non-Wednesday repair, and a
  three-calendar-day maximum-hold guard.
- All parameters are locked; no Q02 sweep is authorized.

## 3. Symbol Universe

- Host and slot 0: `XTIUSD.DWX`, BUY, magic `410180000`.
- Foreign leg and slot 1: `XNGUSD.DWX`, SELL, magic `410180001`.
- Logical tester symbol: `QM5_41018_XTI_XNG_WED_RV_D1`.

The `basket_manifest.json` is authoritative for Q02 fanout and combined-PnL
evaluation. Standalone WTI or natural-gas results are invalid.

## 4. Timeframe

The EA runs only on an `XTIUSD.DWX` D1 chart. It requires synchronized current
XTI and XNG D1 bars, at least 20 completed D1 observations, and a completed
Tuesday predecessor. Missing or shifted Wednesdays are not substituted.

## 5. Expected Behaviour

Before market/data filters, the EA consumes at most one attempt on each
genuine broker Wednesday. It expects roughly 45-52 completed logical packages
per full year, subject to holidays and fail-closed gates. Both legs normally
remain open only for the Wednesday session and close together at broker hour
21.

Q02 must retire the strategy below five packages per year, for zero trades,
for invalid timing or basket state, or for governed performance failure.

## 6. Source Citations

- Li, W., Zhu, Q., Wen, F., and Mohd Nor, N. (2022), "The evolution of
  day-of-the-week and the implications in crude oil market," *Energy
  Economics* 106, 105817, DOI `10.1016/j.eneco.2022.105817`.
- Borowski, K. (2016), "Analysis of Selected Seasonality Effects in Markets
  of Future Contracts," *Journal of Management and Financial Sciences* 26,
  27-44.
- Meek, A. C. and Hoelscher, S. A. (2023), "Day-of-the-week effect: Petroleum
  and petroleum products," *Cogent Economics & Finance* 11(1), 2213876, DOI
  `10.1080/23322039.2023.2213876` (adverse evidence).

The governed packet is
`strategy-seeds/sources/LI-BOROWSKI-XTIXNG-WED-2026/source.md`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and weight 1. The two ATR
stops share one aggregate risk budget; the fixed amount is not applied once
per leg. Lots are rounded down and the package is rejected if either minimum
lot or the 10% notional tolerance cannot be satisfied.

This build has no live preset or live authorization. AutoTrading, T_Live,
deploy manifests, portfolio admission, and portfolio-gate changes are outside
scope.
