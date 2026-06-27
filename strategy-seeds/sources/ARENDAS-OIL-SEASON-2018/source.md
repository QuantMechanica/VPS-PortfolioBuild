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
---

# Arendas Oil Seasonality Source

## Source Identity

- Publisher: Journal of Investment Strategies
- Primary source: Arendas, P., Chovancova, B. and Balaz, V., "Seasonal patterns
  in oil prices and their implications for investors", URL
  https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf

## Research Use

This source is used for structural lineage around month-of-year seasonality in
crude-oil returns. The extraction used only one mechanized card:

- `wti-nov-fade`: XTIUSD.DWX D1 November month-of-year negative-return sleeve.

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
