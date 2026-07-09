---
source_id: EIA-RBA-XBR-AUDUSD-2026
title: EIA/RBA Brent and AUD commodity-FX relative-value source packet
status: cards_ready
created: 2026-07-09
created_by: Codex
source_type: government_and_central_bank_research
uri: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
---

# EIA/RBA Brent and AUD Commodity-FX Source Packet

## Source Identity

- Primary source: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.
- Primary URL: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
- AUD channel: Reserve Bank of Australia, "Drivers of the Australian Dollar
  Exchange Rate".
- AUD URL: https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html
- Brent market context: EIA Europe Brent Spot Price FOB series.
- Brent URL: https://www.eia.gov/dnav/pet/hist/rbrted.htm

## Mining Scope

This packet supports one D1 `XBRUSD.DWX` / `AUDUSD.DWX` return-spread
reversion basket. The EA uses only Darwinex MT5 OHLC, spread, ATR, broker time,
and V5 framework state at runtime.

## Evidence Notes

- The EIA working paper provides official-source lineage for structural links
  between oil prices and exchange rates.
- The RBA source provides central-bank lineage for the Australian dollar's
  sensitivity to commodity prices, terms of trade, export demand, risk
  sentiment, and market expectations.
- The EIA Brent spot series confirms the Brent crude market context. It is not
  consumed by the EA at runtime.
- The implementation uses the source packet only for structural lineage and
  trades Darwinex MT5-native D1 OHLC for `XBRUSD.DWX` and `AUDUSD.DWX`.

## V5 Allowability

- R1 reputable source: PASS - one source packet with official EIA and RBA
  lineage.
- R2 mechanical: PASS - fixed D1 return lookback, rolling z-score,
  paired-basket entry, ATR hard stops, spread caps, max-hold exit, and
  broken-package repair.
- R3 data available: PASS - `AUDUSD.DWX` is in the DWX matrix and existing
  Brent builds use `XBRUSD.DWX`; Q02 validates synchronized XBR/AUD history
  and fills.
- R4 ML forbidden: PASS - no ML, adaptive PnL fitting, external runtime data,
  grid, martingale, or discretionary input.

## Guardrails

- No external data calls in the EA.
- No ML, no adaptive parameter fitting, no grid, no martingale.
- Two-leg basket only, one package at a time.
- Backtests use RISK_FIXED setfiles. Live, T_Live, AutoTrading, deploy
  manifests, and portfolio gates are out of scope.
