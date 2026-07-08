---
source_id: EIA-RBA-JAPAN-XTI-AUDJPY-2026
title: Oil price and AUDJPY structural linkage for WTI/AUDJPY relative value
publisher: U.S. Energy Information Administration / Reserve Bank of Australia
source_type: government_energy_and_central_bank_research
status: cards_ready
created: 2026-07-08
created_by: Codex
uri: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
cards_extracted:
  - xti-audjpy-rspr
---

# EIA-RBA-JAPAN-XTI-AUDJPY-2026

## Source Identity

- Primary: U.S. Energy Information Administration working paper, "The
  Relationship between Oil Prices and Exchange Rates: Theory and Evidence",
  June 2017, URL https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf.
- AUD commodity-channel support: Reserve Bank of Australia education explainer,
  "Drivers of the Australian Dollar Exchange Rate", URL
  https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html.
- Energy-importer context: U.S. Energy Information Administration, "Japan",
  Country Analysis Brief, URL
  https://www.eia.gov/international/content/analysis/countries_long/japan/japan.pdf.

## Research Use

This source packet is used for structural lineage only. The EIA working paper
reviews oil price and exchange-rate links, including transmission channels and
time-varying empirical relationships. The RBA explainer supports the Australian
dollar's commodity and risk-sentiment exposure. The EIA Japan brief supplies
the energy-import context for the JPY side of the cross.

The QM implementation does not ingest EIA data, RBA data, futures curves,
inventory data, import statistics, forecasts, APIs, CSV files, COT data, or
macroeconomic series at runtime. It converts the source idea into a
Darwinex-native D1 relative-value rule: compare completed WTI returns with
completed AUDJPY returns, open a two-leg basket only when their return spread
is unusually wide, and close when the spread mean-reverts or the time stop
fires.

## Extracted Card

- `xti-audjpy-rspr`: `XTIUSD.DWX` and `AUDJPY.DWX` D1 return-spread
  reversion basket.

## Duplicate Boundary

This source is related to energy/FX work, but the extracted card is not a
rebuild of `wti-cad-confirm`, `wti-cad-spread-mr`, `wti-cad-brk`,
`xti-cadjpy-rspr`, `xti-cadchf-rspr`, `xti-audcad-rspr`,
`xti-gbpcad-rspr`, `xbr-cad-rspr`, `xti-nzd-rspread`, or
`xti-xng-rspread`. It also differs from outright WTI trend, WTI seasonality,
natural-gas, XAU/XAG, index, oil/metals, and FX-only cointegration sleeves.
The new sleeve uses WTI plus AUDJPY, trades both legs as a two-leg basket, and
opens from a standardized D1 return-spread dislocation where AUDJPY is the
positive commodity/risk leg.

## R-Rules

- R1 reputable source: PASS. U.S. government energy research plus RBA central
  bank AUD commodity-currency context and U.S. government Japan energy context.
- R2 mechanical: PASS. Fixed D1 return lookback, fixed rolling z-score window,
  deterministic basket directions, ATR hard stops, spread caps, z-score exit,
  broken-package repair, and max-hold exit.
- R3 data available: PASS. `XTIUSD.DWX` and `AUDJPY.DWX` are present in
  `framework/registry/dwx_symbol_matrix.csv`.
- R4 no ML/banned logic: PASS. Deterministic, one position per magic slot, no
  grid, no martingale, no adaptive PnL fitting, and no external runtime feed.
