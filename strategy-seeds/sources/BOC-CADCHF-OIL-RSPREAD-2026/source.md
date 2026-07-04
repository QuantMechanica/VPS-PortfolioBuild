---
source_id: BOC-CADCHF-OIL-RSPREAD-2026
title: Bank of Canada CAD commodity-price linkage for WTI/CADCHF relative value
publisher: Bank of Canada / U.S. Energy Information Administration
source_type: central_bank_and_government_energy_research
status: cards_ready
created: 2026-07-04
created_by: Codex
uri: https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/
cards_extracted:
  - xti-cadchf-rspr
---

# BOC-CADCHF-OIL-RSPREAD-2026

## Source Identity

- Primary: Bank of Canada Staff Analytical Note 2017-1, "The Link Between the
  Canadian Dollar and Commodity Prices: Has It Broken?", URL
  https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/.
- Energy-export context: U.S. Energy Information Administration, "Canada",
  Country Analysis Brief, URL
  https://www.eia.gov/international/analysis/country/CAN.

## Research Use

This source packet is used for structural lineage only. The Bank of Canada
source supports the premise that commodity-price shocks, including oil-price
shocks, have historically been a meaningful driver of the Canadian dollar,
while noting that the relationship varies across regimes. The EIA Canada
country analysis supports the structural energy-export exposure behind that
linkage.

The QM implementation does not ingest Bank of Canada data, EIA data, futures
curves, inventory data, forecasts, APIs, CSV files, COT data, or macroeconomic
series at runtime. It converts the source idea into a Darwinex-native D1
relative-value rule: compare completed WTI returns with completed CADCHF
returns, open a two-leg basket only when their return spread is unusually wide,
and close when the spread mean-reverts or the time stop fires.

## Extracted Card

- `xti-cadchf-rspr`: `XTIUSD.DWX` and `CADCHF.DWX` D1 return-spread
  reversion basket.

## Duplicate Boundary

This source is related to existing WTI/CAD work, but the card is not a rebuild
of `wti-cad-confirm`, `wti-cad-spread-mr`, `wti-cad-brk`,
`xti-cadjpy-rspr`, `xbr-cad-rspr`, or `xti-nzd-rspread`. The new sleeve uses
CADCHF as the CAD leg, trades both WTI and CADCHF as a two-leg basket, and
opens from a standardized D1 return-spread dislocation rather than a one-leg
confirmation, USDCAD residual, CADJPY oil-importer cross, Brent leg, or NZD
commodity-FX channel.

## R-Rules

- R1 reputable source: PASS. Central-bank research plus U.S. government energy
  country analysis.
- R2 mechanical: PASS. Fixed D1 return lookback, fixed rolling z-score window,
  deterministic basket directions, ATR hard stops, spread caps, z-score exit,
  broken-package repair, and max-hold exit.
- R3 data available: PASS. `XTIUSD.DWX` and `CADCHF.DWX` are present in
  `framework/registry/dwx_symbol_matrix.csv`.
- R4 no ML/banned logic: PASS. Deterministic, one position per magic slot, no
  grid, no martingale, no adaptive PnL fitting, and no external runtime feed.
