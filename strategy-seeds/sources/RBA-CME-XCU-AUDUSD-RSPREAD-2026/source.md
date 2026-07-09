# Source Packet - RBA-CME-XCU-AUDUSD-RSPREAD-2026

## Scope

This packet supports one D1 `XCUUSD.DWX` / `AUDUSD.DWX` return-spread
reversion basket. The EA uses only Darwinex MT5 OHLC, spread, ATR, broker time,
and V5 framework state at runtime.

## Primary Source

- Reserve Bank of Australia. "Drivers of the Australian Dollar Exchange Rate."
  URL: https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html.
- Quality tier: A central-bank explainer.
- Role: primary structural lineage for commodity prices, terms of trade, export
  demand, risk sentiment, and AUD exchange-rate transmission.

## Market Context Sources

- CME Group. Copper Futures product page.
  URL: https://www.cmegroup.com/markets/metals/base/copper.html.
  Quality tier: A. Role: confirms copper as a global benchmark base-metal
  futures market.
- U.S. Geological Survey. Copper Statistics and Information.
  URL: https://www.usgs.gov/centers/national-minerals-information-center/copper-statistics-and-information.
  Quality tier: A. Role: confirms copper supply/demand and industrial
  commodity context.

## V5 Allowability

- R1 reputable source: PASS - central-bank AUD driver source plus official CME
  and USGS copper references.
- R2 mechanical: PASS - fixed D1 return lookback, rolling z-score, paired
  market-neutral entry, ATR hard stops, spread caps, max-hold exit, and
  broken-package repair.
- R3 data available: PASS - `AUDUSD.DWX` is in the DWX matrix and existing
  `XCUUSD.DWX` EAs/cards have been built; Q02 must validate synchronized
  XCU/AUD history and fills because the local symbol matrix does not currently
  list `XCUUSD.DWX`.
- R4 ML forbidden: PASS - no ML, adaptive PnL fitting, external runtime data,
  grid, martingale, or discretionary input.
