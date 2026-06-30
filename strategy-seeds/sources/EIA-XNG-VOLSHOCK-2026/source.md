---
source_id: EIA-XNG-VOLSHOCK-2026
title: EIA natural gas price factors and volatility source
publisher: U.S. Energy Information Administration
source_type: official_government_energy_reference
status: cards_ready
created: 2026-06-30
created_by: Codex
cards_extracted:
  - xng-volshock-fade
---

# EIA Natural Gas Volatility-Shock Source

## Source URLs

- U.S. Energy Information Administration, "Factors affecting natural gas
  prices", Natural Gas Explained:
  https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php
- U.S. Energy Information Administration, Natural Gas Weekly Update:
  https://www.eia.gov/naturalgas/weekly/
- U.S. Energy Information Administration, Weekly Natural Gas Storage Report:
  https://www.eia.gov/naturalgas/storage/

## Research Use

This source is used for structural lineage only. EIA describes natural gas price
formation as a supply/demand market where weather, consumption, production,
storage inventories, imports/exports, and market expectations can drive sharp
price changes. Those drivers make natural gas a high-volatility commodity whose
large price shocks may overshoot before reverting as supply, demand, and storage
responses are absorbed by the market.

The QM card converts that official natural-gas volatility thesis into a
Darwinex-only D1 price rule: fade unusually large multi-day XNGUSD.DWX moves
only when the close is stretched away from a D1 moving average by ATR. The EA
does not ingest EIA storage data, weather data, forecasts, futures curves, CSV
files, APIs, or external feeds at runtime.

## Extracted Card

- `xng-volshock-fade`: XNGUSD.DWX D1 volatility-shock mean-reversion fade.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher and the card uses one source packet.
- R2 mechanical: PASS. Fixed multi-day return shock, SMA/ATR stretch, ATR stop,
  mean-reversion exit, max-hold exit, and spread cap are deterministic.
- R3 data available: PASS. `XNGUSD.DWX` exists in the Darwinex symbol matrix.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, adaptive PnL fitting,
  external runtime data, or multiple positions per magic.
