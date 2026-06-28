---
source_id: EIA-WTI-WPSR-IDBRK-2026
title: EIA Weekly Petroleum Status Report post-event WTI consolidation source
publisher: U.S. Energy Information Administration
source_type: official_government_market_report
status: cards_ready
created: 2026-06-28
created_by: Codex
uri: https://www.eia.gov/petroleum/supply/weekly/
cards_extracted:
  - eia-wti-wpsr-idbrk
---

# EIA WTI Weekly Petroleum Status Report Post-Event Consolidation Source

## Source URLs

- U.S. Energy Information Administration, Weekly Petroleum Status Report: https://www.eia.gov/petroleum/supply/weekly/
- U.S. Energy Information Administration, Weekly Petroleum Status Report release schedule: https://www.eia.gov/petroleum/supply/weekly/schedule.php
- U.S. Energy Information Administration, Oil and petroleum products explained: https://www.eia.gov/energyexplained/oil-and-petroleum-products/

## Research Use

This source is used only for structural lineage: the WPSR is a recurring
official weekly information event for crude oil and refined-product markets.
The EA does not ingest EIA data, inventory surprises, analyst forecasts, APIs,
CSV files, futures curves, or external feeds at runtime.

The mechanized card converts the release structure into a Darwinex-only
post-event consolidation rule. It first identifies an expected Wednesday or
holiday-shifted Thursday WPSR event bar, then requires the next completed D1
bar to be an inside consolidation bar. The EA trades only if live price breaks
that inside-bar range during the following D1 bar, with a short ATR stop and
time/trend exits.

## Extracted Card

- `eia-wti-wpsr-idbrk`: XTIUSD.DWX D1 post-WPSR inside-bar breakout.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher.
- R2 mechanical: PASS. WPSR weekday gate, inside-bar setup, live range
  breakout, ATR stop, SMA failure exit, and max-hold exit are deterministic.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external API, or
  discretionary input.
