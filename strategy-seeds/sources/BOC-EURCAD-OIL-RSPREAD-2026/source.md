---
source_id: BOC-EURCAD-OIL-RSPREAD-2026
title: Oil price and Canadian dollar structural linkage for WTI/EURCAD relative value
publisher: U.S. Energy Information Administration / Bank of Canada
source_type: government_and_central_bank_research
status: cards_ready
created: 2026-07-08
created_by: Codex
uri: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
cards_extracted:
  - xti-eurcad-rspr
---

# BOC-EURCAD-OIL-RSPREAD-2026

## Source Identity

- Primary: U.S. Energy Information Administration working paper, "The
  Relationship between Oil Prices and Exchange Rates: Theory and Evidence",
  June 2017, URL https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf.
- CAD commodity-channel support: Bank of Canada Staff Analytical Note 2017-1,
  "The Share of Systematic Variations in the Canadian Dollar-Part II", URL
  https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/.
- Energy-export context: U.S. Energy Information Administration, "Canada",
  Country Analysis Brief, URL https://www.eia.gov/international/analysis/country/CAN.

## Research Use

This source packet is used for structural lineage only. The EIA working paper
reviews theoretical and empirical links between oil prices and exchange rates,
including long-run relationships and time-varying short-run predictability. The
Bank of Canada note supports the commodity-currency channel and explicitly
frames an oil portfolio as part of systematic variation in the Canadian dollar.
The EIA Canada brief supplies the energy-export context behind the CAD/oil
channel.

The QM implementation does not ingest EIA data, Bank of Canada data, futures
curves, inventory data, forecasts, APIs, CSV files, COT data, or macroeconomic
series at runtime. It converts the source idea into a Darwinex-native D1
relative-value rule: compare completed WTI returns with completed EURCAD
returns, open a two-leg basket only when their inverse-CAD return spread is
unusually wide, and close when the spread mean-reverts or the time stop fires.

## Extracted Card

- `xti-eurcad-rspr`: `XTIUSD.DWX` and `EURCAD.DWX` D1 inverse-CAD
  return-spread reversion basket.

## Duplicate Boundary

This source is related to prior WTI/CAD work, but the extracted card is not a
rebuild of `wti-cad-confirm`, `wti-cad-spread-mr`, `wti-cad-brk`,
`xti-cadjpy-rspr`, `xti-cadchf-rspr`, `xti-audcad-rspr`, `xbr-cad-rspr`,
`xti-nzd-rspread`, or `xti-xng-rspread`. It also differs from
the existing FX-only CAD-cross cointegration baskets. The new sleeve uses WTI
plus EURCAD, trades both legs as a two-leg basket, and opens from a
standardized D1 return-spread dislocation designed around EURCAD's inverse CAD
quotation.

## R-Rules

- R1 reputable source: PASS. U.S. government energy research plus central-bank
  CAD commodity-currency research and U.S. government Canada energy context.
- R2 mechanical: PASS. Fixed D1 return lookback, fixed rolling z-score window,
  deterministic basket directions, ATR hard stops, spread caps, z-score exit,
  broken-package repair, and max-hold exit.
- R3 data available: PASS. `XTIUSD.DWX` and `EURCAD.DWX` are present in
  `framework/registry/dwx_symbol_matrix.csv`.
- R4 no ML/banned logic: PASS. Deterministic, one position per magic slot, no
  grid, no martingale, no adaptive PnL fitting, and no external runtime feed.

