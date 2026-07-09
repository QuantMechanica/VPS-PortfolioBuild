---
source_id: CRABEL-WTI-WEEK-ORB-2026
title: Crabel opening-range breakout port to WTI weekly range
publisher: Traders Press
source_type: trading_book
status: cards_ready
created: 2026-07-02
created_by: Codex
cards_extracted:
  - wti-week-orb
  - xti-inweek-brk
---

# Crabel WTI Weekly Opening Range Source

## Source Identity

- Primary source: Crabel, Toby. *Day Trading with Short-Term Price Patterns
  and Opening Range Breakout*. Traders Press, 1990.

## Research Use

This source is used for structural lineage around opening-range and short-term
range-pattern breakout mechanics. The first QM card ports the opening-range
concept to a low-frequency WTI weekly range: the first completed D1 bar of each
broker week defines the range, and later completed D1 closes in the same week
can trigger a volatility expansion breakout. The second QM card uses the same
Crabel-style range-compression lineage but waits for a fully completed inside
week, then trades next-week expansion beyond that inside-week high or low.

The realization is deliberately Darwinex-native. It does not ingest futures
curve, volume, open interest, inventory, EIA, CME, CFTC, analyst, CSV, API, or
external runtime data. The rule uses only `XTIUSD.DWX` OHLC, spread, ATR, SMA,
broker calendar time, and V5 framework state.

## Extracted Card

- `wti-week-orb`: XTIUSD.DWX D1 weekly opening-range breakout, one trade per
  broker week, flat by week change or Friday close.
- `xti-inweek-brk`: XTIUSD.DWX D1 inside-week compression breakout, one trade
  per broker week, flat by failed-breakout, SMA failure, time stop, or Friday
  close.

## R-Rules

- R1 reputable source: PASS. Named trading book source for the opening-range
  breakout concept.
- R2 mechanical: PASS. Fixed weekly range definitions, inside-week or
  opening-range preconditions, ATR/SMA confirmation, spread cap, ATR
  stop/target, and deterministic failed-breakout/time exits.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, external runtime API, grid, martingale,
  pyramiding, or adaptive PnL fitting.
