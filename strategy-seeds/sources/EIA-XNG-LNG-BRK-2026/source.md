---
source_id: EIA-XNG-LNG-BRK-2026
title: EIA natural-gas LNG export demand breakout source
publisher: U.S. Energy Information Administration
source_type: official_government_market_report
status: mined
last_reviewed: 2026-06-29
cards_extracted:
  - eia-xng-lng-brk
---

# EIA Natural Gas LNG Export Demand Breakout Source

## Source URLs

- U.S. Energy Information Administration, Natural gas explained, factors
  affecting natural gas prices:
  https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php
- U.S. Energy Information Administration, Today in Energy, "U.S. natural gas
  prices fell in 2024; we forecast prices will increase in 2025 and 2026":
  https://www.eia.gov/todayinenergy/detail.php?id=64004
- U.S. Energy Information Administration, Today in Energy, "U.S. LNG exports
  reached a record in March 2026":
  https://www.eia.gov/todayinenergy/detail.php?id=67004
- U.S. Energy Information Administration, Natural gas explained:
  https://www.eia.gov/energyexplained/natural-gas/

## Research Use

This source is used only for structural lineage. EIA identifies exports as one
of the supply-demand factors that affects U.S. natural gas prices, links higher
LNG exports and growing power demand to upward pressure on Henry Hub prices,
and reported record U.S. LNG export volumes in March 2026. That makes LNG
export demand an official, price-relevant natural-gas demand sleeve.

The mechanized card does not ingest EIA exports, terminal utilization, shipping,
weather, futures curves, CSV files, APIs, or discretionary inputs at runtime.
It converts the official demand theme into a Darwinex-only D1 rule: during
fixed LNG-demand months, require pre-breakout range compression, a rising SMA
trend, and a close-confirmed upside channel breakout on `XNGUSD.DWX`.

## Extracted Card

- `eia-xng-lng-brk`: XNGUSD.DWX D1 LNG export-demand compression breakout.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher, and all source URLs are EIA pages.
- R2 mechanical: PASS. Fixed calendar months, D1 channel breakout, SMA trend
  confirmation, ATR compression, ATR stop, trend/range/time exits, and a
  one-entry-per-month limiter are deterministic.
- R3 data available: PASS. `XNGUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, oscillator pullback,
  external API, or discretionary input.
