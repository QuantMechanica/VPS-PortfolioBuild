---
source_id: EIA-XNG-WEEKEND-GAP-2026
title: EIA natural-gas price drivers and weather demand source packet
status: cards_ready
created: 2026-06-28
created_by: Codex
source_type: official_energy_research
uri: https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php
---

# EIA Natural-Gas Price Drivers And Weather Demand Source Packet

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: EIA Energy Explained, "Factors affecting natural gas prices", URL https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php.

## Mining Scope

One card was extracted for a structural natural-gas CFD sleeve:

- `xng-weekend-gap`: XNGUSD.DWX D1 weekend weather-gap continuation.

## Evidence Notes

- EIA describes natural-gas prices as supply-and-demand driven and identifies weather-sensitive heating and electric-power demand as major recurring drivers.
- The QM implementation does not read weather, demand, EIA, storage, futures-curve, CSV, API, forecast, or analyst data at runtime.
- The source is used only as official structural lineage for the idea that weekend forecast repricing can appear as a Monday D1 gap in `XNGUSD.DWX`; the EA still requires a mechanical gap and same-day continuation bar before entering.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive parameter fitting, grid, or martingale.
- Single-position XNGUSD.DWX sleeve, one magic slot.
