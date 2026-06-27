---
source_id: GORSKA-WTI-CAL-2015
title: Gorska-Krawiec WTI crude-oil calendar effects
publisher: Quantitative Methods in Economics
source_type: academic_paper
status: mined
last_reviewed: 2026-06-27
cards_extracted:
  - wti-fri-prem
  - wti-feb-prem
  - wti-tue-fade
  - wti-oct-fade
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
positive average return in the sample. The same paper also studies
month-of-year seasonality and reports February as the strongest positive WTI
month in the sample. The same month-of-year table shows the late-year WTI
weakness cluster, with October the weakest average-return month in the sample.

The first mechanized card isolates only the Friday side on `XTIUSD.DWX`: enter
long on the broker-calendar Friday D1 bar, use a fixed ATR hard stop, and
flatten via the framework Friday-close guard or the next non-Friday D1 bar.

The second mechanized card isolates the February month-of-year side on
`XTIUSD.DWX`: enter long only during February D1 bars, hold each entry for one
D1 bar, and use a fixed ATR hard stop. The EAs do not ingest futures-chain data,
EIA inventory data, analyst forecasts, APIs, CSV files, or external feeds at
runtime.

The third mechanized card isolates the Tuesday negative-return side shown in
the weekday table on `XTIUSD.DWX`: enter short on the broker-calendar Tuesday
D1 bar, use a fixed ATR hard stop, and flatten on the first subsequent D1 bar
or one-calendar-day stale-position guard.

The fourth mechanized card isolates the October negative month-of-year side on
`XTIUSD.DWX`: enter short only during October D1 bars, use a fixed ATR hard
stop, and flatten on the first subsequent D1 bar or one-calendar-day
stale-position guard.

## Extracted Card

- `wti-fri-prem`: XTIUSD.DWX D1 weekly Friday calendar-premium sleeve.
- `wti-feb-prem`: XTIUSD.DWX D1 February month-of-year premium sleeve.
- `wti-tue-fade`: XTIUSD.DWX D1 Tuesday negative-return fade sleeve.
- `wti-oct-fade`: XTIUSD.DWX D1 October month-of-year fade sleeve.

## R-Rules

- R1 reputable source: PASS. Academic journal article focused on WTI crude-oil
  calendar effects.
- R2 mechanical: PASS. Fixed D1 day-of-week or month-of-year entries, ATR stop,
  and deterministic time exits.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, adaptive fitting, grid, martingale,
  external API, or discretionary input.
