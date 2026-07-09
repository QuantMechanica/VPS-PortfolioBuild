# Source Packet - EIA-CME-USGS-XTI-XCU-BRK-2026

## Scope

This packet supports one D1 `XTIUSD.DWX` / `XCUUSD.DWX` channel-breakout
basket. The EA uses only Darwinex MT5 OHLC, spread, ATR, broker time, and V5
framework state at runtime.

## Primary Sources

- U.S. Energy Information Administration. "What drives crude oil prices: Spot
  Prices." URL: https://www.eia.gov/finance/markets/crudeoil/spot_prices.php.
  Role: primary structural lineage for crude-oil price sensitivity to supply,
  demand, spare capacity, and geopolitical shocks.
- CME Group. "Copper Futures." URL:
  https://www.cmegroup.com/markets/metals/base/copper.html. Role: exchange
  reference for copper as a benchmark base-metal and industrial commodity risk
  leg.
- U.S. Geological Survey. "Copper Statistics and Information." URL:
  https://www.usgs.gov/centers/national-minerals-information-center/copper-statistics-and-information.
  Role: government reference for copper supply, demand, and materials-flow
  context.

## Implementation Lineage

- Donchian/Turtle-style channel breakout lineage is used only to mechanize
  persistent spread divergence. The card does not import any source performance
  claim and does not optimize parameters on live PnL.

## V5 Allowability

- R1 reputable source: PASS - one lineage packet with official EIA crude-oil
  source plus official CME/USGS copper references.
- R2 mechanical: PASS - fixed D1 log spread, fixed entry and exit channels,
  paired market-neutral entry, ATR hard stops, spread caps, max-hold exit, and
  broken-package repair.
- R3 data available: PASS - `XTIUSD.DWX` is in the DWX matrix and recent V5
  builds already use `XCUUSD.DWX`; Q02 must validate synchronized XTI/XCU D1
  history and fills.
- R4 ML forbidden: PASS - no ML, adaptive PnL fitting, external runtime data,
  grid, martingale, or discretionary input.

## Non-Duplicate Check

- Not `QM5_13090_xti-xcu-rspread`: this card trades price-level log-spread
  channel continuation; 13090 fades fixed-window return-spread z-score
  extremes.
- Not `QM5_13073_xti-audusd-rspr`, `QM5_13034_xti-audcad-rspr`, or other
  commodity-FX baskets: this pairs WTI directly against copper, not a currency.
- Not `QM5_13080_xcu-donchian55` or `QM5_13081_xcu-4w-reversal`: this is a
  two-leg relative-value package, not solo copper trend or reversal.
- Not oil/gold, oil/silver, XTI/XNG, WTI event, inventory, seasonality, roll,
  COT, OPEC, IEA, JODI, or commodity-RSI logic.
