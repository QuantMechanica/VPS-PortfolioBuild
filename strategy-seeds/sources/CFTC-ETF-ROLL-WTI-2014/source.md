---
source_id: CFTC-ETF-ROLL-WTI-2014
title: Predatory or Sunshine Trading? Evidence from Crude Oil ETF Rolls
publisher: U.S. Commodity Futures Trading Commission, Office of the Chief Economist
source_type: official_government_research_paper
status: mined
last_reviewed: 2026-06-29
cards_extracted:
  - wti-roll-fade
  - wti-roll-relief
  - wti-roll-squeeze
---

# CFTC Crude Oil ETF Roll Source

## Source URLs

- CFTC Office of the Chief Economist, "Predatory or Sunshine Trading? Evidence
  from Crude Oil ETF Rolls": https://www.cftc.gov/sites/default/files/idc/groups/public/@economicanalysis/documents/file/oce_predatorysunshine0314.pdf

## Research Use

This source is used only for structural lineage. The CFTC paper studies
predictable crude-oil ETF roll trading and the associated futures-market price
and liquidity effects. The mechanized QM card does not ingest ETF holdings,
futures curves, CFTC data, COT data, roll calendars, APIs, CSV files, or
discretionary analyst inputs at runtime.

The cards convert the structural idea into Darwinex `XTIUSD.DWX` D1 rules.
`wti-roll-fade` trades the pressure side during the early-month ETF roll
window. `wti-roll-relief` trades the post-window relief side only after the
same month has shown confirmed early roll pressure and price reclaims above a
slow D1 mean.
`wti-roll-squeeze` trades a symmetric early-month roll-window breakout only
when the D1 bars before the signal were compressed.

## Extracted Card

- `wti-roll-fade`: XTIUSD.DWX D1 ETF roll-pressure short sleeve.
- `wti-roll-relief`: XTIUSD.DWX D1 post-roll relief long sleeve.
- `wti-roll-squeeze`: XTIUSD.DWX D1 ETF roll-window compression breakout.

## R-Rules

- R1 reputable source: PASS. CFTC is the official U.S. derivatives regulator
  and the paper is from its Office of the Chief Economist.
- R2 mechanical: PASS. Fixed trading-day-of-month windows, D1 return
  confirmations, SMA trend/reclaim gates, ATR stop, time exit, and window exit
  are deterministic.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix and the
  runtime uses broker OHLC/calendar only.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external feed,
  pyramiding, or adaptive sizing.
