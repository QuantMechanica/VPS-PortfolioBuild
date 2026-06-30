---
source_id: EIA-BOJ-WTI-JPY-2026
title: Japan oil-importer FX confirmation source packet
status: cards_ready
created: 2026-06-30
created_by: Codex
source_type: official_energy_and_central_bank_sources
uri: https://www.eia.gov/international/analysis/country/JPN
---

# Japan Oil-Importer FX Confirmation Source

## Source Identity

- Primary energy source: U.S. Energy Information Administration, "Japan",
  Country Analysis Brief, URL https://www.eia.gov/international/analysis/country/JPN.
- Primary macro source: Bank of Japan, Uchida, S., "Recent Developments in
  Economic Activity, Prices, and Monetary Policy", speech in Osaka, 2026-06-03,
  URL https://www.boj.or.jp/en/about/press/koen_2026/ko260603a.htm.
- Supplemental exchange-rate source: Beckmann, J., Czudaj, R. L., and Arora,
  V., "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration Working Paper, June 2017, URL
  https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf.

## Mining Scope

One card is extracted from this source packet:

- `wti-jpy-confirm`: `XTIUSD.DWX` D1 WTI trend entries confirmed by the
  closed-bar direction of `USDJPY.DWX` as a Japan oil-importer FX proxy.

## Evidence Notes

- EIA documents Japan as a large energy importer with limited domestic oil
  resources, making crude-oil price moves structurally relevant to Japan's
  terms of trade.
- The BOJ source links recent higher crude-oil prices and yen depreciation to
  Japan's import-cost and terms-of-trade channel.
- The EIA oil/exchange-rate working paper is used only as supplemental lineage
  that oil prices and exchange rates are jointly studied as a macro linkage.
- The EA does not ingest EIA, BOJ, DXY, oil-import, futures-curve, macro CSV,
  API, or analyst data at runtime.
- Runtime uses closed Darwinex MT5 D1 bars only: `XTIUSD.DWX` for WTI and
  `USDJPY.DWX` as read-only confirmation.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive parameter fitting, grid, martingale, or pyramiding.
- `USDJPY.DWX` is read-only confirmation; the EA trades only `XTIUSD.DWX`.
- One open position per magic slot.

## R-Rules

- R1 reputable source: PASS. Official EIA country analysis plus official BOJ
  policy speech, with EIA exchange-rate working paper as supplement.
- R2 mechanical: PASS. Fixed weekly gate, fixed closed-bar lookbacks, fixed
  return thresholds, SMA trend filter, ATR hard stop, signal-flip exit, and
  max-hold exit.
- R3 data available: PASS. `XTIUSD.DWX` and `USDJPY.DWX` exist in the DWX
  symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic, one position per magic slot, no
  ML, no grid, no martingale, no external runtime data.
