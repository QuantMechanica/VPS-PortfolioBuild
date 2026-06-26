---
source_id: EIA-RBOB-CRACK-SEASON-2025
title: EIA gasoline crack spread seasonal research
status: cards_ready
created: 2026-06-26
created_by: Codex
source_type: government_energy_research
uri: https://www.eia.gov/petroleum/weekly/archive/2025/250312/includes/analysis_print.php
---

# EIA Gasoline Crack Spread Seasonal Research

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: EIA, "Gasoline crack spreads rise ahead of the summer driving season", This Week in Petroleum, March 12, 2025.
- URL: https://www.eia.gov/petroleum/weekly/archive/2025/250312/includes/analysis_print.php

## Mining Scope

One card was extracted for a structural WTI sleeve:

- `eia-rbob-crack`: XTIUSD.DWX D1 gasoline crack-spread seasonal breakout proxy.

## Evidence Notes

- EIA describes RBOB gasoline crack spreads as a refiner-margin proxy for converting crude oil into gasoline.
- The article documents a recurring gasoline-season structure: crack spreads typically rise in March as refiners increase summer-grade gasoline production, stay elevated through the summer driving season, and decline when winter-grade gasoline specification starts on September 1.
- The QM implementation does not ingest EIA spreads, RBOB futures, refinery utilization, inventories, or any external data at runtime. It uses the EIA source only for structural lineage and trades XTIUSD.DWX D1 OHLC breakouts during the documented gasoline crack-spread seasonal windows.

## Guardrails

- No external data calls in the EA.
- No ML, no adaptive parameter fitting, no grid, no martingale.
- Single-position XTIUSD.DWX sleeve, one magic slot.
