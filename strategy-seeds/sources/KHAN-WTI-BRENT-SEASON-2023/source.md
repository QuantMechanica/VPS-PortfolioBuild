---
source_id: KHAN-WTI-BRENT-SEASON-2023
title: "Understanding the Seasonality in Crude Oil Returns for WTI and Brent"
quality_tier: B
source_type: posted_research_paper
status: cards_ready
created: 2026-07-01
created_by: Codex
uri: https://www.researchsquare.com/article/rs-2569101/v1.pdf
cards_extracted:
  - wti-may-prem
---

# Khan WTI/Brent Seasonality Source

## Source Identity

- Authors: Zafarullah Khan, Tapash Ranjan Saha, and Tosin Ekundayo.
- Source: "Understanding the Seasonality in Crude Oil Returns for WTI and
  Brent", Research Square posted content, DOI 10.21203/rs.3.rs-2569101/v1.
- Primary URL: https://www.researchsquare.com/article/rs-2569101/v1.pdf

## Research Use

This source is used for a single WTI month-of-year card. The paper studies daily
and monthly WTI and Brent crude-oil returns and reports that May has the highest
average monthly return in the sample, while November and December are the
weakest months. The QM card isolates the positive May side only.

The runtime implementation does not import the paper's performance values. Q02+
must validate the deterministic rule on Darwinex `XTIUSD.DWX` D1 bars.

## Guardrails

- Runtime uses Darwinex MT5 OHLC and broker calendar only.
- No external API calls, CSV feeds, futures curve, inventory data, analyst
  forecast, or discretionary override.
- No ML, adaptive PnL fitting, grid, or martingale.
- One position per `XTIUSD.DWX` magic slot.

## R-Rules

- R1 source lineage: PASS. Single research-paper source with URL and source ID.
- R2 mechanical: PASS. Fixed D1 May entry, ATR stop, and deterministic time exit.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic single-position calendar sleeve.
