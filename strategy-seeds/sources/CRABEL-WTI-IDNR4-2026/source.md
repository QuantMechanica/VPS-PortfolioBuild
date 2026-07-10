---
source_id: CRABEL-WTI-IDNR4-2026
title: Crabel ID/NR4 contraction breakout ported to WTI
publisher: Traders Press
source_type: trading_book
status: cards_ready
created: 2026-07-10
created_by: Codex
cards_extracted:
  - xti-idnr4-brk
---

# Crabel WTI ID/NR4 Source

## Source Identity

- Primary source: Crabel, Toby. *Day Trading with Short-Term Price Patterns and
  Opening Range Breakout*. Traders Press, 1990. ISBN 9780934380171.
- Corroborating primary-author publication: Crabel, Toby. "Playing the Opening
  Range Breakout, Part 1." *Technical Analysis of Stocks & Commodities*,
  Vol. 6:9, pp. 337-339, 1988.
- Bibliographic verification: Google Books describes the 288-page book as a
  computer-tested study of OHLC price patterns, range expansion/contraction,
  and opening-range breakouts in commodities.

## Bounded Extraction

The approved extraction scope is the book's ID/NR4 setup: the completed setup
bar is both an inside day and the narrowest daily high-low range of the last
four completed sessions. Crabel pairs the contraction state with a subsequent
breakout. The QM port makes the breakout reproducible on Darwinex data by
requiring the immediately following completed D1 bar to close beyond the setup
extreme; it does not import a fixed-dollar futures opening-range distance.

No source performance number is imported. Q02 and later gates must establish
whether the deterministic `XTIUSD.DWX` CFD realization has an edge.

## Runtime Guardrails

- Native MT5 `XTIUSD.DWX` D1 OHLC, spread, ATR, broker calendar, and framework
  position state only.
- No futures curve, inventory, volume, open interest, event feed, external
  API/CSV, discretionary override, ML, adaptive PnL fitting, grid, martingale,
  pyramiding, or stop-and-reverse sizing.
- One position on magic slot 0.

## R-Rules

- R1 reputable source: PASS. Named commodity-trading book by a known systematic
  practitioner, published by Traders Press, plus the primary author's trade-
  journal article.
- R2 mechanical: PASS. Fixed inside-day and NR4 definitions, immediate next-bar
  close confirmation, range-anchored stop, fixed-R target, and time exit.
- R3 data available: PASS. `XTIUSD.DWX` is registered in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic OHLC-only, single-position sleeve.
