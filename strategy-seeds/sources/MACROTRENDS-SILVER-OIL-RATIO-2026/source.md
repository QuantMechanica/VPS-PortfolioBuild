---
source_id: MACROTRENDS-SILVER-OIL-RATIO-2026
title: "Macrotrends: Silver to Oil Ratio - Historical Chart"
source_type: market_data_chart
url: "https://www.macrotrends.net/2612/silver-to-oil-ratio-historical-chart"
status: cards_ready
last_updated: 2026-06-27
---

# Macrotrends Silver/Oil Ratio Source Notes

## Source

Macrotrends, "Silver to Oil Ratio - Historical Chart":
https://www.macrotrends.net/2612/silver-to-oil-ratio-historical-chart

## Extracted Strategy

- `oil-silver-ratio`: D1 `XTIUSD.DWX` / `XAGUSD.DWX` log-ratio reversion
  basket.
- `oil-silver-brk`: D1 `XTIUSD.DWX` / `XAGUSD.DWX` log-ratio breakout
  basket.

## Research Summary

The source frames silver and WTI crude oil as a long-run relative-value ratio.
The QM implementation uses that lineage only to define a tradable two-leg
commodity basket: oil as the numerator and silver as the hedge leg. Runtime
logic uses Darwinex MT5 D1 OHLC only; it does not call Macrotrends or import
any external data.

## R1-R4 Notes

- R1 single source: PASS. One public Macrotrends market-data chart.
- R2 mechanical: PASS. Cards supply deterministic D1 log-spread z-score entry,
  fixed exit rules, ATR hard stops, and one package at a time.
- R3 data available: PASS. `XTIUSD.DWX` and `XAGUSD.DWX` are present in
  `framework/registry/dwx_symbol_matrix.csv`.
- R4 compliant: PASS. No ML, adaptive PnL fitting, grid, martingale, external
  runtime data, or live-only dependency.

## Non-Duplicate Check

- Not `QM5_12577_cme-xauxag-ratio`: this is energy versus silver, not
  gold-versus-silver metal value.
- `oil-silver-brk` is not `QM5_12606_oil-silver-ratio`: it follows D1 ratio
  breakouts and exits on signal failure or time stop instead of fading z-score
  extremes into mean reversion.
- Not `QM5_12578_eia-oilgas-ratio`: this uses silver as the denominator, not
  natural gas.
- Not `QM5_12604_cme-oilgold-ratio` or `QM5_12605_cme-oilgold-brk`: the hedge
  leg is silver and the card source is the silver/oil ratio, not oil/gold.
- Not the WTI seasonal/news sleeve group: no calendar, inventory, OPEC, WPSR,
  refinery, or hurricane rule.
- Not `QM5_12567_cum-rsi2-commodity`: no RSI or short-horizon pullback logic.
