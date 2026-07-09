---
source_id: EIA-XTI-FIELDPROD-FADE-2026
title: EIA weekly crude field-production failed-probe fade source packet
publisher: U.S. Energy Information Administration
source_type: official_government_data_series
status: mined
last_reviewed: 2026-07-09
cards_extracted:
  - xti-prod-fade
---

# EIA Weekly Crude Field-Production Failed-Probe Fade Source

## Source URLs

- U.S. Energy Information Administration, "Weekly U.S. Field Production of
  Crude Oil": https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCRFPUS2
- U.S. Energy Information Administration, "Weekly Petroleum Status Report":
  https://www.eia.gov/petroleum/supply/weekly/
- U.S. Energy Information Administration, "Weekly Petroleum Status Report
  Schedule": https://www.eia.gov/petroleum/supply/weekly/schedule.php

## Research Use

This source packet uses official EIA weekly crude field-production data and the
regular WPSR publication cadence only as structural lineage. The executable EA
does not read EIA data, schedules, APIs, CSV files, analyst forecasts, volume,
open interest, or futures curves at runtime.

The mechanized edge asks whether WTI D1 bars around the weekly petroleum
release window sometimes over-extend beyond a medium crude channel and then
reclaim it. The card fades that failed probe, with ATR-sized range and rejection
tail requirements, toward a slow SMA mean.

## Extracted Card

- `xti-prod-fade`: `XTIUSD.DWX` D1 EIA field-production release-window
  failed-probe fade.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher; the cited pages are official EIA pages.
- R2 mechanical: PASS. Fixed Wednesday/Thursday WPSR proxy window, D1 channel
  probe/reclaim, SMA stretch, ATR range, rejection-tail filter, ATR stop/target,
  time exit, mean exit, and one-position guard are deterministic.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix with D1
  history available for Q02.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external runtime feed,
  unbounded averaging, or discretionary input.

## Non-Duplicate Boundary

This is not `QM5_13028_xti-prod-brk`, which follows close-confirmed
field-production-window breakouts after compression. This card requires a
failed probe outside the prior channel and a close back inside the channel, then
fades the move. It is also not WPSR inventory momentum/fade/inside-bar/pre-event
logic, DPR/PSM monthly production logic, import/export flow logic, PADD/Cushing,
SPR, refinery, hurricane, OPEC/IEA/STEO/JODI, COT, rig-count, roll/expiry,
calendar month/weekday seasonality, oil-gas ratio, oil-metal ratio, XNG, XAU/XAG,
index, or commodity RSI logic.
