---
source_id: EIA-XNG-STORAGE-AFTERSHOCK-2026
title: EIA Weekly Natural Gas Storage Report event structure
status: cards_ready
created: 2026-06-26
created_by: Codex
source_type: government_energy_research
uri: https://www.eia.gov/naturalgas/storage/
---

# EIA Weekly Natural Gas Storage Report Aftershock Source

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: EIA Weekly Natural Gas Storage Report.
- URL: https://www.eia.gov/naturalgas/storage/
- Release schedule: https://www.eia.gov/naturalgas/schedule/

## Mining Scope

One card was extracted for a structural natural-gas sleeve:

- `eia-xng-storage`: XNGUSD.DWX D1 weekly storage-report reaction aftershock.

## Evidence Notes

- EIA publishes a recurring weekly natural-gas storage report covering working
  gas in underground storage.
- The report is a scheduled energy-market information event. The QM
  implementation does not ingest storage levels, consensus forecasts, surprises,
  EIA files, or external APIs at runtime.
- The EA uses the D1 bar that contains the scheduled storage-report reaction as
  a price-only proxy: after that bar closes, it follows only large directional
  XNGUSD.DWX reactions for a short aftershock window.

## Guardrails

- No external data calls in the EA.
- No ML, no adaptive parameter fitting, no grid, no martingale.
- Single-position XNGUSD.DWX sleeve, one magic slot.
