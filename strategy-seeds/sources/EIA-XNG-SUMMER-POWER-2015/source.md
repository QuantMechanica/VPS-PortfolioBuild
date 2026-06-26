---
source_id: EIA-XNG-SUMMER-POWER-2015
title: EIA natural gas summer electric-sector demand
status: cards_ready
created: 2026-06-26
created_by: Codex
source_type: official_energy_statistics
uri: https://www.eia.gov/todayinenergy/detail.php?id=22892
---

# EIA Natural Gas Summer Electric-Sector Demand

## Source Identity

- Publisher: U.S. Energy Information Administration
- Primary source: EIA Today in Energy, "Natural gas consumption, production respond to seasonal changes", 2015-09-24, URL https://www.eia.gov/todayinenergy/detail.php?id=22892

## Mining Scope

One card was extracted for a second structural natural-gas CFD sleeve:

- `eia-xng-sum-sqz`: XNGUSD.DWX D1 summer power-burn volatility-squeeze breakout.

## Evidence Notes

- EIA describes U.S. natural gas consumption as seasonal, with consumption peaks in winter heating demand and summer electric-sector demand.
- This card isolates the summer electric-sector demand component instead of using the existing broad monthly season map.
- The QM implementation does not ingest EIA, weather, storage, or power-load data at runtime. It uses the source only for structural lineage and trades deterministic Darwinex MT5 OHLC compression/breakout rules.

## Guardrails

- No external API calls, weather feed, storage report feed, power-load feed, or futures-curve feed.
- No ML, adaptive PnL fitting, grid, or martingale.
- One position per XNGUSD.DWX magic slot.
