# Source Packet - EIA-CME-USGS-XTI-XCU-RSPREAD-2026

## Scope

This packet supports one D1 `XTIUSD.DWX` / `XCUUSD.DWX` return-spread
reversion basket. The EA uses only Darwinex MT5 OHLC, spread, ATR, broker time,
and V5 framework state at runtime.

## Primary Sources

- U.S. Energy Information Administration. "What drives crude oil prices: Spot
  Prices." URL: https://www.eia.gov/finance/markets/crudeoil/spot_prices.php.
  Quality tier: A government energy-market explainer. Role: primary structural
  lineage for crude oil price volatility, short-run supply/demand inelasticity,
  and event-sensitive WTI exposure.
- CME Group. "Copper Futures." URL:
  https://www.cmegroup.com/markets/metals/base/copper.html. Quality tier: A
  exchange product reference. Role: confirms copper as a benchmark base-metal
  futures market and industrial commodity risk leg.
- U.S. Geological Survey. "Copper Statistics and Information." URL:
  https://www.usgs.gov/centers/national-minerals-information-center/copper-statistics-and-information.
  Quality tier: A government commodity reference. Role: confirms copper
  supply, demand, and materials-flow context.

## Implementation Lineage

- Chan, Ernest P. Algorithmic Trading: Winning Strategies and Their Rationale,
  Wiley, 2013. Role: pair-spread mean-reversion implementation lineage. The
  V5 card uses deterministic fixed-window return-spread z-scores instead of
  external regression, ML, or runtime data imports.

## V5 Allowability

- R1 reputable source: PASS - official EIA crude-oil source plus official CME
  and USGS copper references, with Chan pair-spread implementation lineage.
- R2 mechanical: PASS - fixed D1 return lookback, rolling z-score, paired
  market-neutral entry, ATR hard stops, spread caps, max-hold exit, and
  broken-package repair.
- R3 data available: PASS - `XTIUSD.DWX` is in the DWX matrix and recent V5
  builds already use `XCUUSD.DWX`; Q02 must validate synchronized XTI/XCU D1
  history and fills.
- R4 ML forbidden: PASS - no ML, adaptive PnL fitting, external runtime data,
  grid, martingale, or discretionary input.

## Non-Duplicate Check

- Not `QM5_13073_xti-audusd-rspr`, `QM5_13034_xti-audcad-rspr`, or other
  commodity-FX baskets: this pairs WTI directly against copper, not a currency.
- Not `QM5_13080_xcu-donchian55` or `QM5_13081_xcu-4w-reversal`: this is a
  two-leg relative-value package, not solo copper trend or reversal.
- Not `QM5_12863_oilgold-rspread`, `QM5_12864_oilsilver-rspr`, or
  `QM5_13053_brentsilver-rspr`: this uses copper as the hedge leg and WTI as
  the energy leg.
- Not `QM5_12840_xti-xng-rspread` or `QM5_13089_xti-xng-carry`: this is not
  natural-gas relative value or broker-swap carry ranking.
- Not WTI event, inventory, seasonality, roll, COT, OPEC, IEA, JODI, or
  commodity-RSI logic.
