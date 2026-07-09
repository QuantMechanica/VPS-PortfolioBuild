---
source_id: CRABEL-WTI-NR7-BRK-2026
title: Crabel narrow-range price-pattern breakout ported to WTI
publisher: Traders Press
source_type: trading_book
status: cards_ready
created: 2026-07-09
created_by: Codex
cards_extracted:
  - xti-nr7-brk
---

# Crabel WTI NR7 Breakout Source

## Source Identity

- Primary source: Crabel, Toby. *Day Trading with Short-Term Price Patterns and
  Opening Range Breakout*. Traders Press, 1990.

## Research Use

Crabel's short-term price-pattern lineage treats narrow-range bars as volatility
contraction reference points before range expansion. This source packet ports
that idea to a low-frequency Darwinex `XTIUSD.DWX` D1 sleeve: the EA waits for a
completed D1 bar whose range is the narrowest of the last seven completed D1
bars, then follows the next completed D1 close if it breaks beyond that narrow
bar in the direction of the broader SMA trend.

The QM implementation imports no source performance claim. Q02 and later phases
must validate the deterministic Darwinex CFD implementation.

## Guardrails

- Runtime uses native MT5 `XTIUSD.DWX` D1 OHLC, spread, ATR, SMA, broker
  calendar, and V5 framework state only.
- No futures curve, inventory feed, EIA/CME/CFTC/API/CSV data, volume,
  open-interest feed, analyst forecast, discretionary override, ML, adaptive
  PnL fitting, grid, martingale, or pyramiding.
- One position per `XTIUSD.DWX` magic slot.

## R-Rules

- R1 reputable source: PASS. Single trading-book source with clear title and
  publisher.
- R2 mechanical: PASS. Fixed D1 NR7 definition, close-confirmed breakout, ATR
  stop/target, trend exit, and time exit.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic single-position D1 sleeve.
