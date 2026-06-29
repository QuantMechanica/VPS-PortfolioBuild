---
source_id: EIA-XNG-STOR-IDBRK-2026
title: EIA Weekly Natural Gas Storage Report inside-day breakout source
publisher: U.S. Energy Information Administration
source_type: official_government_market_report
status: mined
last_reviewed: 2026-06-29
cards_extracted:
  - eia-xng-stor-idbrk
---

# EIA Natural Gas Storage Inside-Day Breakout Source

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
EA does not ingest storage levels, consensus forecasts, surprises, weather,
futures curves, CSV files, APIs, or external feeds at runtime.

The mechanized card converts the release structure into a Darwinex-only price
compression breakout rule. It identifies a likely storage-report D1 event bar,
requires the following completed D1 bar to be an inside/range-compression bar,
then trades only a live break of that compressed range with SMA confirmation.

## Extracted Card

- `eia-xng-stor-idbrk`: XNGUSD.DWX D1 post-storage inside-day breakout.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher.
- R2 mechanical: PASS. Fixed event-day set, inside-day compression filters,
  live range breakout, SMA confirmation, ATR stop, and time/trend exits are
  deterministic.
- R3 data available: PASS. `XNGUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external API, or
  discretionary input.
