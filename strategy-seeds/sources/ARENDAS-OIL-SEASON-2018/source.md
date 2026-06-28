---
source_id: ARENDAS-OIL-SEASON-2018
title: Arendas et al. crude-oil seasonal patterns
publisher: Journal of Investment Strategies
source_type: academic_paper
status: cards_ready
created: 2026-06-27
created_by: Codex
uri: https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf
cards_extracted:
  - wti-nov-fade
  - wti-apr-prem
  - wti-aug-prem
---

# Arendas Oil Seasonality Source

## Source Identity

- Publisher: Journal of Investment Strategies
- Primary source: Arendas, P., Chovancova, B. and Balaz, V., "Seasonal patterns
  in oil prices and their implications for investors", URL
  https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf

## Research Use

This source is used for structural lineage around month-of-year seasonality in
crude-oil returns. The extraction used two mechanized cards:

- `wti-nov-fade`: XTIUSD.DWX D1 November month-of-year negative-return sleeve.
- `wti-apr-prem`: XTIUSD.DWX D1 April month-of-year positive-return sleeve.
- `wti-aug-prem`: XTIUSD.DWX D1 August month-of-year positive-return sleeve.

The April card isolates one of the positive spring months reported by the
source. It is intentionally separate from the February premium card that uses
the Gorska-Krawiec WTI calendar source, and from the broad EIA demand-season
strategy that requires trend/momentum confirmation.

The August card isolates the third positive month named by the source and is
kept separate from the April spring premium and broad EIA summer-demand season
logic. Q02+ must validate the deterministic rule on Darwinex XTIUSD.DWX bars
before any portfolio conclusion is drawn.

The QM implementation does not import the paper's performance numbers into the
portfolio. Q02+ must validate the deterministic rule on Darwinex XTIUSD.DWX
bars.

## Guardrails

- Runtime uses Darwinex MT5 OHLC and broker calendar only.
- No external API calls, CSV feeds, futures curve, inventory data, analyst
  forecast, or discretionary override.
- No ML, adaptive PnL fitting, grid, or martingale.
- One position per XTIUSD.DWX magic slot.

## R-Rules

- R1 reputable source: PASS. Single academic paper source with URL.
- R2 mechanical: PASS. Fixed D1 month-of-year entry, ATR stop, and deterministic
  time exit.
- R3 data available: PASS. XTIUSD.DWX exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic single-position calendar sleeve.
