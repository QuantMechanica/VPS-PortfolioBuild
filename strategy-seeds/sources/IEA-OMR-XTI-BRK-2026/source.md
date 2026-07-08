---
source_id: IEA-OMR-XTI-BRK-2026
title: International Energy Agency Oil Market Report WTI breakout proxy
publisher: International Energy Agency
source_type: official_energy_market_report
status: cards_ready
created: 2026-07-08
created_by: Codex
uri: https://www.iea.org/data-and-statistics/data-product/oil-market-report-omr
cards_extracted:
  - iea-omr-brk
---

# IEA OMR XTI Breakout Source

## Source Identity

- Primary source: International Energy Agency, Oil Market Report (OMR):
  https://www.iea.org/data-and-statistics/data-product/oil-market-report-omr
- Context source: International Energy Agency monthly Oil Market Report pages,
  e.g. https://www.iea.org/reports/oil-market-report-june-2026

## Research Use

The IEA OMR is an official recurring oil-market report covering global demand,
supply, inventories, refinery activity, and prices. This source is used only
for structural lineage around a monthly crude-oil information window.

`iea-omr-brk` expresses the lineage as an OHLC-only Darwinex `XTIUSD.DWX` D1
breakout proxy. The EA does not read IEA report contents, release calendars,
news, forecasts, PDFs, APIs, CSV files, futures curves, or inventory data at
runtime. It trades only closed D1 price action inside a deterministic
mid-month broker-calendar proxy window.

## Guardrails

- Runtime uses native MT5 `XTIUSD.DWX` D1 OHLC, spread, ATR, broker calendar,
  and V5 framework state only.
- No external data calls, CSV/API feeds, report parsing, analyst forecasts, ML,
  adaptive PnL fitting, grid, martingale, or discretionary override.
- One position per `XTIUSD.DWX` magic slot.

## R-Rules

- R1 reputable source: PASS. Official IEA energy-market report source with URL.
- R2 mechanical: PASS. Fixed calendar proxy, D1 Donchian breakout, ATR stop and
  target, spread cap, and time exit.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic single-symbol structural sleeve.
