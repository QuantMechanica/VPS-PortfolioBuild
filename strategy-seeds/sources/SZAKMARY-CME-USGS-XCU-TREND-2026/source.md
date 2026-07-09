# Source Packet - SZAKMARY-CME-USGS-XCU-TREND-2026

## Scope

This source packet supports a single-symbol `XCUUSD.DWX` D1 copper trend-following card.
It combines peer-reviewed commodity trend-following evidence with official copper market
and copper-use references. Runtime strategy logic remains Darwinex MT5-native: OHLC,
spread, ADX, ATR, broker calendar, and V5 framework state only.

## Primary Source

- Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010). "Trend-following trading
  strategies in commodity futures: A re-examination." Journal of Banking and
  Finance, 34(2), 409-426. DOI: https://doi.org/10.1016/j.jbankfin.2009.10.012.
- Quality tier: A.
- Role: primary structural lineage for mechanical commodity futures trend
  following and channel-breakout style rules.

## Supplemental Market Sources

- CME Group. Copper Futures product page.
  URL: https://www.cmegroup.com/markets/metals/base/copper.html.
  Quality tier: A. Role: confirms copper is a liquid exchange-traded base-metal
  futures market and not an equity-index or precious-metal proxy.
- U.S. Geological Survey. Copper Statistics and Information.
  URL: https://www.usgs.gov/centers/national-minerals-information-center/copper-statistics-and-information.
  Quality tier: A. Role: confirms copper's industrial/base-metal demand and
  supply context.

## V5 Allowability

- R1 reputable source: PASS - peer-reviewed finance paper plus official CME and
  USGS references.
- R2 mechanical: PASS - fixed D1 Donchian entry/exit, ADX regime gate, ATR hard
  stop, spread cap, stale-position exit.
- R3 data available: PASS - `XCUUSD.DWX` exists in the V5 registry symbol
  universe; Q02 validates synchronized local history and fills.
- R4 ML forbidden: PASS - no ML, adaptive fitting, external runtime data, grid,
  martingale, or portfolio-gate dependency.

