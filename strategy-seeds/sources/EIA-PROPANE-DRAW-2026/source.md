---
source_id: EIA-PROPANE-DRAW-2026
title: EIA propane stock-build and heating-season draw structure
status: cards_ready
created: 2026-07-03
created_by: Codex
source_type: official_energy_statistics
uri: https://www.eia.gov/energyexplained/hydrocarbon-gas-liquids/prices-for-hydrocarbon-gas-liquids-propane.php
---

# EIA Propane Heating-Season Draw Structure

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: EIA Energy Explained, "Prices for hydrocarbon gas liquids:
  propane", URL
  https://www.eia.gov/energyexplained/hydrocarbon-gas-liquids/prices-for-hydrocarbon-gas-liquids-propane.php.
- Supplement: EIA Heating Oil and Propane Update, URL
  https://www.eia.gov/petroleum/heatingoilpropane/.

## Mining Scope

One structural WTI crude oil CFD card was extracted:

- `wti-propane-draw`: XTIUSD.DWX D1 October-March propane
  heating-season draw displacement continuation.

## Evidence Notes

- EIA describes propane consumption as highly seasonal while production from
  crude oil refining and natural gas processing is comparatively consistent.
- EIA describes propane inventories as typically building during spring and
  summer and then being used during autumn and winter.
- EIA notes that propane prices can rise quickly when supply sources cannot
  respond quickly enough to demand, and the 2013-2014 case links low stocks,
  logistics constraints, and cold-weather demand.
- EIA's Heating Oil and Propane Update covers the October through March heating
  season, matching the card's fixed calendar window.

## Mechanization Guardrails

- The EA does not ingest propane prices, propane stocks, weather, EIA APIs,
  futures curves, spreads, CSVs, or discretionary event flags at runtime.
- The source is structural lineage only. Execution uses Darwinex MT5 D1 OHLC,
  spread, ATR, SMA, broker calendar, and V5 framework state.
- No ML, optimization-at-runtime, grid, martingale, or live-trading file touch.
- One position per `XTIUSD.DWX` magic slot.
