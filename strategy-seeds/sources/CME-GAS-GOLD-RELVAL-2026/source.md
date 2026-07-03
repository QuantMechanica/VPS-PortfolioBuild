---
source_id: CME-GAS-GOLD-RELVAL-2026
title: CME natural gas and gold futures relative-value source packet
publisher: CME Group
source_type: exchange_product_source
status: cards_ready
created: 2026-06-30
created_by: Codex
uri: https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.html
cards_extracted:
  - cme-gasgold-ratio
  - xnggold-rspread
---

# CME Natural Gas / Gold Relative-Value Source

## Source Identity

- Publisher: CME Group.
- Henry Hub Natural Gas futures overview: https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.html.
- Gold futures overview: https://www.cmegroup.com/markets/metals/precious/gold.html.

## Research Use

This source packet is used for structural lineage only. CME lists liquid,
exchange-traded Henry Hub Natural Gas and Gold futures markets. The QM card
constructs Darwinex-native relative-value baskets from the corresponding
validated CFDs, `XNGUSD.DWX` and `XAUUSD.DWX`. The first card tests whether
extreme deviations in natural gas priced against gold mean-revert at D1
frequency. The second card tests a distinct short-window return-spread shock,
where natural gas and gold relative returns have temporarily diverged.

The EA does not ingest CME data, futures curves, settlement files, inventory
data, weather feeds, macro feeds, CSV files, APIs, analyst forecasts, or any
external runtime input. It uses only Darwinex MT5 D1 OHLC, broker spread, ATR,
and broker trade-session state for the two registered `.DWX` symbols.

## Guardrails

- Runtime uses `XNGUSD.DWX` and `XAUUSD.DWX` D1 OHLC only.
- Logical basket dispatch must evaluate `QM5_12824_XNG_XAU_RATIO_D1` or
  `QM5_12993_XNG_XAU_RSPREAD_D1`, not standalone leg setfiles.
- No ML, adaptive PnL fitting, grid, martingale, pyramiding, or discretionary
  override.
- One open two-leg package per magic set.

## R-Rules

- R1 reputable source: PASS. CME Group is the exchange operator for Henry Hub
  Natural Gas and Gold futures product pages.
- R2 mechanical: PASS. Fixed D1 log-ratio or return-spread z-score entry,
  deterministic mean-reversion exit, ATR hard stops, spread caps, and
  broken-package close.
- R3 data available: PASS. `XNGUSD.DWX` and `XAUUSD.DWX` exist in the DWX symbol
  matrix and have active magic slots.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external API, or
  discretionary input.
