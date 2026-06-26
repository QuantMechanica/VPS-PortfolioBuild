---
source_id: EIA-WTI-HURRICANE-2025
title: EIA refining industry risks from 2025 hurricane season
publisher: U.S. Energy Information Administration
source_type: official_government_market_article
status: mined
last_reviewed: 2026-06-27
cards_extracted:
  - eia-wti-hurr-brk
---

# EIA WTI Hurricane Season Source

## Source URL

- U.S. Energy Information Administration, "Refining industry risks from 2025 hurricane season": https://www.eia.gov/todayinenergy/detail.php?id=65304

## Research Use

This source is used only for structural lineage. EIA documents the Atlantic
hurricane season window, peak storm timing, and the exposure of U.S. Gulf Coast
refining and petroleum supply chains to storm-related outages. The EA does not
ingest hurricane forecasts, weather feeds, EIA data, refinery data, APIs, CSVs,
or any external feed at runtime.

The mechanized card converts that structural supply-risk window into a
Darwinex-only XTIUSD.DWX D1 price rule: during hurricane season, require an
upside breakout, directional bar close, and trend confirmation before taking a
long-only WTI position with ATR risk and short time/failed-breakout exits.

## Extracted Card

- `eia-wti-hurr-brk`: XTIUSD.DWX D1 hurricane-season upside breakout.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher.
- R2 mechanical: PASS. Calendar window, D1 OHLC breakout, ATR range threshold,
  SMA trend filter, ATR stop, channel exit, and max-hold exit are deterministic.
- R3 data available: PASS. XTIUSD.DWX exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external API, or
  discretionary input.
