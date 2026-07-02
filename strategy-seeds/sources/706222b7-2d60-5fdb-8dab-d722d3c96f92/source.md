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
- Title: "Natural gas use features two seasonal peaks per year"
- Date: 2015-09-11
- URL: https://www.eia.gov/todayinenergy/detail.php?id=22892

## Mining Scope

Five cards were extracted for structural natural-gas CFD sleeves:

- `eia-xng-season`: XNGUSD.DWX D1 monthly seasonal demand/shoulder regime with price confirmation.
- `xngusd-winter-withdrawal-long`: XNGUSD.DWX D1 winter withdrawal/heating-demand long-only regime with price confirmation.
- `xngusd-spring-shoulder-short`: XNGUSD.DWX D1 spring shoulder demand-lull short-only regime with price confirmation.
- `xngusd-summer-power-long`: XNGUSD.DWX D1 summer electric-sector demand long-only regime with price confirmation.
- `xngusd-fall-storage-short`: XNGUSD.DWX D1 fall shoulder/storage-fill short-only regime with price confirmation.
- `xngusd-seasonal-dual-peak`: XNGUSD.DWX D1 long-only combined winter/summer demand-peak regime with price confirmation.
- `xng-oct-turn-long`: XNGUSD.DWX D1 October-November autumn-to-winter transition long with weekly price-turn confirmation.

## Evidence Notes

- The source describes natural gas consumption as seasonally shaped, with peaks tied to winter heating demand and summer electric-sector demand and lower use during the spring/fall shoulder periods.
- The QM implementations do not ingest external EIA data at runtime. They mechanize the calendar seasonality as fixed windows and use only Darwinex MT5 OHLC data for price confirmation and risk control.
- This source is intentionally single-source for R1 lineage.
- The dual-peak card is intentionally long-only. It does not include the shoulder-season shorts from the broad `eia-xng-season` card and is tested as a separate correlation candidate by Q02+.

## Guardrails

- No external API calls or storage-report data in the EA.
- No ML, no adaptive parameter fitting, no grid, no martingale.
- One position per XNGUSD.DWX magic slot.
