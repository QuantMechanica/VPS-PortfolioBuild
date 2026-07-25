---
source_id: EIA-WTI-WPSR-INTRADAY-2026
title: EIA Weekly Petroleum Status Report intraday WTI event structure
publisher: U.S. Energy Information Administration
source_type: official_government_market_report
status: approved
created: 2026-07-25
created_by: Codex
last_updated: 2026-07-25
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-07-25
uri: https://www.eia.gov/petroleum/supply/weekly/
strategy_ids:
  - EIA-WTI-WPSR-INTRADAY-2026_S01
---

# EIA Weekly Petroleum Status Report Intraday WTI Source

## Source identity

- Publisher: U.S. Energy Information Administration.
- Primary source: Weekly Petroleum Status Report.
- URL: https://www.eia.gov/petroleum/supply/weekly/
- Release schedule:
  https://www.eia.gov/petroleum/supply/weekly/schedule.php
- Existing repository lineage:
  `strategy-seeds/sources/EIA-WTI-WPSR-IDBRK-2026/source.md`,
  `strategy-seeds/sources/EIA-WTI-WPSR-AFTERSHOCK-2026/source.md`, and
  `framework/EAs/QM5_1121_unger-crude-inventory-release/`.

## Mining scope

One mechanically bounded card is authorized from this packet:

- `wti-wpsr-pb`: `XTIUSD.DWX` M30 standard-Wednesday WPSR release impulse
  followed by one completed shallow counter-direction pullback bar. Entry is
  at 11:30 New York in the original impulse direction, with a structural
  event-sequence stop, fixed-R target, and same-session exit.

## Evidence notes

- The existing repository packets establish the WPSR as an official recurring
  weekly information event for crude-oil and refined-product markets.
- The existing governed `QM5_1121_unger-crude-inventory-release` build locks
  the standard event clock to Wednesday 10:30 New York and already treats
  holiday-shifted weeks as a distinct scheduling problem.
- Fresh generic-URL retrieval attempts for the WPSR page and release schedule
  on 2026-07-25 both returned `DEFERRED:SOURCE_POLICY` from the deterministic
  source router. No browser, proxy, cache, authentication, or policy bypass
  was attempted. This packet imports no new webpage text or changed schedule
  claim.
- The EA reads no inventory value, consensus, surprise, schedule file,
  analyst forecast, futures curve, CSV, API, volume, or external market data.
  It trades only native Darwinex `XTIUSD.DWX` timestamps, M30 OHLC, ATR,
  executable quotes, positions, and deal history.
- EIA supports the event identity and official schedule lineage only. The
  impulse threshold, shallow-pullback definition, continuation direction,
  stop, target, and same-session lifecycle are QM research hypotheses. EIA
  does not claim they are profitable and does not certify a Darwinex CFD as a
  futures replica.
- Version 1 trades only the standard Wednesday clock and deliberately skips
  holiday-shifted releases rather than inferring them without an authorized
  runtime calendar.

## Guardrails

- No external runtime data calls.
- No ML, banned indicator, adaptive fitting, grid, martingale, scale-in, or
  pyramiding.
- One `XTIUSD.DWX` position and one consumed decision per standard Wednesday.
- Card/build approval is non-live only. It does not authorize a live setfile,
  AutoTrading, `T_Live`, a deploy manifest, portfolio admission, a portfolio
  gate change, or a correlation waiver.
