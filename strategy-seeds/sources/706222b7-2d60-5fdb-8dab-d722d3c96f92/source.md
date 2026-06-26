---
source_id: 706222b7-2d60-5fdb-8dab-d722d3c96f92
title: EIA Today in Energy natural gas seasonal peaks
status: cards_ready
created: 2026-06-26
created_by: Codex
source_type: web_blog
uri: https://www.eia.gov/todayinenergy/detail.php?id=22892
---

# EIA Today in Energy - Natural Gas Seasonal Peaks

## Source Identity

- Publisher: U.S. Energy Information Administration
- Title: "Natural gas consumption, production respond to seasonal changes"
- Date: 2015-09-24
- URL: https://www.eia.gov/todayinenergy/detail.php?id=22892

## Mining Scope

One card was extracted for a structural natural-gas CFD sleeve:

- `eia-xng-season`: XNGUSD.DWX D1 monthly seasonal demand/shoulder regime with price confirmation.

## Evidence Notes

- The source describes natural gas consumption and production as seasonally shaped, with consumption peaks tied to winter heating demand and summer electric-sector demand.
- The QM implementation does not ingest external EIA data at runtime. It mechanizes the calendar seasonality as fixed monthly windows and uses only Darwinex MT5 OHLC data for price confirmation and risk control.
- This source is intentionally single-source for R1 lineage.

## Guardrails

- No external API calls or storage-report data in the EA.
- No ML, no adaptive parameter fitting, no grid, no martingale.
- One position per XNGUSD.DWX magic slot.
