---
source_id: EIA-WTI-SEASON-2024
title: EIA petroleum product seasonal demand cycle
status: cards_ready
created: 2026-06-26
created_by: Codex
source_type: official_energy_statistics
uri: https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php
---

# EIA Petroleum Product Seasonal Demand Cycle

## Source Identity

- Publisher: U.S. Energy Information Administration
- Primary source: EIA Energy Explained, "Gasoline price fluctuations", URL https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php
- Supplement: EIA Energy Explained, "Use of heating oil", URL https://www.eia.gov/energyexplained/heating-oil/use-of-heating-oil.php
- Supplement: EIA Energy Explained, "Diesel fuel explained: factors affecting diesel prices", URL https://www.eia.gov/energyexplained/diesel-fuel/factors-affecting-diesel-prices.php

## Mining Scope

Two cards were extracted for structural WTI crude oil CFD sleeves:

- `eia-wti-season`: XTIUSD.DWX D1 monthly product-demand seasonal trend with price confirmation.
- `wti-jun-prem`: XTIUSD.DWX D1 June-only driving-season calendar premium.

## Evidence Notes

- EIA describes retail gasoline prices as tending to rise in spring and peak in late summer when driving frequency increases.
- EIA describes heating oil use as concentrated in the October through March heating season.
- EIA describes fall/winter heating-oil demand as a seasonal factor that can affect diesel fuel prices because heating oil and diesel are related distillate products.
- The QM implementation does not ingest external EIA data at runtime. It mechanizes the source lineage as fixed monthly windows and uses only Darwinex MT5 OHLC data for trend confirmation and risk control.

## Guardrails

- No external API calls, inventory data, refinery data, futures curve, or discretionary override in the EA.
- No ML, adaptive parameter fitting, grid, or martingale.
- One position per XTIUSD.DWX magic slot.
