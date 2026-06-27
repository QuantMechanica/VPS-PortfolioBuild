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

Canonical source for the `wti-tsmom12m` and
`tsmom-9m-commodity-xtiusd` cards.

## Source Scope

This source documents the broad time-series-momentum finding across liquid
futures markets, including commodities. The QM card ports the source's
structural rule to the DWX-tradable WTI CFD, `XTIUSD.DWX`, using only MT5 D1
price history and broker calendar state at runtime.

## Extraction Notes

- Single-source lineage for R1: AQR/JFE page for Moskowitz, Ooi, and Pedersen,
  "Time Series Momentum".
- Extracted strategy: monthly 12-month return-sign momentum package on WTI.
- Extracted strategy: monthly 9-month return-sign momentum package on WTI with
  a 3-month same-sign confirmation filter.
- Runtime data deliberately excludes futures curves, open interest, inventory
  feeds, analyst forecasts, CSVs, APIs, and ML models.
- The EAs should be tested as energy sleeves, not as replacements for existing
  WTI calendar/event cards. The 9-month card is a shorter-horizon variant with
  confirmation and must be duplicate-reviewed against the 12-month card.
