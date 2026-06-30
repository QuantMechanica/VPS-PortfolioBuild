---
source_id: EIA-OIL-USD-FX-2017
title: EIA oil prices and exchange rates working paper
status: cards_ready
created: 2026-06-30
created_by: Codex
source_type: official_energy_research_working_paper
uri: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
---

# EIA Oil And Dollar Exchange-Rate Source

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", EIA Working Paper,
  June 2017, URL https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf.

## Mining Scope

Two cards are extracted for structural WTI CFD sleeves:

- `wti-usd-confirm`: XTIUSD.DWX D1 WTI trend package confirmed by broad USD
  weakness/strength through a Darwinex-native EURUSD.DWX proxy.
- `wti-eurusd-spread`: two-leg XTIUSD.DWX/EURUSD.DWX D1 relative-value
  basket that fades temporary dislocations in the oil-dollar linkage.

## Evidence Notes

- The EIA working paper studies the oil-price and exchange-rate relationship,
  including the frequently discussed link between U.S. dollar strength and
  oil-price weakness.
- The QM implementation does not ingest EIA data, dollar-index data, exchange
  rates outside MT5, futures curves, macro releases, APIs, CSV files, or any
  external feed at runtime.
- Runtime uses closed Darwinex MT5 D1 bars only: `XTIUSD.DWX` as the WTI proxy
  and `EURUSD.DWX` as a broad USD weakness/strength proxy.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive parameter fitting, grid, martingale, or pyramiding.
- Cards extracted from this source may be either one-leg confirmation trades or
  two-leg baskets, but each EA uses only registered DWX symbols and one open
  position per magic slot.

## R-Rules

- R1 reputable source: PASS. Single official EIA working paper URL.
- R2 mechanical: PASS. Fixed weekly or D1 gates, fixed closed-bar lookbacks,
  deterministic trend or spread-z rules, ATR hard stops, signal or z-score
  exits, and max-hold exits.
- R3 data available: PASS. `XTIUSD.DWX` and `EURUSD.DWX` exist in the DWX symbol
  matrix.
- R4 no ML/banned logic: PASS. Deterministic, one position per magic slot, no
  ML, no grid, no martingale, no external runtime data.
