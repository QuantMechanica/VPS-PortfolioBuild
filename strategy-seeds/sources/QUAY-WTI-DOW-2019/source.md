---
source_id: QUAY-WTI-DOW-2019
title: Quayyum et al. crude-oil day-of-week seasonality
publisher: Soft Computing
source_type: academic_paper
status: mined
created: 2026-06-29
created_by: Codex
uri: https://doi.org/10.1007/s00500-019-04329-0
cards_extracted:
  - wti-mon-fade
  - wti-thu-prem
---

# Quayyum WTI Day-Of-Week Source

## Source Identity

- Primary citation: Quayyum, H. A., Khan, M. A. M. and Ali, S. M.,
  "Seasonality in crude oil returns", Soft Computing 24, 7857-7873 (2020),
  DOI https://doi.org/10.1007/s00500-019-04329-0.
- Public metadata pointer: https://pure.cardiffmet.ac.uk/en/publications/seasonality-in-crude-oil-returns/

## Research Use

This source is used for structural lineage around WTI and Brent day-of-week
seasonality. The already-built `wti-mon-fade` card isolates the reported weak
Monday side. This extraction adds a separate WTI Thursday premium test: buy
only the broker-calendar Thursday D1 bar and flatten on the next non-Thursday
D1 bar or a one-day stale-position guard.

No source performance number is imported into the portfolio. The QM pipeline
must validate the deterministic Darwinex `XTIUSD.DWX` realization in Q02 and
later phases before any portfolio conclusion is drawn.

## Guardrails

- Runtime uses Darwinex MT5 OHLC and broker calendar only.
- No external API calls, CSV feeds, futures curve, inventory data, analyst
  forecast, discretionary override, or news scraping.
- No ML, adaptive PnL fitting, grid, or martingale.
- One position per `XTIUSD.DWX` magic slot.

## R-Rules

- R1 reputable source: PASS. Peer-reviewed Springer journal article with DOI.
- R2 mechanical: PASS. Fixed D1 day-of-week entry, ATR hard stop, and
  deterministic time exit.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic single-position calendar sleeve.
