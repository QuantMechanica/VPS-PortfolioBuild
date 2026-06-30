---
source_id: CME-XNG-EXPIRY-BRK-2026
title: CME Henry Hub Natural Gas futures expiration window
publisher: CME Group
source_type: exchange_rulebook
status: cards_ready
created: 2026-06-30
created_by: Codex
uri: https://www.cmegroup.com/rulebook/NYMEX/2/220.pdf
cards_extracted:
  - xng-exp-brk
---

# CME XNG Expiry Breakout Source

## Source Identity

- Publisher: CME Group / NYMEX.
- Primary source: CME Group, "Chapter 220 Henry Hub Natural Gas Futures",
  URL https://www.cmegroup.com/rulebook/NYMEX/2/220.pdf.
- Supplemental source: CME Group, "Henry Hub Natural Gas Futures Contract
  Specs", URL
  https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.contractSpecs.html.
- Supplemental source: CME Group, "Understanding Futures Expiration &
  Contract Roll", URL
  https://www.cmegroup.com/education/courses/introduction-to-futures/understanding-futures-expiration-contract-roll.

## Research Use

This source is used for structural lineage around the recurring final-trading
and delivery process for Henry Hub Natural Gas futures. The mechanized card
ports that monthly flow window to a Darwinex-native natural-gas sleeve:
`XNGUSD.DWX` D1 channel breakout confirmation around the approximate last
trading day.

The implementation does not ingest CME data, futures curves, open interest,
volume, storage data, analyst forecasts, CSV files, APIs, or external feeds at
runtime. It uses Darwinex MT5 OHLC and broker calendar state only.

## Guardrails

- Runtime uses `XNGUSD.DWX` D1 OHLC and broker calendar only.
- The last-trading-day window is approximated from calendar/business-day logic;
  exchange holidays are not imported.
- No external API calls or CSV dependencies.
- No ML, adaptive PnL fitting, grid, martingale, pyramiding, or discretionary
  override.
- One position per `XNGUSD.DWX` magic slot.

## R-Rules

- R1 reputable source: PASS. Official CME/NYMEX exchange rulebook and contract
  specification source packet.
- R2 mechanical: PASS. Fixed monthly calendar approximation, D1 channel
  breakout, SMA/range/close-location confirmation, ATR hard stop, window exit,
  and max-hold exit.
- R3 data available: PASS. `XNGUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic one-position monthly structural
  breakout sleeve.

