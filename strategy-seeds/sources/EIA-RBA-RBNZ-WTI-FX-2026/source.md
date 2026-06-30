---
source_id: EIA-RBA-RBNZ-WTI-FX-2026
title: EIA/RBA/RBNZ WTI and Antipodean Commodity-FX Source Packet
status: cards_ready
created: 2026-06-30
created_by: Codex
source_type: government_and_central_bank_research
uri: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
---

# EIA/RBA/RBNZ WTI and Antipodean Commodity-FX Source Packet

## Source Identity

- Primary source: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.
- Primary URL: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
- Supplement: Reserve Bank of Australia, "Drivers of the Australian Dollar
  Exchange Rate".
- Supplement URL: https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html
- Supplement: Reserve Bank of New Zealand, "Explaining New Zealand's monetary
  policy framework and exchange-rate transmission", RBNZ education and research
  material.
- Supplement URL: https://www.rbnz.govt.nz/

## Mining Scope

One card was extracted for a structural commodity/FX relative-value sleeve:

- `wti-audnzd-mr`: XTIUSD.DWX/AUDUSD.DWX/NZDUSD.DWX D1 oil-in-antipodean-FX
  z-score mean-reversion basket.

## Evidence Notes

- The EIA source provides official-source lineage for structural links between
  oil prices and exchange rates.
- The RBA source provides official central-bank lineage for the Australian
  dollar's sensitivity to commodity prices, terms of trade, and global demand.
- The RBNZ source is used only as a reputable central-bank supplement for NZD
  exchange-rate transmission and New Zealand's open-economy sensitivity. No RBNZ
  data is consumed at runtime.
- The QM implementation does not ingest EIA, RBA, RBNZ, commodity-index,
  futures-curve, rate, macro, or external FX data at runtime. It uses the source
  packet only for structural lineage and trades Darwinex MT5-native D1 OHLC for
  `XTIUSD.DWX`, `AUDUSD.DWX`, and `NZDUSD.DWX`.

## Guardrails

- No external data calls in the EA.
- No ML, no adaptive parameter fitting, no grid, no martingale.
- Three-leg basket only, one package at a time.
- Backtests use RISK_FIXED setfiles. Live, T_Live, AutoTrading, deploy
  manifests, and portfolio gates are out of scope.
