---
source_id: EIA-XNG-MONTH-ORB-2026
title: EIA natural gas seasonality plus monthly opening-range structure
status: cards_ready
created: 2026-06-30
created_by: Codex
source_type: official_energy_statistics_plus_market_structure
uri: https://www.eia.gov/todayinenergy/detail.php?id=22892
---

# EIA Natural Gas Monthly Opening-Range Source

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: EIA Today in Energy, "Natural gas consumption, production respond to seasonal changes", 2015-09-24, URL https://www.eia.gov/todayinenergy/detail.php?id=22892.
- Supplement: Crabel, Toby. *Day Trading with Short-Term Price Patterns and Opening Range Breakout*. Traders Press, 1990.
- Supplement: CME Group, "Henry Hub Natural Gas Futures contract specifications", URL https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.contractSpecs.html.

## Mining Scope

One card was extracted for a structural natural-gas CFD sleeve:

- `xng-month-orb`: XNGUSD.DWX D1 monthly opening-range breakout.

## Evidence Notes

- EIA documents that U.S. natural gas consumption and production respond to seasonal changes, with distinct winter heating and summer electric-sector demand peaks.
- CME Henry Hub natural gas futures provide the listed monthly-contract market structure context for recurring calendar-month positioning and hedging.
- The QM implementation does not ingest EIA, storage, weather, power-load, futures-curve, volume, open-interest, CSV, or API data at runtime. It mechanizes the source lineage through a deterministic month-opening range on Darwinex `XNGUSD.DWX` D1 bars.

## Guardrails

- No external API calls, weather feed, storage report feed, power-load feed, futures-curve feed, CSV, or discretionary input.
- No ML, adaptive PnL fitting, grid, martingale, or pyramiding.
- One position per `XNGUSD.DWX` magic slot.
