---
source_id: OPEC-MOMR-XTI-BRK-2026
title: OPEC Monthly Oil Market Report WTI information-window breakout
publisher: Organization of the Petroleum Exporting Countries
source_type: official_report
status: cards_ready
created: 2026-07-03
created_by: Codex
uri: https://www.opec.org/monthly-oil-market-report.html
cards_extracted:
  - opec-momr-brk
---

# OPEC Monthly Oil Market Report WTI Information Window

## Source Identity

- Publisher: Organization of the Petroleum Exporting Countries.
- Primary source: OPEC, "Monthly Oil Market Report", URL
  https://www.opec.org/monthly-oil-market-report.html.

## Research Use

OPEC describes its Monthly Oil Market Report as covering major world oil-market
issues and providing an outlook for crude-oil market developments over the
coming year, including oil demand, supply, and market balance. The same OPEC
page publishes a dated monthly release schedule; the 2026 dates cluster around
the 10th through 14th calendar day of each month.

The QM expression does not ingest OPEC reports, appendix data, forecasts, APIs,
CSV files, or web content at runtime. It uses a deterministic mid-month OPEC
MOMR proxy window on `XTIUSD.DWX` D1 bars. If the completed proxy-window bar is
an ATR-sized directional breakout beyond the prior D1 range, the EA follows the
next-day continuation for a short fixed hold with ATR stop and target.

This is separate from the existing `opec-wti-brk` ordinary-meeting-risk sleeve,
which only targets June/December OPEC meeting windows, and from the EIA STEO
and IEA OMR monthly information-window sleeves.

## Extracted Card

- `opec-momr-brk`: XTIUSD.DWX D1 OPEC Monthly Oil Market Report proxy-window
  breakout continuation.

## R-Rules

- R1 reputable source: PASS. OPEC is the official publisher of the Monthly Oil
  Market Report and release dates.
- R2 mechanical: PASS. Fixed D1 calendar proxy, Donchian breakout, ATR range
  and body filters, ATR stop/target, spread cap, and max-hold exit are
  deterministic.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol universe.
- R4 no ML/banned logic: PASS. No ML, external runtime feed, grid, martingale,
  pyramiding, or adaptive sizing.
