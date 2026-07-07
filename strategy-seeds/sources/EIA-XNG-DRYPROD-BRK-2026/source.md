---
source_id: EIA-XNG-DRYPROD-BRK-2026
title: EIA Natural Gas Monthly dry-production release-window breakout source
publisher: U.S. Energy Information Administration
source_type: official_government_market_report
status: mined
last_reviewed: 2026-07-07
cards_extracted:
  - xng-prod-brk
---

# EIA XNG Dry-Production Breakout Source

## Source URLs

- U.S. Energy Information Administration, Natural Gas Monthly:
  https://www.eia.gov/naturalgas/monthly/
- U.S. Energy Information Administration, Natural Gas Data:
  https://www.eia.gov/naturalgas/data.php
- U.S. Energy Information Administration, Natural Gas Dry Production table:
  https://www.eia.gov/dnav/ng/ng_prod_sum_a_epg0_fpd_mmcf_a.htm

## Research Use

This source is used only for structural lineage. EIA publishes monthly natural
gas market data, including dry natural gas production, on a scheduled official
release cycle. Dry production is a direct structural supply variable for U.S.
natural gas and is distinct from weekly storage draws, weather shocks, LNG
exports, and broad seasonal demand regimes.

The mechanized card does not ingest EIA values, surprises, calendars, CSV
files, APIs, weather, storage data, futures curves, volume, or discretionary
inputs at runtime. It converts the official supply-update window into a
Darwinex-only D1 rule: during late-month production-release windows, require
pre-breakout compression, a close outside a Donchian channel, trend alignment,
and ATR-defined risk on `XNGUSD.DWX`.

## Extracted Card

- `xng-prod-brk`: XNGUSD.DWX D1 dry-production release-window compression
  breakout.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher, and all source URLs are EIA pages.
- R2 mechanical: PASS. Fixed late-month production window, D1 channel
  breakout, SMA trend confirmation, ATR compression, ATR stop/target, time
  exit, and a one-entry-per-month limiter are deterministic.
- R3 data available: PASS. `XNGUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, oscillator pullback,
  external API, or discretionary input.
