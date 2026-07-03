---
source_id: EIA-OILGAS-RSPREAD-2026
title: EIA crude oil and natural gas relationship return-spread research
status: cards_ready
created: 2026-07-03
created_by: Codex
source_type: government_energy_research
uri: https://www.eia.gov/naturalgas/articles/reloilgaspriindex.php
cards_extracted:
  - xbr-xng-rspr
---

# EIA Oil/Gas Return-Spread Research

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: EIA, "An Analysis of Price Volatility in Natural Gas
  Markets", section on the relationship between crude oil and natural gas
  prices.
- URL: https://www.eia.gov/naturalgas/articles/reloilgaspriindex.php

## Research Use

EIA documents that crude-oil and natural-gas prices have a meaningful but
unstable economic relationship. That relationship is not treated as a fixed
price ratio. The QM card tests a lower-frequency relative return dislocation:
when Brent's fixed-window return has moved unusually far versus natural gas,
standardize the return spread against its own recent D1 history and trade a
two-leg reversion basket.

The runtime implementation uses only Darwinex MT5 D1 close data, spread, ATR,
broker calendar, and V5 framework state. It does not ingest EIA data, futures
curves, inventory data, CFTC data, analyst forecasts, APIs, CSV files, or ML
models at runtime.

Secondary implementation lineage is the pair-spread mean-reversion mechanic
from Ernest P. Chan, *Algorithmic Trading: Winning Strategies and Their
Rationale* (2013), already used in the V5 basket family. The EIA source supplies
the oil/gas economic relationship; the Chan lineage supplies the mechanical
z-score mean-reversion form.

## Guardrails

- No external runtime data calls.
- No ML, adaptive PnL fitting, grid, martingale, or standalone commodity leg.
- Basket has two separate registered magic slots, one per traded symbol.
- Q02 must evaluate the logical basket symbol, not individual leg PnL.
