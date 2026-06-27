---
source_id: OPEC-WTI-CONF-BRK-2026
title: OPEC ordinary-meeting WTI structural risk windows
publisher: OPEC / U.S. Energy Information Administration
source_type: official_sources
status: mined
last_reviewed: 2026-06-27
cards_extracted:
  - opec-wti-brk
---

# OPEC WTI Conference Breakout Source

## Source URLs

- OPEC, "OPEC holds 181st Meeting of the Conference", 2021:
  https://www.opec.org/pn-detail/86-15-june-2021.html
- U.S. Energy Information Administration, "Oil supply and OPEC":
  https://www.eia.gov/finance/markets/crudeoil/supply-opec.php

## Research Use

This source packet is used for structural lineage only. OPEC's official
Conference material establishes recurring ordinary-meeting timing around the
June and December meeting cycle. EIA's OPEC supply background establishes why
OPEC production targets and supply policy are load-bearing inputs for crude-oil
price expectations.

The mechanized card does not forecast OPEC decisions and does not ingest OPEC,
EIA, futures-chain, inventory, or news feeds at runtime. It trades only
`XTIUSD.DWX` D1 price confirmation inside fixed June/December meeting-risk
windows: follow a strong D1 channel breakout in either direction, use a fixed
ATR hard stop, and exit on failed breakout, trend failure, window end, or time.

## Extracted Card

- `opec-wti-brk`: XTIUSD.DWX D1 June/December OPEC meeting-risk breakout sleeve.

## R-Rules

- R1 reputable source: PASS. OPEC and EIA official source packet.
- R2 mechanical: PASS. Fixed calendar windows, D1 channel breakout, SMA trend
  filter, ATR stop, and deterministic exits.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, adaptive fitting, grid, martingale,
  external API, CSV, or discretionary input.
