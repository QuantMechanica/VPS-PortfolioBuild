---
source_id: EIA-SNB-XTI-USDCHF-RSPREAD-2026
title: EIA/SNB WTI and USDCHF return-spread reversion source packet
status: cards_ready
created: 2026-07-08
created_by: Codex
source_type: government_and_central_bank_research
uri: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
---

# EIA/SNB WTI and USDCHF Return-Spread Reversion Source Packet

## Source Identity

- Primary source: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.
- Primary URL: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
- Supplement: Grisse, C., and Nitschka, T., "On financial risk and the safe
  haven characteristics of Swiss franc exchange rates", Swiss National Bank
  Working Paper 2013-04, April 2013.
- Supplement URL:
  https://www.snb.ch/en/publications/research/working-papers/2013/working_paper_2013_04

## Mining Scope

One card was extracted for a structural commodity/FX relative-value sleeve:

- `xti-usdchf-rspr`: XTIUSD.DWX/USDCHF.DWX D1 CHF-terms return-spread
  z-score reversion basket.

## Evidence Notes

- The EIA source provides official-source lineage for structural links between
  oil prices and exchange rates, including bidirectional and time-varying
  channels rather than a one-way forecast claim.
- The SNB source provides official central-bank lineage for treating CHF as a
  safe-haven currency whose risk response varies across counterpart currencies
  and becomes stronger in periods of stress.
- The QM implementation does not ingest EIA, SNB, futures-curve, rate, macro,
  or external FX data at runtime. It uses the source packet only for structural
  lineage and trades Darwinex MT5-native D1 OHLC for `XTIUSD.DWX` and
  `USDCHF.DWX`.

## Guardrails

- No external data calls in the EA.
- No ML, no adaptive parameter fitting, no grid, no martingale.
- Two-leg basket only, one package at a time.
- Backtests use RISK_FIXED setfiles. Live, T_Live, AutoTrading, deploy
  manifests, and portfolio gates are out of scope.
