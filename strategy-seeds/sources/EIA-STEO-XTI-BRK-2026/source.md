---
source_id: EIA-STEO-XTI-BRK-2026
title: EIA Short-Term Energy Outlook monthly release schedule and global oil market forecast
publisher: U.S. Energy Information Administration
source_type: official_report
status: cards_ready
created: 2026-07-03
created_by: Codex
uri: https://www.eia.gov/outlooks/steo/
cards_extracted:
  - eia-steo-brk
---

# EIA STEO XTI Breakout Source

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary report hub: https://www.eia.gov/outlooks/steo/
- Release schedule: https://www.eia.gov/outlooks/steo/release_schedule.php
- Global oil markets report: https://www.eia.gov/outlooks/steo/report/global_oil.php

## Research Use

The Short-Term Energy Outlook is a recurring official EIA forecast product
covering global oil supply, demand, inventories, and WTI/Brent price context.
The release schedule defines a deterministic monthly timing rule: first Tuesday
after the first Thursday of each month, with occasional Wednesday delay after a
Monday federal holiday.

The QM extraction mechanizes a price-only D1 proxy for this monthly information
window on `XTIUSD.DWX`: if the completed STEO release proxy bar produces an
ATR-sized directional breakout, the EA follows the next-day continuation for a
short fixed hold with ATR stop and target. Runtime does not read the EIA site,
CSV files, APIs, analyst forecasts, or release contents.

## Guardrails

- Runtime uses Darwinex MT5 OHLC, ATR, spread, and broker calendar only.
- No external API calls, CSV feeds, futures curve, inventory feed, analyst
  forecast, discretionary override, or news scraping.
- No ML, adaptive PnL fitting, grid, martingale, or pyramiding.
- One position per `XTIUSD.DWX` magic slot.

## R-Rules

- R1 reputable source: PASS. Single official EIA source lineage.
- R2 mechanical: PASS. Fixed monthly calendar proxy, D1 breakout confirmation,
  ATR hard stop/target, and deterministic time exit.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic single-position D1 sleeve.
