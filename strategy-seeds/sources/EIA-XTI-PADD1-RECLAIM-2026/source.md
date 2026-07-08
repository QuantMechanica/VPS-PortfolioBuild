---
source_id: EIA-XTI-PADD1-RECLAIM-2026
title: EIA East Coast PADD 1 crude-stock failed-breakdown WTI proxy
publisher: U.S. Energy Information Administration
source_type: official_energy_statistics
status: cards_ready
created: 2026-07-08
created_by: Codex
uri: https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP11
cards_extracted:
  - xti-padd1-reclaim
---

# EIA East Coast PADD 1 Crude-Stock Source

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: EIA weekly East Coast (PADD 1) ending stocks excluding SPR of
  crude oil.
- Primary URL: https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP11
- Supporting release family: EIA Weekly Petroleum Status Report.
- Supporting URL: https://www.eia.gov/petroleum/supply/weekly/

## Research Use

This source is used only for official structural lineage. EIA publishes PADD 1
East Coast crude-stock data inside the weekly petroleum statistics family, and
the WPSR gives the recurring market-information window. The QM implementation
does not read EIA data, CSV files, XLS downloads, APIs, inventories, refinery
flows, imports, exports, analyst forecasts, or discretionary inputs at runtime.

The card maps the lineage to a Darwinex-native WTI proxy: during fixed East
Coast winter/late-year stock-sensitivity windows, a D1 failed-breakdown and
reclaim on `XTIUSD.DWX` is treated as a price-confirmed reversal signal after
the weekly petroleum report window.

## Guardrails

- Runtime uses only MT5 `XTIUSD.DWX` D1 OHLC, broker spread, ATR, SMA, broker
  calendar state, and V5 framework controls.
- No external API calls or CSV dependencies.
- No ML, adaptive PnL fitting, grid, martingale, pyramiding, or discretionary
  override.
- One open position per `XTIUSD.DWX` magic slot.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher; the primary data series and WPSR are official EIA pages.
- R2 mechanical: PASS. Fixed calendar windows, post-WPSR weekday proxy, D1
  failed-breakdown reclaim, SMA trend gate, ATR hard stop/target, spread cap,
  one-entry-per-month limiter, and deterministic exits.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external runtime feed,
  or multi-position basket dependency.
