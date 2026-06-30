---
source_id: EIA-SNB-WTI-CHF-2026
title: EIA/SNB WTI and CHF commodity-FX breakout source packet
status: cards_ready
created: 2026-06-30
created_by: Codex
source_type: government_and_central_bank_research
uri: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
---

# EIA/SNB WTI and CHF Commodity-FX Source Packet

## Source Identity

- Primary source: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.
- Primary URL: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
- Supplement: Swiss National Bank, "The Swiss franc as a safe-haven currency",
  SNB Quarterly Bulletin 2020 Q2.
- Supplement URL: https://www.snb.ch/en/publications/communication/quarterly-bulletin/2020/q2

## Mining Scope

One card was extracted for a structural commodity/FX relative-value sleeve:

- `wti-usdchf-brk`: XTIUSD.DWX/USDCHF.DWX D1 CHF-terms channel breakout basket.

## Evidence Notes

- The EIA source provides official-source lineage for structural links between
  oil prices and exchange rates.
- The SNB source provides official central-bank lineage for treating CHF as a
  safe-haven currency, making `USDCHF.DWX` a useful Darwinex-native hedge leg
  when expressing oil in CHF terms.
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
