---
source_id: EIA-BOC-BOJ-XTI-CADJPY-2026
title: WTI, CAD, and Japan oil-importer FX relative-value source packet
status: cards_ready
created: 2026-07-04
created_by: Codex
source_type: official_energy_and_central_bank_sources
uri: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
cards:
  - xti-cadjpy-rspr
---

# WTI/CADJPY Oil-FX Relative-Value Source

## Source Identity

- Primary source: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.
- Primary URL: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
- Canada support: Bank of Canada, Staff Analytical Note 2017-1, "The Link
  Between the Canadian Dollar and Commodity Prices: Has It Broken?"
  https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/
- Japan support: U.S. Energy Information Administration, "Japan", Country
  Analysis Brief. https://www.eia.gov/international/analysis/country/JPN
- Japan macro support: Bank of Japan, Uchida, S., "Recent Developments in
  Economic Activity, Prices, and Monetary Policy", 2026-06-03.
  https://www.boj.or.jp/en/about/press/koen_2026/ko260603a.htm

## Mining Scope

This packet supports one card:

- `xti-cadjpy-rspr`: D1 two-leg `XTIUSD.DWX` / `CADJPY.DWX` return-spread
  z-score reversion. The basket treats WTI as the energy leg and CADJPY as an
  oil-exporter versus oil-importer FX leg.

## Evidence Notes

- The EIA working paper provides official-source lineage that oil prices and
  exchange rates are jointly studied and may move through macro and terms of
  trade channels.
- The Bank of Canada source supports Canada's commodity and oil sensitivity as
  a structural CAD channel, while noting that the relationship can vary across
  regimes.
- The EIA Japan and BOJ sources support Japan's oil-importer terms-of-trade
  channel and sensitivity to higher crude-oil prices and yen depreciation.
- The QM implementation does not ingest EIA, Bank of Canada, BOJ, CFTC,
  futures-curve, macro CSV, API, analyst forecast, or external FX data at
  runtime. Runtime data is only closed Darwinex MT5 D1 OHLC for
  `XTIUSD.DWX` and `CADJPY.DWX`.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive parameter fitting, grid, martingale, or pyramiding.
- Two-leg basket packages only, one package at a time.
- One magic slot per leg.
- Backtests use `RISK_FIXED`. Live, `T_Live`, AutoTrading, deploy manifests,
  and portfolio gates are out of scope.

## R-Rules

- R1 reputable source: PASS. Single source packet anchored on official EIA
  research, with official Bank of Canada, EIA Japan, and BOJ support for the
  two economic channels.
- R2 mechanical: PASS. Fixed D1 return window, rolling z-score, deterministic
  entry/exit bands, ATR hard stops, spread caps, and max-hold exit.
- R3 data available: PASS. `XTIUSD.DWX` and `CADJPY.DWX` exist in the DWX
  symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic, one position per magic slot, no
  ML, no grid, no martingale, no external runtime data.
