# QM5_41088 XAU/XAG Weekly Close-Location Divergence Reversion

## Identity

- EA: `QM5_41088_xauxag-wclv-div-rv`
- strategy: `SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026_S01`
- host: exact `XAUUSD.DWX`, D1, slot 0, magic `410880000`
- companion: exact `XAGUSD.DWX`, D1, slot 1, magic `410880001`
- logical symbol: `QM5_41088_XAU_XAG_WCLVDIV_RV_D1`

## Entry Contract

On the first tradable D1 bar of a new normalized Monday-anchored broker week,
consume one durable attempt and aggregate every synchronized XAU/XAG D1 OHLC
pair from the immediately preceding completed week. Require three to five
unique sessions and exact timestamp agreement.

For each leg compute
`clv=(completed_week_close-completed_week_low)/(completed_week_high-completed_week_low)`.
Sell XAU and buy XAG only on strict `xau_clv>2/3 && xag_clv<1/3`; buy XAU and
sell XAG only on strict `xau_clv<1/3 && xag_clv>2/3`. Equality, an interior
state, invalid range, incomplete history, or asynchrony is flat.

## Risk And Lifecycle

- fixed backtest risk: `RISK_FIXED=1000`; `RISK_PERCENT=0`; weight 1;
- target absolute entry-notional ratio: 1:1, maximum mismatch 20 percent;
- frozen stop on each leg: `3.5*ATR(20,D1)`; no take profit;
- maximum spreads: 1,500 XAU points and 500 XAG points;
- one package and one attempt per broker week;
- close on the first tick of a later broker week;
- ten-calendar-day stale repair;
- news OFF and Friday close OFF.

No current-week price enters the signal. No retry, optimization surface,
ratio center, fitted beta, return filter, scale-in, grid, martingale, pyramid,
trail, break-even move, partial close, external runtime feed, banned signal,
or trained logic is authorized.

## Validation

Reference tests must cover exact week aggregation, session bounds, final-close
selection, independent CLVs, both valid sides, boundary equality, interior and
same-tercile states, zero ranges, timestamp mismatch, week labels, persistent
attempts, equal-notional sizing, atomic repair, and next-week lifecycle. Strict
compile, resolver validation, canonical fixed-risk setfile validation, basket
manifest validation, and static Q01 validation must pass before Q02.
