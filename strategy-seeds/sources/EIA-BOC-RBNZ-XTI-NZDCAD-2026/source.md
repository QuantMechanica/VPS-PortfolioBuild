---
source_id: EIA-BOC-RBNZ-XTI-NZDCAD-2026
title: WTI, CAD, and NZD commodity-FX relative-value source packet
status: cards_ready
created: 2026-07-09
created_by: Codex
source_type: official_energy_and_central_bank_sources
uri: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
cards:
  - xti-nzdcad-rspr
---

# WTI/NZDCAD Oil-FX Relative-Value Source

## Source Identity

- Primary source: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.
- Primary URL: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
- Canada support: Bank of Canada, Staff Analytical Note 2017-1, "The Link
  Between the Canadian Dollar and Commodity Prices: Has It Broken?"
  https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/
- New Zealand support: Reserve Bank of New Zealand, "Commodity prices and
  implications for monetary policy", 2011.
  https://www.rbnz.govt.nz/research-and-publications/research/our-research-and-analysis/additional-research/commodity-prices-and-implications-for-monetary-policy

## Mining Scope

This packet supports one card:

- `xti-nzdcad-rspr`: D1 two-leg `XTIUSD.DWX` / `NZDCAD.DWX` return-spread
  z-score reversion. The basket treats WTI as the energy leg and `NZDCAD` as
  an inverse-CAD FX leg that contrasts Canada's oil-sensitive CAD channel with
  New Zealand commodity-exporter exposure.

## Evidence Notes

- The EIA working paper supplies official-source lineage for oil prices and
  exchange rates moving through macro and terms-of-trade channels.
- The Bank of Canada source supports Canada's commodity and oil sensitivity as
  a structural CAD channel, while noting that the relationship varies across
  regimes.
- The RBNZ source supports New Zealand's commodity-exporter terms-of-trade
  exposure. Using `NZDCAD` focuses the executable rule on relative CAD versus
  NZD commodity-channel movement rather than a broad USD leg.
- The QM implementation does not ingest EIA, Bank of Canada, RBNZ, CFTC,
  futures-curve, macro CSV, API, analyst forecast, or external FX data at
  runtime. Runtime data is only closed Darwinex MT5 D1 OHLC for
  `XTIUSD.DWX` and `NZDCAD.DWX`.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive parameter fitting, grid, martingale, or pyramiding.
- Two-leg basket packages only, one package at a time.
- One magic slot per leg.
- Backtests use `RISK_FIXED`. Live, `T_Live`, AutoTrading, deploy manifests,
  and portfolio gates are out of scope.

## R-Rules

- R1 reputable source: PASS. Single source packet anchored on official EIA
  research, with official Bank of Canada and RBNZ support for the two currency
  channels.
- R2 mechanical: PASS. Fixed D1 return window, rolling z-score, deterministic
  entry/exit bands, ATR hard stops, spread caps, and max-hold exit.
- R3 data available: PASS. `XTIUSD.DWX` and `NZDCAD.DWX` exist in the DWX
  symbol matrix with D1 history available to Q02.
- R4 no ML/banned logic: PASS. Deterministic, one position per magic slot, no
  ML, no grid, no martingale, no external runtime data.
