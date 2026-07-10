---
source_id: CRABEL-XNG-IDNR4-2026
title: Crabel ID/NR4 contraction breakout ported to natural gas
publisher: Traders Press
source_type: trading_book
status: cards_ready
created: 2026-07-10
created_by: Codex
cards_extracted:
  - xng-idnr4-brk
---

# Crabel Natural-Gas ID/NR4 Source

## Source Identity

- Primary source: Crabel, Toby. *Day Trading with Short-Term Price Patterns and
  Opening Range Breakout*. Traders Press, 1990. ISBN 9780934380171.
- Corroborating primary-author publication: Crabel, Toby. "Playing the Opening
  Range Breakout, Part 1." *Technical Analysis of Stocks & Commodities*,
  Vol. 6:9, pp. 337-339, 1988.
- Bibliographic pointer: https://books.google.com/books?id=xpgbAAAACAAJ

## Bounded Extraction

The mission-approved extraction is the source's ID/NR4 contraction pattern:
the setup session is strictly inside its predecessor and has the narrowest
high-low range of the latest four completed sessions. Crabel's breakout
lineage supplies the structural compression-to-expansion thesis. The QM port
requires the immediately following completed D1 bar to close outside the setup
range before entering `XNGUSD.DWX` on the next bar.

The source supplies a commodity price pattern, not a Darwinex natural-gas
performance claim. Q02 and later gates must establish whether this specific
CFD realization has an edge.

## Runtime Guardrails

- Native MT5 `XNGUSD.DWX` D1 OHLC, spread, ATR, broker calendar, and framework
  position state only.
- No storage report, weather model, futures curve, volume, open interest,
  external API/CSV, discretionary override, ML, adaptive PnL fitting, grid,
  martingale, pyramiding, or stop-and-reverse sizing.
- One position on magic slot 0.

## R-Rules

- R1 reputable source: PASS. Named systematic commodity-trading book from
  Traders Press plus the primary author's trade-journal article.
- R2 mechanical: PASS. Fixed inside-day and NR4 definitions, immediate next-
  bar close confirmation, range-anchored stop, fixed-R target, and time exit.
- R3 data available: PASS. `XNGUSD.DWX` is registered in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic OHLC-only, single-position D1
  sleeve.
