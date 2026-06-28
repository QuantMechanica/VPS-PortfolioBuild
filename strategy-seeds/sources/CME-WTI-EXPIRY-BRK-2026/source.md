---
source_id: CME-WTI-EXPIRY-BRK-2026
title: CME WTI futures expiration and contract-roll structure
publisher: CME Group
source_type: exchange_rulebook_and_education
status: mined
last_reviewed: 2026-06-27
cards_extracted:
  - cme-wti-exp-brk
  - wti-postroll-fade
---

# CME WTI Expiry/Roll Source

## Source URLs

- CME Group, "Chapter 200 Light Sweet Crude Oil Futures":
  https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf
- CME Group, "Understanding Futures Expiration & Contract Roll":
  https://www.cmegroup.com/education/courses/introduction-to-futures/understanding-futures-expiration-contract-roll
- CME Group, "Crude Oil Futures Contract Specs":
  https://www.cmegroup.com/markets/energy/crude-oil/light-sweet-crude.contractSpecs.html

## Research Use

This source packet is used for structural lineage around recurring WTI futures
expiration and contract-roll pressure. CME Rulebook Chapter 200 defines the
monthly termination schedule for Light Sweet Crude Oil futures. CME education
material explains that futures positions must be offset, rolled, or settled
before expiration, creating recurring position-management activity around the
front-month transition.

The mechanized card does not ingest CME futures data, volume, open interest,
expiration calendars, or APIs at runtime. It approximates the monthly WTI
termination date from the broker calendar, then trades only if Darwinex
`XTIUSD.DWX` D1 bars show a confirmed breakout inside that window.

The second mechanized card isolates the post-roll pressure-relief window. It
waits until after the default expiry breakout window, then fades stretched
`XTIUSD.DWX` D1 impulses back toward a short D1 mean. It uses only broker OHLC
and the same deterministic calendar approximation; no futures-chain, open
interest, volume, calendar feed, CSV, or API is used at runtime.

## Extracted Cards

- `cme-wti-exp-brk`: XTIUSD.DWX D1 expiry/roll-window breakout sleeve.
- `wti-postroll-fade`: XTIUSD.DWX D1 post-expiry roll-window impulse fade.

## R-Rules

- R1 reputable source: PASS. Primary source is CME's own NYMEX WTI rulebook and
  CME education material.
- R2 mechanical: PASS. Fixed calendar calculation, closed-bar D1 channel/SMA
  breakout, ATR stop, and deterministic exits.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, adaptive fitting, grid, martingale,
  external API, CSV, or discretionary input.
