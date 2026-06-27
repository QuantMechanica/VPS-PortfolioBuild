---
source_id: BOC-CAD-OIL-2017
title: Canadian dollar and oil/commodity-price linkage
publisher: Bank of Canada / U.S. Energy Information Administration
uri: https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/
status: APPROVED
cards:
  - wti-cad-confirm
---

# Canadian Dollar and Oil Confirmation Source

## Primary Sources

- Bank of Canada, Staff Analytical Note 2017-1, "The Link Between the Canadian
  Dollar and Commodity Prices: Has It Broken?", URL
  https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/.
- U.S. Energy Information Administration, "Canada", Country Analysis Brief,
  URL https://www.eia.gov/international/analysis/country/CAN.

## Source Use

This source packet is used for structural lineage only. The Bank of Canada
source supports the premise that commodity-price shocks, including oil-price
shocks, have historically been a meaningful driver of the Canadian dollar,
while noting that the relationship varies across regimes. The EIA country
analysis supports the structural energy-export exposure behind that linkage.

The QM strategy therefore does not treat USDCAD as a standalone forecast. It
uses closed-bar `USDCAD.DWX` movement only as a confirmation filter for an
`XTIUSD.DWX` D1 trend package. The EA does not ingest Bank of Canada, EIA,
futures-curve, inventory, forecast, API, CSV, COT, or macroeconomic data at
runtime.

## Criteria Check

- R1 reputable source: PASS. Central-bank analytical note plus U.S. government
  energy country analysis.
- R2 mechanical: PASS. Fixed weekly gate, closed-bar WTI return, closed-bar
  USDCAD return, SMA trend filter, ATR hard stop, confirmation failure exit, and
  max-hold exit are deterministic.
- R3 data available: PASS. `XTIUSD.DWX` and `USDCAD.DWX` exist in
  `framework/registry/dwx_symbol_matrix.csv`.
- R4 compliant: PASS. No ML, no grid, no martingale, no external runtime feed,
  and one open XTI position per magic.
