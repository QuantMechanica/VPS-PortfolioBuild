---
source_id: EIA-WTI-WPSR-PRE-2026
title: EIA Weekly Petroleum Status Report pre-release WTI positioning source
publisher: U.S. Energy Information Administration
source_type: official_government_market_report
status: mined
last_reviewed: 2026-06-27
cards_extracted:
  - eia-wti-prewpsr
---

# EIA WTI Weekly Petroleum Status Report Pre-Release Source

## Source URLs

- U.S. Energy Information Administration, Weekly Petroleum Status Report: https://www.eia.gov/petroleum/supply/weekly/
- U.S. Energy Information Administration, Weekly Petroleum Status Report release schedule: https://www.eia.gov/petroleum/supply/weekly/schedule.php
- U.S. Energy Information Administration, Oil and petroleum products explained: https://www.eia.gov/energyexplained/oil-and-petroleum-products/

## Research Use

This source is used only for structural lineage: the WPSR is a recurring
official weekly information event for crude oil and refined-product markets.
The EA does not ingest EIA data, inventory surprises, analyst forecasts, APIs,
CSV files, or external feeds at runtime.

The mechanized card converts the release structure into a Darwinex-only
pre-event positioning rule. It trades at the start of the expected WPSR D1 bar
after prior-bar compression and trend confirmation, then exits after the report
window. This is distinct from post-WPSR cards that wait for the event-day bar to
close before following or fading the reaction.

## Extracted Card

- `eia-wti-prewpsr`: XTIUSD.DWX D1 weekly pre-WPSR trend/compression positioning.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher.
- R2 mechanical: PASS. Calendar gate, D1 compression/trend filters, ATR stop,
  and max-hold exit are deterministic.
- R3 data available: PASS. XTIUSD.DWX exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external API, or
  discretionary input.
