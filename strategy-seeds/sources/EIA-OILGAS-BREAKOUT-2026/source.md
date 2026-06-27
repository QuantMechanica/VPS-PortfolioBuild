---
source_id: EIA-OILGAS-BREAKOUT-2026
title: EIA crude oil and natural gas price relationship breakout research
status: cards_ready
created: 2026-06-27
created_by: Codex
source_type: government_energy_research
uri: https://www.eia.gov/naturalgas/articles/reloilgaspriindex.php
---

# EIA Oil/Gas Breakout Research

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: EIA, "An Analysis of Price Volatility in Natural Gas Markets", section on the relationship between crude oil and natural gas prices.
- URL: https://www.eia.gov/naturalgas/articles/reloilgaspriindex.php

## Mining Scope

One card was extracted for a structural energy relative-value sleeve:

- `eia-oilgas-breakout`: XTIUSD.DWX/XNGUSD.DWX D1 oil-gas log-ratio channel breakout basket.

## Evidence Notes

- EIA documents that crude oil and natural gas prices have a significant but not mechanically constant relationship.
- EIA also documents periods where the relationship changes or decouples, which is the structural basis for testing persistence after an oil/gas ratio channel breakout rather than fading the ratio.
- The QM implementation does not ingest EIA data, physical spreads, futures curves, inventories, or external APIs at runtime. It uses the EIA source only for structural lineage and trades Darwinex MT5 D1 OHLC for XTIUSD.DWX and XNGUSD.DWX.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive PnL fitting, grid, martingale, or standalone commodity leg.
- Basket has two separate registered magic slots, one per traded symbol.
