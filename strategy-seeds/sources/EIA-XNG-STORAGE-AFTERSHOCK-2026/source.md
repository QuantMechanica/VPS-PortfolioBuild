---
source_id: EIA-XNG-STORAGE-AFTERSHOCK-2026
title: EIA Weekly Natural Gas Storage Report event structure
status: approved
created: 2026-06-26
created_by: Codex
last_updated: 2026-07-25
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-07-25
source_type: government_energy_research
uri: https://www.eia.gov/naturalgas/storage/
strategy_ids:
  - EIA-XNG-STORAGE-AFTERSHOCK-2026
  - EIA-XNG-STORAGE-INTRADAY-2026_S01
  - EIA-XNG-STORAGE-INTRADAY-2026_S02
---

# EIA Weekly Natural Gas Storage Report Aftershock Source

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: EIA Weekly Natural Gas Storage Report.
- URL: https://www.eia.gov/naturalgas/storage/
- Release schedule: https://ir.eia.gov/ngs/schedule.html

## Mining Scope

Two mechanically distinct cards are bounded by this official event source:

- `eia-xng-storage`: XNGUSD.DWX D1 weekly storage-report reaction aftershock.
- `xng-stor-m30`: XNGUSD.DWX M30 standard-Thursday release-bar impulse
  continuation, entered only after the 10:30-11:00 New York bar closes and
  flattened in the same New York session.
- `xng-stor-fade`: XNGUSD.DWX M30 standard-Thursday failed-release-break
  reclaim, entered only after the 11:00-11:30 New York confirmation bar closes
  back inside the pre-release range and flattened in the same New York session.

## Evidence Notes

- EIA publishes a recurring weekly natural-gas storage report covering working
  gas in underground storage.
- EIA's natural-gas data page states that the regular Weekly Natural Gas
  Storage Report release is Thursday at 10:30 a.m. eastern time. The official
  WNGSR schedule states that federal-holiday weeks can use exceptions.
- Source review refreshed 2026-07-25 from:
  - https://www.eia.gov/naturalgas/data.php
  - https://ir.eia.gov/ngs/schedule.html
- The report is a scheduled energy-market information event. The QM
  implementation does not ingest storage levels, consensus forecasts, surprises,
  EIA files, or external APIs at runtime.
- The EA uses the D1 bar that contains the scheduled storage-report reaction as
  a price-only proxy: after that bar closes, it follows only large directional
  XNGUSD.DWX reactions for a short aftershock window.
- The M30 extraction uses only the standard Thursday clock. It deliberately
  skips holiday-shifted releases because the EA has no external schedule feed.
  Its continuation direction, price filters, stop, and session exit are QM
  hypotheses; EIA supplies event identity and timing, not a profitability claim.
- The second M30 extraction waits one additional completed bar. It fades only
  when the 10:30 release impulse broke the prior hour but the 11:00 bar closes
  back inside that prior range and through the impulse midpoint. Its reclaim
  rule, release-open target, structural stop, and session exit are likewise QM
  hypotheses rather than EIA findings.

## Guardrails

- No external data calls in the EA.
- No ML, no adaptive parameter fitting, no grid, no martingale.
- Single-position XNGUSD.DWX sleeves, one magic slot per EA.
- Card/build approval is non-live only. It does not authorize portfolio
  admission, a deploy manifest, T_Live, or AutoTrading.
