---
source_id: EIA-RBA-BOC-XBR-AUDCAD-2026
title: Brent, AUD, and CAD commodity-FX relative-value source packet
status: cards_ready
created: 2026-07-09
created_by: Codex
source_type: official_energy_and_central_bank_sources
uri: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
cards:
  - xbr-audcad-rspr
---

# Brent/AUDCAD Oil-FX Relative-Value Source

## Source Identity

- Primary source: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.
  https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
- Australia support: Reserve Bank of Australia, "Drivers of the Australian
  Dollar Exchange Rate".
  https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html
- Canada support: Bank of Canada, Staff Analytical Note 2017-1, "The Share of
  Systematic Variations in the Canadian Dollar - Part II".
  https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/

## Mining Scope

This packet supports one card:

- `xbr-audcad-rspr`: D1 two-leg `XBRUSD.DWX` / `AUDCAD.DWX` return-spread
  z-score reversion. The basket treats Brent as the global seaborne crude leg
  and `AUDCAD` as a commodity-FX cross contrasting Australia's broad commodity
  exposure against Canada's oil-sensitive CAD channel.

## Evidence Notes

- The EIA working paper supplies official-source lineage for crude oil prices
  and exchange rates moving through macro and terms-of-trade channels.
- The RBA source supports AUD sensitivity to trade, commodity, and risk
  channels without implying a deterministic one-for-one hedge.
- The Bank of Canada source supports commodity-price exposure as a structural
  CAD channel, while noting that the relationship varies across regimes.
- The QM implementation does not ingest EIA, RBA, Bank of Canada, CFTC,
  futures-curve, macro CSV, API, analyst forecast, or external FX data at
  runtime. Runtime data is only closed Darwinex MT5 D1 OHLC for `XBRUSD.DWX`
  and `AUDCAD.DWX`, plus broker spread and ATR metadata.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive parameter fitting, grid, martingale, or pyramiding.
- Two-leg basket packages only, one package at a time.
- One magic slot per leg.
- Backtests use `RISK_FIXED`. Live, `T_Live`, AutoTrading, deploy manifests,
  and portfolio gates are out of scope.

## R-Rules

- R1 reputable source: PASS. Official EIA research, official RBA education
  material, and official Bank of Canada analytical work.
- R2 mechanical: PASS. Fixed D1 return window, rolling z-score, deterministic
  entry/exit bands, ATR hard stops, spread caps, and max-hold exit.
- R3 data available: PASS. `XBRUSD.DWX` and `AUDCAD.DWX` are existing DWX
  symbols used by the framework's energy/FX sleeves.
- R4 no ML/banned logic: PASS. Deterministic, one position per magic slot, no
  ML, no grid, no martingale, no external runtime data.
