---
source_id: YANG-COMM-REVERSAL-2017
title: Yang-Goncu-Pantelous Momentum and Reversal in Commodity Futures
publisher: SSRN working paper
source_type: academic_paper
status: mined
last_reviewed: 2026-06-28
cards_extracted:
  - yang-wti-reversal
  - comm-reversal-4wk-xngusd
  - comm-reversal-4wk-xtiusd
  - commodity-reversal-1m
---

# Yang-Goncu-Pantelous Commodity Reversal Source

## Source URL

- Yang, Goncu, and Pantelous, "Momentum and Reversal in Commodity Futures":
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253

## Research Use

This source is used only for structural lineage: commodity futures can exhibit
systematic momentum and reversal behavior at fixed lookback horizons. The
mechanized cards isolate the reversal side on DWX energy symbols and on a
market-neutral commodity basket using Darwinex MT5 D1 OHLC only.

The EAs do not ingest futures-chain data, CFTC data, inventory data, analyst
forecasts, APIs, CSV files, or external feeds at runtime. They convert the
academic reversal family into fixed D1 price rules with ATR-bounded risk.

## Extracted Card

- `yang-wti-reversal`: XTIUSD.DWX D1 weekly medium-term reversal toward SMA(63).
- `comm-reversal-4wk-xngusd`: XNGUSD.DWX D1 weekly 20-bar overreaction reversal.
- `comm-reversal-4wk-xtiusd`: XTIUSD.DWX D1 weekly 20-bar overreaction reversal.
- `commodity-reversal-1m`: monthly long-loser/short-winner basket across
  `XTIUSD.DWX`, `XNGUSD.DWX`, `XAUUSD.DWX`, and `XAGUSD.DWX` with an energy-leg
  requirement.

## R-Rules

- R1 reputable source: PASS. SSRN academic paper with commodity futures focus.
- R2 mechanical: PASS. Fixed D1 return, SMA, ATR, weekly calendar gate, hard
  ATR stop, mean exit, and max-hold exit are deterministic.
- R3 data available: PASS. `XTIUSD.DWX`, `XNGUSD.DWX`, `XAUUSD.DWX`, and
  `XAGUSD.DWX` exist in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, adaptive fitting, grid, martingale,
  external API, or discretionary input.
