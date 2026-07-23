---
source_id: MOP-TSMOM-2012
source_type: paper
title: Time Series Momentum
authors: Tobias J. Moskowitz, Yao Hua Ooi, Lasse Heje Pedersen
publication: Journal of Financial Economics, 2012
url: https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum
status: cards_ready
created: 2026-06-27
created_by: Codex
---

# Time Series Momentum

Canonical source for the `wti-tsmom12m`,
`tsmom-9m-commodity-xtiusd`, and `xng-tsmom12m-atr` cards.

## Source Scope

This source documents the broad time-series-momentum finding across liquid
futures markets, including commodities. QM cards port the source's structural
rule to DWX-tradable energy CFDs such as `XTIUSD.DWX` and `XNGUSD.DWX`, using
only MT5 D1 price history and broker calendar state at runtime.

## Extraction Notes

- Single-source lineage for R1: AQR/JFE page for Moskowitz, Ooi, and Pedersen,
  "Time Series Momentum".
- Extracted strategy: monthly 12-month return-sign momentum package on WTI.
- Extracted strategy: monthly 9-month return-sign momentum package on WTI with
  a 3-month same-sign confirmation filter.
- Extracted strategy: monthly WTI dual-horizon 6-month and 12-month
  return-sign momentum package requiring both horizons to agree.
- Extracted strategy: monthly WTI 12-month return-sign momentum package gated
  by a fixed ATR-as-percent-of-price volatility corridor.
- Extracted strategy: monthly natural-gas 12-month return-sign momentum package
  gated by a fixed ATR-as-percent-of-price volatility corridor.
- Extracted strategy: monthly natural-gas 3-month return-sign momentum package
  without the 12-month card's ATR/price volatility corridor; OWNER explicitly
  expanded this source lane for the 2026-07-23 commodity-sleeve mission.
- Extracted strategy: monthly Brent 12-month return-sign momentum package on
  `XBRUSD.DWX`, kept separate from WTI TSMOM and Brent/WTI spread baskets.
- Runtime data deliberately excludes futures curves, open interest, inventory
  feeds, analyst forecasts, CSVs, APIs, and ML models.
- The EAs should be tested as energy sleeves, not as replacements for existing
  WTI calendar/event cards. The 9-month and dual-horizon cards are shorter or
  confirmation-filtered variants and must be duplicate-reviewed against the
  pure 12-month card.
