---
source_id: EIA-WTI-WPSR-FADE-2026
title: EIA Weekly Petroleum Status Report WTI exhaustion-fade source
publisher: U.S. Energy Information Administration
source_type: official_government_market_report
status: mined
last_reviewed: 2026-06-26
cards_extracted:
  - eia-wti-wpsr-fade
---

# EIA WTI Weekly Petroleum Status Report Exhaustion-Fade Source

## Source URLs

- U.S. Energy Information Administration, Weekly Petroleum Status Report: https://www.eia.gov/petroleum/supply/weekly/
- U.S. Energy Information Administration, Weekly Petroleum Status Report release schedule: https://www.eia.gov/petroleum/supply/weekly/schedule.php
- U.S. Energy Information Administration, Oil and petroleum products explained: https://www.eia.gov/energyexplained/oil-and-petroleum-products/

## Research Use

This source is used only for structural lineage: the WPSR is a recurring official
weekly information event for crude oil and refined-product markets. The EA does
not ingest EIA data, inventory surprises, analyst forecasts, APIs, CSV files, or
external feeds at runtime.

The mechanized card converts the release structure into a Darwinex-only price
reaction rule. It waits until the first D1 bar after an expected Wednesday or
holiday-shifted Thursday release day, requires an unusually wide directional
event-day close that is stretched from slow D1 trend, then fades that exhaustion
for a short mean-reversion window.

## Extracted Card

- `eia-wti-wpsr-fade`: XTIUSD.DWX D1 weekly post-WPSR exhaustion fade.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher.
- R2 mechanical: PASS. Calendar gate, D1 OHLC reaction, ATR range threshold,
  SMA distance threshold, ATR stop, mean-reversion exit, and max-hold exit are
  deterministic.
- R3 data available: PASS. XTIUSD.DWX exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external API, or
  discretionary input.
