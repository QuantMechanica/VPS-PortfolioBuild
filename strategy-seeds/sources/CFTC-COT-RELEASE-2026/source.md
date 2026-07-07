---
source_id: CFTC-COT-RELEASE-2026
title: CFTC Commitments of Traders release cadence
publisher: U.S. Commodity Futures Trading Commission
source_type: official_government_market_data
status: cards_ready
last_reviewed: 2026-07-07
source_urls:
  - https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm
  - https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm
  - https://www.cmegroup.com/tools-information/quikstrike/commitment-of-traders.html
cards_extracted:
  - xti-cot-fade
  - xti-cot-mom
---

# CFTC Commitments of Traders Release Cadence

## Source Identity

- Primary official source: U.S. Commodity Futures Trading Commission,
  "Commitments of Traders", URL
  https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm.
- Official release schedule: U.S. Commodity Futures Trading Commission,
  "Commitments of Traders Release Schedule", URL
  https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm.
- Supplement: CME Group, "Commitment of Traders", URL
  https://www.cmegroup.com/tools-information/quikstrike/commitment-of-traders.html.

## Research Use

The CFTC Commitments of Traders pages describe a weekly public futures and
options positioning report. The CFTC source states that reports are generally
based on Tuesday position data and released Friday afternoon, with holidays
able to alter the exact schedule.

The QM expression does not download, parse, or store CFTC data at runtime. It
uses the official COT release cadence as structural lineage and tests whether
the completed Friday `XTIUSD.DWX` D1 bar contains a tradable positioning-window
reaction proxy.

Two mechanical hypotheses are intentionally separated:

- `xti-cot-fade`: fades unusually extended Friday COT-window displacements.
- `xti-cot-mom`: follows Friday COT-window displacements only when the move is
  also a trend-confirmed Donchian breakout.

## R-Rules

- R1 reputable source: PASS. CFTC is the official COT publisher; CME is used
  only as exchange-context supplement.
- R2 mechanical: PASS. Fixed first-new-week gate, prior Friday displacement,
  close-location, ATR scaling, trend/channel confirmation, ATR stop, and
  deterministic exits.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, external runtime API, grid, martingale,
  pyramiding, or adaptive PnL fitting.
