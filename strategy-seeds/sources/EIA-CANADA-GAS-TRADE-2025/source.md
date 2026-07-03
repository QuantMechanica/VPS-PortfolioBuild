---
source_id: EIA-CANADA-GAS-TRADE-2025
title: EIA U.S.-Canada energy trade and natural-gas pipeline flows
status: cards_ready
created: 2026-07-03
created_by: Codex
source_type: government_energy_research
uri: https://www.eia.gov/todayinenergy/detail.php?id=65825
---

# EIA Canada Gas Trade Source

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: EIA Today in Energy, "Last year's U.S.-Canada energy trade
  was valued around $150 billion", published 2025-07-30 and updated 2025-08-04.
- URL: https://www.eia.gov/todayinenergy/detail.php?id=65825

## Mining Scope

One card is extracted for a structural natural-gas/CAD basket:

- `xng-cad-rspread`: D1 `XNGUSD.DWX` / `USDCAD.DWX` CAD-denominated gas spread
  mean reversion.

## Evidence Notes

- EIA describes the Canada/U.S. energy trade channel and reports that natural gas
  is traded through cross-border pipelines, with U.S. imports from Canada and
  U.S. exports to Canada both material in 2024.
- This source is used only for structural lineage around a Canada-linked natural
  gas price/FX channel. It does not provide a trading performance claim.
- The QM implementation does not ingest EIA data, trade volumes, tariffs,
  forecasts, APIs, CSV files, or any external feed at runtime.
- Runtime uses closed Darwinex MT5 D1 bars only: `XNGUSD.DWX` as the natural-gas
  proxy and `USDCAD.DWX` as the CAD/USD FX proxy.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive parameter fitting, grid, martingale, or pyramiding.
- Two registered DWX symbols only, with one open position per magic slot.

## R-Rules

- R1 reputable source: PASS. Single official EIA Today in Energy source URL.
- R2 mechanical: PASS. Fixed D1 log-spread z-score entries, mean exit, ATR hard
  stops, max-hold exit, spread caps, and Friday close.
- R3 data available: PASS. `XNGUSD.DWX` and `USDCAD.DWX` exist in the DWX symbol
  matrix.
- R4 no ML/banned logic: PASS. Deterministic, one position per magic slot, no
  ML, no grid, no martingale, no external runtime data.
