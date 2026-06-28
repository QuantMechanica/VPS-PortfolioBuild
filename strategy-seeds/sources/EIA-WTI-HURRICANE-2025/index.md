---
source_id: EIA-WTI-HURRICANE-2025
title: EIA refining industry risks from 2025 hurricane season
publisher: U.S. Energy Information Administration
source_type: official_government_market_article
status: mined
last_reviewed: 2026-06-27
cards_extracted:
  - eia-wti-hurr-brk
  - eia-wti-hurr-fade
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

The mechanized cards convert that structural supply-risk window into
Darwinex-only XTIUSD.DWX D1 price rules. The breakout card trades upside supply
risk after trend confirmation. The fade card uses the same official hurricane
season lineage but trades the opposite failure mode: during the late-summer
storm-risk window, fade failed upside spike/rejection bars back toward a slow
D1 mean with ATR risk and short time exits.

## Extracted Card

- `eia-wti-hurr-brk`: XTIUSD.DWX D1 hurricane-season upside breakout.
- `eia-wti-hurr-fade`: XTIUSD.DWX D1 hurricane-season failed upside spike fade.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher.
- R2 mechanical: PASS. Calendar windows, D1 OHLC breakout or failed-spike
  rejection rules, ATR range thresholds, SMA mean/trend filters, ATR stops, and
  max-hold exits are deterministic.
- R3 data available: PASS. XTIUSD.DWX exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external API, or
  discretionary input.
