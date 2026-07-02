---
source_id: CME-GAS-SILVER-RELVAL-2026
title: CME natural gas and silver futures relative-value source packet
publisher: CME Group
source_type: exchange_product_source
status: cards_ready
created: 2026-06-30
created_by: Codex
uri: https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.html
cards_extracted:
  - cme-gassilver-ratio
  - cme-gassilver-brk
  - cme-gassilver-rspr
---

# CME Natural Gas / Silver Relative-Value Source

## Source Identity

- Publisher: CME Group.
- Henry Hub Natural Gas futures overview: https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.html.
- Silver futures overview: https://www.cmegroup.com/markets/metals/precious/silver.html.

## Research Use

This source packet is used for structural lineage only. CME lists liquid,
exchange-traded Henry Hub Natural Gas and Silver futures markets. The QM card
constructs Darwinex-native relative-value baskets from the corresponding
validated CFDs, `XNGUSD.DWX` and `XAGUSD.DWX`, and tests whether natural gas
priced against silver mean-reverts, trends after D1 channel breaks, or mean
reverts after short-window relative-return dislocations.

The EA does not ingest CME data, futures curves, settlement files, storage data,
weather feeds, macro feeds, CSV files, APIs, analyst forecasts, or any external
runtime input. It uses only Darwinex MT5 D1 OHLC, broker spread, ATR, and broker
trade-session state for the two registered `.DWX` symbols.

## Guardrails

- Runtime uses `XNGUSD.DWX` and `XAGUSD.DWX` D1 OHLC only.
- Logical basket dispatch must evaluate the card-specific logical basket, not
  standalone leg setfiles.
- No ML, adaptive PnL fitting, grid, martingale, pyramiding, or discretionary
  override.
- One open two-leg package per magic set.

## R-Rules

- R1 reputable source: PASS. CME Group is the exchange operator for Henry Hub
  Natural Gas and Silver futures product pages.
- R2 mechanical: PASS. Fixed D1 log-ratio z-score, return-spread z-score, or
  channel-breakout entry, deterministic exit, ATR hard stops, spread caps, and
  broken-package close.
- R3 data available: PASS. `XNGUSD.DWX` and `XAGUSD.DWX` exist in the DWX
  symbol matrix and have active magic slots.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external API, or
  discretionary input.
