# QM5_20095_auag-mon-diff

**EA ID:** QM5_20095

**Source strategy:** `LUCEY-TULLY-DOW-2006_S01`

## 1. Strategy Logic

On the first executable tick of a synchronized broker-Monday D1 bar, consume
one daily attempt and open an equal-USD-notional basket: BUY
`XAUUSD.DWX` and SELL `XAGUSD.DWX`. Close the complete package at the first
following XAU D1 boundary. Any partial, malformed, or materially
notional-mismatched package is flattened immediately.

The source reports weak/non-robust individual Monday mean effects and does not
test this relative-value translation. The strategy is a locked Q02
falsification candidate.

## 2. Parameters

- Monday entry: `day_of_week=1`, opening grace 15 minutes.
- Risk stops: completed-bar ATR(20), multiplier 3.0 on each leg.
- Hedge: XAU:XAG absolute USD notional target 1.0, mismatch cap 20%.
- Entry spread caps: 1500 XAU points and 500 XAG points.
- Lifecycle: first following D1 boundary, three-calendar-day stale guard,
  framework Friday emergency close at broker hour 21.
- All parameters are locked; no Q02 sweep is authorized.

## 3. Symbol Universe

- Host and slot 0: `XAUUSD.DWX`, BUY.
- Foreign leg and slot 1: `XAGUSD.DWX`, SELL.
- Logical tester symbol: `QM5_20095_XAU_XAG_MON_DIFF_D1`.

The `basket_manifest.json` is authoritative for Q02 fanout and combined-PnL
evaluation.

## 4. Timeframe

The EA runs only on an `XAUUSD.DWX` D1 chart. It requires a synchronized
current XAG D1 bar and completed D1 ATR history for both legs.

## 5. Expected Behaviour

Before market/data filters, the EA consumes at most one attempt on each
genuine broker Monday. It expects roughly 45-52 completed packages per full
year, subject to holidays and fail-closed gates. Both legs normally remain
open for one D1 session and close together at Tuesday's first host tick.

Q02 must retire the strategy below five packages per year, for zero trades,
for invalid timing or basket state, or for governed performance failure.

## 6. Source Citation

Lucey, B. M. and Tully, E. (2006), "Seasonality, risk and return in daily
COMEX gold and silver data 1982-2002," *Applied Financial Economics* 16(4),
319-333, DOI `10.1080/09603100500386586`.

The complete reviewed source record is
`strategy-seeds/sources/LUCEY-TULLY-DOW-2006/source.md`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and weight 1. The two ATR
stops share one aggregate risk budget; the fixed amount is not applied once
per leg. Lots are rounded down and the package is rejected if either minimum
lot or the notional tolerance cannot be satisfied.

This build has no live preset or live authorization. AutoTrading, T_Live,
deploy manifests, portfolio admission, and portfolio-gate changes are outside
scope.
