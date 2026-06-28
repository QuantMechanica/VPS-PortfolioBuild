---
source_id: EIA-XNG-STORAGE-FADE-2026
title: EIA Weekly Natural Gas Storage Report exhaustion-fade source
publisher: U.S. Energy Information Administration
source_type: official_government_market_report
status: mined
last_reviewed: 2026-06-28
cards_extracted:
  - eia-xng-storfade
---

# EIA Natural Gas Storage Exhaustion-Fade Source

## Source URLs

- U.S. Energy Information Administration, Weekly Natural Gas Storage Report:
  https://www.eia.gov/naturalgas/storage/
- U.S. Energy Information Administration, Natural Gas Weekly Update and Storage
  Report Schedule: https://www.eia.gov/naturalgas/schedule/
- U.S. Energy Information Administration, Natural gas explained:
  https://www.eia.gov/energyexplained/natural-gas/

## Research Use

This source is used only for structural lineage: the EIA Weekly Natural Gas
Storage Report is a recurring official information event for natural gas. The
EA does not ingest EIA storage levels, consensus forecasts, surprises, weather,
futures curves, CSV files, APIs, or external feeds at runtime.

The mechanized card converts the release structure into a Darwinex-only price
reaction rule. It waits until a likely storage-report D1 bar has closed, then
fades only unusually wide, directional, outer-tail bars that are stretched away
from a slow D1 mean.

## Extracted Card

- `eia-xng-storfade`: XNGUSD.DWX D1 weekly storage-report exhaustion fade.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher.
- R2 mechanical: PASS. Fixed event-day set, D1 range/body/tail/stretch filters,
  ATR stop, mean-reversion exit, and max-hold exit are deterministic.
- R3 data available: PASS. `XNGUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external API, or
  discretionary input.
