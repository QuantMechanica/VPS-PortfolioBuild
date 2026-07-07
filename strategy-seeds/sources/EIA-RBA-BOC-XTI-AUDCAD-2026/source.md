---
source_id: EIA-RBA-BOC-XTI-AUDCAD-2026
title: EIA/RBA/BoC WTI and AUDCAD commodity-FX source packet
status: cards_ready
created: 2026-07-07
created_by: Codex
source_type: government_and_central_bank_research
uri: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
---

# EIA/RBA/BoC WTI and AUDCAD Commodity-FX Source Packet

## Source Identity

- Primary source: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.
- Primary URL: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
- Supplement: Reserve Bank of Australia, "Drivers of the Australian Dollar
  Exchange Rate".
- Supplement URL: https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html
- Supplement: Bank of Canada, Monetary Policy Report April 2026, Canadian
  outlook footnote on the historical CAD/oil relationship.
- Supplement URL: https://www.bankofcanada.ca/publications/mpr/mpr-2026-04-29/canadian-outlook/

## Mining Scope

One card was extracted for a structural commodity/FX relative-value sleeve:

- `xti-audcad-rspr`: XTIUSD.DWX/AUDCAD.DWX D1 WTI-versus-CAD-through-AUDCAD
  return-spread z-score reversion basket.

## Evidence Notes

- The EIA working paper provides official-source lineage for time-varying
  links, long-run relationships, and short-run predictability between oil
  prices and exchange rates.
- The RBA source provides official central-bank lineage for AUD as a commodity
  currency and for commodity prices as a terms-of-trade exchange-rate driver.
- The Bank of Canada source documents that CAD historically rose with stronger
  oil prices while also warning that the relationship weakened after 2015. The
  card therefore uses a mean-reversion spread, not a one-way oil-to-CAD signal.
- The EA consumes none of these sources at runtime. It trades only Darwinex MT5
  D1 OHLC, spread, ATR, broker calendar, and V5 framework state for
  `XTIUSD.DWX` and `AUDCAD.DWX`.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive PnL fitting, grid, martingale, or pyramiding.
- Two-leg basket only, one package at a time.
- Backtests use `RISK_FIXED` setfiles. Live, `T_Live`, AutoTrading, deploy
  manifests, portfolio gates, and portfolio admission are out of scope.
