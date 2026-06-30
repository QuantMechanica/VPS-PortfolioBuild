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

One card is extracted for a structural WTI CFD sleeve:

- `wti-usd-confirm`: XTIUSD.DWX D1 WTI trend package confirmed by broad USD
  weakness/strength through a Darwinex-native EURUSD.DWX proxy.

## Evidence Notes

- The EIA working paper studies the oil-price and exchange-rate relationship,
  including the frequently discussed link between U.S. dollar strength and
  oil-price weakness.
- The QM implementation does not ingest EIA data, dollar-index data, exchange
  rates outside MT5, futures curves, macro releases, APIs, CSV files, or any
  external feed at runtime.
- Runtime uses closed Darwinex MT5 D1 bars only: `XTIUSD.DWX` as the traded
  WTI proxy and `EURUSD.DWX` as a broad USD weakness/strength proxy.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive parameter fitting, grid, martingale, or pyramiding.
- Single traded position on XTIUSD.DWX, one magic slot; EURUSD.DWX is read-only.

## R-Rules

- R1 reputable source: PASS. Single official EIA working paper URL.
- R2 mechanical: PASS. Fixed weekly gate, fixed D1 return lookbacks, SMA trend
  confirmation, ATR hard stop, signal-flip exit, and max-hold exit.
- R3 data available: PASS. `XTIUSD.DWX` and `EURUSD.DWX` exist in the DWX symbol
  matrix.
- R4 no ML/banned logic: PASS. Deterministic, one position per magic, no ML,
  no grid, no martingale, no external runtime data.
