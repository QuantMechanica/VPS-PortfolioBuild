---
source_id: EIA-BOC-XBR-CADCHF-2026
title: Brent, CADCHF, and oil-CAD relative-value source packet
status: cards_ready
created: 2026-07-09
created_by: Codex
source_type: official_energy_and_central_bank_sources
uri: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
cards:
  - xbr-cadchf-rspr
---

# Brent/CADCHF Oil-FX Relative-Value Source

## Source Identity

- Primary source: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.
- Primary URL: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
- Canada support: Bank of Canada Staff Analytical Note 2017-1, "The Link
  Between the Canadian Dollar and Commodity Prices: Has It Broken?"
  https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/
- Canada energy support: U.S. Energy Information Administration, "Canada",
  Country Analysis Brief. https://www.eia.gov/international/analysis/country/CAN

## Mining Scope

This packet supports one new card:

- `xbr-cadchf-rspr`: D1 two-leg `XBRUSD.DWX` / `CADCHF.DWX` return-spread
  z-score reversion. The basket treats Brent as the global crude leg and
  CADCHF as a CAD-versus-defensive-FX confirmation leg.

## Evidence Notes

- The EIA working paper gives official-source lineage that oil prices and
  exchange rates are jointly studied through macro, trade, and terms-of-trade
  channels.
- The Bank of Canada source supports Canada's commodity-price and oil
  sensitivity as a structural CAD channel while warning that the relationship
  changes across regimes.
- The EIA Canada country analysis supports Canada's structural energy-export
  exposure behind the CAD/oil channel.
- The QM implementation does not ingest EIA, Bank of Canada, futures-curve,
  inventory, CFTC, macro CSV, API, analyst forecast, or external FX data at
  runtime. Runtime data is only closed Darwinex MT5 D1 OHLC for `XBRUSD.DWX`
  and `CADCHF.DWX`.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive parameter fitting, grid, martingale, or pyramiding.
- Two-leg basket packages only, one package at a time.
- One magic slot per leg.
- Backtests use `RISK_FIXED`. Live, `T_Live`, AutoTrading, deploy manifests,
  and portfolio gates are out of scope.

## R-Rules

- R1 reputable source: PASS. Official EIA research plus official Bank of
  Canada and EIA Canada support.
- R2 mechanical: PASS. Fixed D1 return window, rolling z-score, deterministic
  entry/exit bands, ATR hard stops, spread caps, package repair, and max-hold
  exit.
- R3 data available: PASS. `XBRUSD.DWX` is already registered for Brent builds
  and `CADCHF.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic, one position per magic slot, no
  ML, no grid, no martingale, and no external runtime data.
