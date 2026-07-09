---
source_id: EIA-XTI-EXPORT-FLOW-2026
title: EIA crude export-flow structural source packet
publisher: U.S. Energy Information Administration
source_type: official_government_energy_reference
status: cards_ready
created: 2026-07-09
created_by: Codex
cards_extracted:
  - xti-export-flow-brk
  - xti-export-fade
---

# EIA Crude Export-Flow Source

## Source URLs

- U.S. Energy Information Administration, "U.S. crude oil exports reached a new
  record in 2024", Today in Energy, 2025-04-10:
  https://www.eia.gov/todayinenergy/detail.php?id=64964
- U.S. Energy Information Administration, "Petroleum & Other Liquids - Data",
  imports/exports and exports-by-destination release table:
  https://www.eia.gov/petroleum/data.php
- U.S. Energy Information Administration, Weekly Petroleum Status Report
  schedule:
  https://www.eia.gov/petroleum/supply/weekly/schedule.php

## Research Use

EIA documents U.S. crude exports as a material physical-flow channel for
WTI-linked crude and maintains recurring imports/exports publication tables.
This source packet uses that official structural lineage only. EAs derived from
it do not ingest EIA export values, monthly tables, WPSR files, vessel data,
CSV/API data, futures curves, analyst forecasts, or discretionary inputs at
runtime.

Extracted cards:

- `xti-export-flow-brk`: last-business-days export-flow information-window D1
  breakout.
- `xti-export-fade`: last-business-days export-flow failed-probe D1 fade after
  the market rejects a channel break.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher.
- R2 mechanical: PASS. The extracted cards use fixed broker-calendar windows,
  D1 OHLC, Donchian channel state, ATR/SMA filters, deterministic stops, and
  deterministic exits.
- R3 data available: PASS. `XTIUSD.DWX` is present in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, adaptive PnL fitting, grid, martingale,
  external runtime data, or multiple positions per magic.
