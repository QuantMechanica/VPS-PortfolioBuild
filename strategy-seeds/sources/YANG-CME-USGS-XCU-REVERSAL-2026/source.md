# Source Packet - YANG-CME-USGS-XCU-REVERSAL-2026

## Scope

This packet supports a single-symbol `XCUUSD.DWX` D1 copper four-week reversal
card. It extends the existing Yang-Goncu-Pantelous commodity momentum/reversal
source family to copper, with official copper market/context references. The
EA uses no external data at runtime.

## Primary Source

- Yang, Goncu, and Pantelous. "Momentum and Reversal in Commodity Futures."
  SSRN working paper. URL:
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253.
- Quality tier: A/B academic working paper, already accepted by V5 source
  packet `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`.
- Role: primary structural lineage for fixed-horizon commodity momentum and
  reversal effects.

## Supplemental Market Sources

- CME Group. Copper Futures product page.
  URL: https://www.cmegroup.com/markets/metals/base/copper.html.
  Quality tier: A. Role: confirms copper is a liquid exchange-traded base-metal
  futures market.
- U.S. Geological Survey. Copper Statistics and Information.
  URL: https://www.usgs.gov/centers/national-minerals-information-center/copper-statistics-and-information.
  Quality tier: A. Role: confirms copper's industrial/base-metal context.

## V5 Allowability

- R1 reputable source: PASS - academic commodity reversal source plus official
  CME and USGS copper references.
- R2 mechanical: PASS - fixed weekly gate, fixed 20-D1-bar return threshold,
  ATR hard stop, spread cap, and max-hold exit.
- R3 data available: PASS - `XCUUSD.DWX` exists in the V5 registry symbol
  universe; Q02 validates local history and fills.
- R4 ML forbidden: PASS - no ML, adaptive fitting, external runtime data, grid,
  martingale, or discretionary input.

