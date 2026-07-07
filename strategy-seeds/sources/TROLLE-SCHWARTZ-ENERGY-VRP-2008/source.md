---
source_id: TROLLE-SCHWARTZ-ENERGY-VRP-2008
title: "Variance risk premia in energy commodities"
publisher: "Trolle and Schwartz / UCLA Anderson public paper copy"
source_type: academic_paper
status: cards_ready
created: 2026-07-07
created_by: Codex
uri: https://www.anderson.ucla.edu/documents/areas/fac/finance/schwartz_risk_premia.pdf
cards_extracted:
  - xti-vrp-proxy
---

# Trolle-Schwartz Energy VRP Source

## Source Identity

- Primary source: Anders B. Trolle and Eduardo S. Schwartz, "Variance risk
  premia in energy commodities", July 2008 public paper copy.
- URL: https://www.anderson.ucla.edu/documents/areas/fac/finance/schwartz_risk_premia.pdf
- Supplemental source: BIS Working Papers No. 619, "Volatility risk premia and
  future commodities returns", https://www.bis.org/publ/work619.pdf.

## Research Use

The source is used only for structural lineage around energy volatility risk
premia. The paper studies crude oil and natural gas variance risk premia from
futures and options, and documents that energy variance premia are negative on
average and time-varying.

V5 does not have runtime access to crude-oil option chains, variance swaps, or
implied-volatility surfaces. The extracted card is therefore deliberately named
`xti-vrp-proxy`: it is an OHLC-only realized-volatility proxy that trades
Darwinex `XTIUSD.DWX` in top-quartile realized-volatility regimes, fading
short-horizon directional stretches as a conservative spot-CFD expression of
volatility carry normalization. It does not claim to replicate true options VRP.

## Guardrails

- Runtime uses `XTIUSD.DWX` D1 OHLC, spread, ATR, SMA, and broker calendar only.
- No options data, EIA data, news feed, futures curve, CSV, API, or external
  market-data dependency.
- No ML, adaptive PnL fitting, grid, martingale, pyramiding, or discretionary
  override.
- One position per `XTIUSD.DWX` magic slot.

## R-Rules

- R1 reputable source: PASS. Academic energy-commodity variance-risk-premium
  source, supplemented by BIS commodity VRP research.
- R2 mechanical: PASS. Fixed D1 realized-volatility percentile, return-stretch,
  ATR stop, SMA/vol/time exits.
- R3 data available: PASS for the proxy expression. `XTIUSD.DWX` exists in the
  DWX symbol matrix and all runtime inputs are MT5 OHLC-derived.
- R4 no ML/banned logic: PASS. Deterministic single-symbol structural sleeve.

