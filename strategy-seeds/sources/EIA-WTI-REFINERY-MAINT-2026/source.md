---
source_id: EIA-WTI-REFINERY-MAINT-2026
title: EIA refinery maintenance and planned outage structure
publisher: U.S. Energy Information Administration
source_type: official_government_market_study
status: mined
last_reviewed: 2026-06-27
cards_extracted:
  - eia-wti-ref-fade
  - wti-ref-sqz-brk
  - wti-ref-ramp-pb
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

The cards convert that structural refinery-turnaround regime into Darwinex
`XTIUSD.DWX` D1 price rules. `eia-wti-ref-fade` trades spring/autumn shoulder
stretch rejection as mean reversion. `wti-ref-sqz-brk` isolates the different
pre-summer refinery-utilization ramp: during May-July, buy only when WTI has
compressed, the slow D1 trend is rising, and price closes through a prior D1
range high. `wti-ref-ramp-pb` uses the same May-July ramp lineage but requires
a measured pullback from a recent high and a short rebound close instead of ATR
compression. All cards use MT5 OHLC only and do not ingest EIA outage or
utilization data at runtime.

## Extracted Card

- `eia-wti-ref-fade`: XTIUSD.DWX D1 refinery-turnaround stretch rejection fade.
- `wti-ref-sqz-brk`: XTIUSD.DWX D1 pre-summer refinery-utilization squeeze breakout.
- `wti-ref-ramp-pb`: XTIUSD.DWX D1 pre-summer refinery-utilization pullback continuation.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher.
- R2 mechanical: PASS. Fixed calendar windows, D1 OHLC rejection or
  compression-breakout rules, ATR/SMA thresholds, ATR stop, mean/range exits,
  and max-hold exits are deterministic.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external feed, or
  discretionary input.
