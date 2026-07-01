---
source_id: QUAY-WTI-DOW-2019
title: Quayyum et al. crude-oil day-of-week seasonality
publisher: Soft Computing
source_type: academic_paper
status: cards_ready
created: 2026-06-29
created_by: Codex
uri: https://doi.org/10.1007/s00500-019-04329-0
cards_extracted:
  - wti-mon-fade
  - wti-thu-prem
  - brent-thu-prem
  - brent-mon-fade
  - brent-fri-prem
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

The `brent-thu-prem` extraction uses the same peer-reviewed day-of-week
lineage but ports the Thursday premium to the Brent CFD proxy `XBRUSD.DWX`.
It is deliberately separate from the WTI Thursday build so Q02 can decide
whether the Brent benchmark adds usable non-XNG energy exposure.

The `brent-mon-fade` extraction uses the same source lineage but isolates the
Monday weakness side on Brent. It is deliberately separate from WTI Monday and
Brent Thursday so the pipeline can test whether a short early-week Brent sleeve
adds different energy exposure to the XAU/SP500/NDX/XNG book.

The `brent-fri-prem` extraction isolates the positive Friday side on Brent. It
uses the same deterministic D1 calendar package as the Thursday card but tests a
separate weekday that the source identifies for Brent, giving Q02 a distinct
energy benchmark sleeve rather than another WTI, XNG, metal, or index leg.

No source performance number is imported into the portfolio. The QM pipeline
must validate the deterministic Darwinex `XTIUSD.DWX` realization in Q02 and
later phases before any portfolio conclusion is drawn.

## Guardrails

- Runtime uses Darwinex MT5 OHLC and broker calendar only.
- No external API calls, CSV feeds, futures curve, inventory data, analyst
  forecast, discretionary override, or news scraping.
- No ML, adaptive PnL fitting, grid, or martingale.
- One position per symbol magic slot.

## R-Rules

- R1 reputable source: PASS. Peer-reviewed Springer journal article with DOI.
- R2 mechanical: PASS. Fixed D1 day-of-week entry, ATR hard stop, and
  deterministic time exit.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic single-position calendar sleeve.
