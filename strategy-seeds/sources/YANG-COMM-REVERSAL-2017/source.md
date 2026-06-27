---
source_id: YANG-COMM-REVERSAL-2017
title: Yang-Goncu-Pantelous Momentum and Reversal in Commodity Futures
publisher: SSRN working paper
source_type: academic_paper
status: mined
last_reviewed: 2026-06-27
cards_extracted:
  - yang-wti-reversal
---

# Yang-Goncu-Pantelous Commodity Reversal Source

## Source URL

- Yang, Goncu, and Pantelous, "Momentum and Reversal in Commodity Futures":
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253

## Research Use

This source is used only for structural lineage: commodity futures can exhibit
systematic momentum and reversal behavior at fixed lookback horizons. The
mechanized card isolates the reversal side on `XTIUSD.DWX` using Darwinex MT5
D1 OHLC only.

The EA does not ingest futures-chain data, CFTC data, inventory data, analyst
forecasts, APIs, CSV files, or external feeds at runtime. It converts the
academic reversal family into a fixed D1 price rule: after a large multi-month
WTI move, wait for a weekly reversal confirmation and trade back toward a slow
D1 mean with fixed ATR risk.

## Extracted Card

- `yang-wti-reversal`: XTIUSD.DWX D1 weekly medium-term reversal toward SMA(63).

## R-Rules

- R1 reputable source: PASS. SSRN academic paper with commodity futures focus.
- R2 mechanical: PASS. Fixed D1 return, SMA, ATR, weekly calendar gate, hard
  ATR stop, mean exit, and max-hold exit are deterministic.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, adaptive fitting, grid, martingale,
  external API, or discretionary input.
