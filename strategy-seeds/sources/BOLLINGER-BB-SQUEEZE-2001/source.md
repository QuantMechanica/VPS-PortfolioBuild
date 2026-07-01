---
source_id: BOLLINGER-BB-SQUEEZE-2001
title: Bollinger BandWidth squeeze and WTI volatility expansion
publisher: McGraw-Hill / StockCharts / CME Group
source_type: trading_book_plus_exchange_reference
status: mined
last_reviewed: 2026-06-30
cards_extracted:
  - xti-vcb
  - xti-xng-vcb
---

# Bollinger BandWidth Squeeze Source

## Source Identity

- Bollinger, John. *Bollinger on Bollinger Bands*. McGraw-Hill, 2001.
- Supplement: StockCharts ChartSchool, "Bollinger Band Squeeze",
  https://chartschool.stockcharts.com/table-of-contents/trading-strategies-and-models/trading-strategies/bollinger-band-squeeze.
- Supplement: CME Group, "Light Sweet Crude Oil Futures contract
  specifications",
  https://www.cmegroup.com/markets/energy/crude-oil/light-sweet-crude.contractSpecs.html.

## Research Use

This source is used for structural lineage around volatility contraction
preceding directional expansion. The first QM implementation ports that idea to
a Darwinex-native WTI CFD rule: rank Bollinger BandWidth on completed D1 bars,
then trade only a close-confirmed breakout through the Bollinger envelope when
the WTI daily series has been in a low BandWidth state and the slow SMA slope
agrees with the breakout direction. The XTI/XNG extension applies the same
BandWidth squeeze mechanism to the completed D1 log ratio between WTI and
natural gas, then trades the two-leg basket only after ratio compression.

The EA does not ingest futures-chain data, inventory data, CFTC data, analyst
forecasts, APIs, CSV files, volume, open interest, or ML features at runtime.
It uses only Darwinex MT5 D1 OHLC, spread, ATR, SMA, Bollinger Bands, broker
calendar, and V5 framework risk/news/friday-close guards.

## R-Rules

- R1 reputable source: PASS. Bollinger's book is the primary technical source;
  CME is an exchange reference for WTI instrument lineage.
- R2 mechanical: PASS. Fixed D1 BandWidth rank, fixed Bollinger breakout,
  fixed trend-slope confirmation where used, fixed ATR stop/target or
  basket-leg ATR stops, and fixed time exit.
- R3 data available: PASS. `XTIUSD.DWX` and `XNGUSD.DWX` exist in the DWX
  symbol matrix.
- R4 no ML/banned logic: PASS. No ML, adaptive PnL fitting, grid, martingale,
  external API, or discretionary input.
