---
source_id: EIA-CUSHING-STORAGE-2021
title: EIA Cushing crude oil storage and WTI delivery-hub tightness
status: cards_ready
created: 2026-06-30
created_by: Codex
source_type: official_energy_statistics
uri: https://www.eia.gov/todayinenergy/detail.php?id=49636
---

# EIA Cushing Storage Tightness

## Source Identity

- Publisher: U.S. Energy Information Administration
- Primary source: EIA Today in Energy, "Crude oil inventories at Cushing, Oklahoma, remain low after summer draws", October 21, 2021.
- URL: https://www.eia.gov/todayinenergy/detail.php?id=49636

## Mining Scope

Two cards were extracted for structural WTI crude-oil CFD sleeves:

- `wti-cushing-brk`: XTIUSD.DWX D1 Cushing delivery-hub tightness breakout proxy.
- `wti-cushing-fade`: XTIUSD.DWX D1 failed tightness-spike relief fade proxy.

## Evidence Notes

- EIA identifies Cushing, Oklahoma as the delivery point for the NYMEX WTI crude-oil futures contract.
- EIA describes Cushing as a major storage hub, with inventories and utilization materially affected by supply and refinery/consumption flows.
- The source discusses low Cushing inventories after sustained draws, which is used only as structural lineage for a tightness regime.
- The QM implementations do not ingest EIA inventory, API, CSV, futures-curve, storage, refinery, or pipeline data at runtime. They express the lineage as Darwinex-native D1 price proxies on `XTIUSD.DWX`.

## Guardrails

- Runtime data is limited to MT5 `XTIUSD.DWX` OHLC, broker calendar, spread, and ATR/SMA calculations.
- No ML, adaptive PnL fitting, grid, martingale, or multiple positions per magic.
- One `XTIUSD.DWX` magic slot only.
