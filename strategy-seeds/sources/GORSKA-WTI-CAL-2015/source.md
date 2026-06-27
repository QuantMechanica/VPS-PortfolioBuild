---
source_id: GORSKA-WTI-CAL-2015
title: Gorska-Krawiec WTI crude-oil calendar effects
publisher: Quantitative Methods in Economics
source_type: academic_paper
status: mined
last_reviewed: 2026-06-27
cards_extracted:
  - wti-fri-prem
---

# Gorska-Krawiec WTI Calendar Effects Source

## Source URL

- Gorska, A. and Krawiec, M., "Calendar Effects in the Market of Crude Oil",
  Quantitative Methods in Economics, 16(4), 2015:
  https://ageconsearch.umn.edu/record/230857/files/2015_4_7.pdf

## Research Use

This source is used for structural lineage around WTI crude-oil calendar
anomalies. The paper studies WTI daily returns and reports a weekday pattern in
which Monday and Tuesday are negative on average and Friday has the strongest
positive average return in the sample.

The mechanized card isolates only the Friday side on `XTIUSD.DWX`: enter long on
the broker-calendar Friday D1 bar, use a fixed ATR hard stop, and flatten via
the framework Friday-close guard or the next non-Friday D1 bar. The EA does not
ingest futures-chain data, EIA inventory data, analyst forecasts, APIs, CSV
files, or external feeds at runtime.

## Extracted Card

- `wti-fri-prem`: XTIUSD.DWX D1 weekly Friday calendar-premium sleeve.

## R-Rules

- R1 reputable source: PASS. Academic journal article focused on WTI crude-oil
  calendar effects.
- R2 mechanical: PASS. Fixed D1 day-of-week entry, ATR stop, and deterministic
  time exits.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, adaptive fitting, grid, martingale,
  external API, or discretionary input.
