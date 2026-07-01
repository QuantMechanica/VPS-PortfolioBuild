---
source_id: CME-OIL-GOLD-RATIO-2024
title: "CME Group: Through the Lens of Gold"
source_type: exchange_article
url: "https://www.cmegroup.com/articles/2024/through-the-lens-of-gold.html"
status: cards_ready
last_updated: 2026-06-27
---

# CME Oil/Gold Ratio Source Notes

## Source

CME Group, "Through the Lens of Gold", 2024:
https://www.cmegroup.com/articles/2024/through-the-lens-of-gold.html

## Extracted Strategy

- `cme-oilgold-ratio`: D1 `XTIUSD.DWX` / `XAUUSD.DWX` log-ratio reversion
  basket.
- `oilgold-rspread`: D1 `XTIUSD.DWX` / `XAUUSD.DWX` return-spread reversion
  basket.

## Research Summary

The source frames crude oil prices through gold as a relative-value lens rather
than a standalone oil forecast. The QM implementation uses that lineage only to
define the tradable pair: oil as the ratio numerator and gold as the hedge leg.
Runtime logic uses Darwinex MT5 D1 OHLC only.

## R1-R4 Notes

- R1 single source: PASS. One CME Group exchange article.
- R2 mechanical: PASS. Card supplies deterministic D1 log-spread z-score entry,
  mean-reversion exit, ATR hard stops, and one package at a time.
- R3 data available: PASS. `XTIUSD.DWX` and `XAUUSD.DWX` are present in
  `framework/registry/dwx_symbol_matrix.csv`.
- R4 compliant: PASS. No ML, grid, martingale, external data, or live-only
  dependency.

## Non-Duplicate Check

- Not `QM5_12577_cme-xauxag-ratio`: this is energy versus gold, not an
  intra-metals ratio.
- Not `QM5_12578_eia-oilgas-ratio`: this uses gold as the denominator and CME
  oil-through-gold lineage, not oil versus natural gas.
- Not the WTI seasonal/news sleeve group: no calendar, OPEC, WPSR, refinery, or
  hurricane rule.
- Not `QM5_12567_cum-rsi2-commodity`: no RSI or short-horizon pullback logic.
- `oilgold-rspread` is not a duplicate of the existing oil/gold ratio cards:
  it fades a fixed-window relative-return shock rather than the absolute
  oil/gold ratio level or a ratio channel breakout.
