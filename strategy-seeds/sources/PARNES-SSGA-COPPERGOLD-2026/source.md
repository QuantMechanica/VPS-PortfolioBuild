# Source Packet - PARNES-SSGA-COPPERGOLD-2026

## Scope

This packet supports one D1 `XCUUSD.DWX` / `XAUUSD.DWX` copper/gold
return-spread reversion basket. The EA uses only Darwinex MT5 OHLC, spread,
ATR, broker time, and V5 framework state at runtime.

## Primary Sources

- Parnes, Dror. "Copper-to-gold ratio as a leading indicator for the 10-Year
  Treasury yield." The North American Journal of Economics and Finance,
  Volume 69 Part A, January 2024, Article 102016.
  DOI: https://doi.org/10.1016/j.najef.2023.102016.
  Quality tier: A. Role: peer-reviewed structural lineage for the
  copper-to-gold ratio as a macro risk/growth signal.
- State Street Global Advisors. "The gold/copper ratio is rising, but this
  time the signal is different." 2026-05-04.
  URL: https://www.ssga.com/us/en/intermediary/etfs/insights/the-gold-copper-ratio-is-rising-but-this-time-the-signal-is-different.
  Quality tier: A-. Role: market-practitioner explanation of copper as a
  cyclical/growth proxy and gold as a safe-haven/flight-to-quality proxy.

## Market Context Sources

- CME Group OpenMarkets. "Gold, Silver, Copper: An Optimistic Outlook?"
  URL: https://www.cmegroup.com/openmarkets/metals/2024/Gold-Silver-Copper-An-Optimistic-Outlook.html.
  Quality tier: A-. Role: exchange context for copper industrial demand and
  gold safe-haven behavior.

## V5 Allowability

- R1 reputable source: PASS - peer-reviewed 2024 copper/gold ratio paper plus
  State Street and CME market references.
- R2 mechanical: PASS - fixed D1 return lookback, rolling z-score, paired
  market-neutral entry, ATR hard stops, spread caps, max-hold exit, and
  broken-package repair.
- R3 data available: PASS - `XAUUSD.DWX` is widely present in V5 registry rows
  and existing XCU builds use `XCUUSD.DWX`; Q02 must validate synchronized
  XCU/XAU history and fills because the local symbol matrix does not currently
  list every custom commodity symbol.
- R4 ML forbidden: PASS - no ML, adaptive PnL fitting, external runtime data,
  grid, martingale, or discretionary input.

