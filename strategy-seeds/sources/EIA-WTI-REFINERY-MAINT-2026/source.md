---
source_id: EIA-WTI-REFINERY-MAINT-2026
title: EIA refinery maintenance and planned outage structure
publisher: U.S. Energy Information Administration
source_type: official_government_market_study
status: mined
last_reviewed: 2026-06-27
cards_extracted:
  - eia-wti-ref-fade
---

# EIA WTI Refinery Maintenance Source

## Source URLs

- U.S. Energy Information Administration, "Refinery outages: planned and unplanned outages, 2007-2011": https://www.eia.gov/petroleum/articles/refoutagesindex.php
- U.S. Energy Information Administration, "U.S. refinery utilization rates slightly higher than last year heading into summer": https://www.eia.gov/todayinenergy/detail.php?id=61543

## Research Use

This source is used only for structural lineage. EIA documents refinery planned
and unplanned outage behavior and discusses refinery utilization around the
pre-summer maintenance transition. The mechanized card does not ingest EIA
outage data, refinery utilization series, APIs, CSV files, or discretionary
maintenance calendars at runtime.

The card converts that structural refinery-turnaround regime into a Darwinex
`XTIUSD.DWX` D1 price rule: during spring and autumn shoulder months, fade
stretched WTI bars that reject away from a slow D1 mean, then exit on mean
reversion or a short time stop.

## Extracted Card

- `eia-wti-ref-fade`: XTIUSD.DWX D1 refinery-turnaround stretch rejection fade.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher.
- R2 mechanical: PASS. Fixed calendar windows, D1 OHLC rejection, ATR/SMA
  thresholds, ATR stop, mean exit, and max-hold exit are deterministic.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external feed, or
  discretionary input.
