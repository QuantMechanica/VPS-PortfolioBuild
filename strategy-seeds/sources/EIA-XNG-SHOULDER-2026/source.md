---
source_id: EIA-XNG-SHOULDER-2026
title: EIA natural gas shoulder-season demand lull
status: cards_ready
created: 2026-06-27
created_by: Codex
source_type: official_energy_statistics
uri: https://www.eia.gov/todayinenergy/detail.php?id=22892
---

# EIA Natural Gas Shoulder-Season Demand Lull

## Source Identity

- Publisher: U.S. Energy Information Administration
- Primary source: EIA Today in Energy, "Natural gas consumption, production respond to seasonal changes", 2015-09-24, URL https://www.eia.gov/todayinenergy/detail.php?id=22892
- Supplemental source: EIA Weekly Natural Gas Storage Report, URL https://www.eia.gov/naturalgas/storage/

## Mining Scope

One card was extracted for a structural natural-gas CFD sleeve:

- `eia-xng-shfade`: XNGUSD.DWX D1 shoulder-season failed-rally fade.

## Evidence Notes

- EIA describes U.S. natural gas demand as seasonal, with winter heating and summer electric-sector peaks.
- EIA describes lower heating and cooling demand in spring and fall shoulder periods.
- EIA storage material supports the structural context that injections rebuild inventories outside winter withdrawal stress.
- The QM implementation does not ingest EIA, storage, weather, power-load, or futures-curve data at runtime. It mechanizes the source lineage as fixed shoulder-season windows and uses only Darwinex MT5 OHLC data for stretch, rejection, and risk control.

## Guardrails

- No external API calls, weather feed, storage report feed, power-load feed, or futures-curve feed.
- No ML, adaptive PnL fitting, grid, or martingale.
- One position per XNGUSD.DWX magic slot.
