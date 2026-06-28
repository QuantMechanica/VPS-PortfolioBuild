---
source_id: EIA-WTI-POSTDRIVE-2026
title: EIA gasoline post-driving-season price fluctuation research
publisher: U.S. Energy Information Administration
source_type: government_energy_research
status: cards_ready
created: 2026-06-28
created_by: Codex
uri: https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php
cards_extracted:
  - eia-wti-postdrive
---

# EIA WTI Post-Driving-Season Source

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: U.S. Energy Information Administration, "Gasoline price fluctuations", Energy Explained, URL https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php.

## Research Use

This source is used for structural lineage around recurring U.S. gasoline
seasonality. The mechanized card isolates the period after the spring/summer
driving-season support window and maps it to a Darwinex-native WTI sleeve:
D1 channel breakdowns on `XTIUSD.DWX` during the post-driving shoulder window.

The implementation does not ingest EIA data, gasoline cracks, futures curves,
inventories, analyst forecasts, CSV files, APIs, or external feeds at runtime.
It uses Darwinex MT5 OHLC and broker calendar state only.

## Guardrails

- Runtime uses `XTIUSD.DWX` D1 OHLC and broker calendar only.
- No external API calls or CSV dependencies.
- No ML, adaptive PnL fitting, grid, martingale, pyramiding, or discretionary override.
- One position per `XTIUSD.DWX` magic slot.

## R-Rules

- R1 reputable source: PASS. Official U.S. EIA energy education source with URL.
- R2 mechanical: PASS. Fixed post-driving-season date window, D1 channel breakdown, ATR hard stop, and deterministic channel/date/time exits.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic one-position calendar-breakdown sleeve.
