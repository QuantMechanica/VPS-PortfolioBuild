---
source_id: EIA-XNG-FREEZE-2026
title: EIA natural-gas winter freeze-off price shock packet
status: cards_ready
created: 2026-06-27
created_by: Codex
source_type: official_energy_research
uri: https://www.eia.gov/todayinenergy/detail.php?id=50778
---

# EIA Natural-Gas Winter Freeze-Off Price Shock Packet

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: EIA Today in Energy, "U.S. natural gas prices spiked in February 2021, then generally increased through October", 2022-01-06, URL https://www.eia.gov/todayinenergy/detail.php?id=50778.
- Supplemental source: EIA Today in Energy, "February 2021 weather triggers largest monthly decline in U.S. natural gas production", 2021-05-10, URL https://www.eia.gov/todayinenergy/detail.php?id=47896.
- Supplemental source: EIA Today in Energy, "Cold weather brings near record-high natural gas spot prices", 2021-03-05, URL https://www.eia.gov/todayinenergy/detail.php?id=47016.

## Mining Scope

Two cards were extracted for structural natural-gas CFD sleeves:

- `eia-xng-frzfade`: XNGUSD.DWX D1 winter freeze-off spike fade.
- `eia-xng-frzbrk`: XNGUSD.DWX D1 winter freeze-off continuation breakout.

## Evidence Notes

- EIA documents that severe U.S. winter weather can create sharp natural-gas price spikes through heating demand, supply interruptions, and regional constraints.
- EIA also documents that extreme winter spot-price shocks can normalize after the acute weather stress passes.
- The QM implementations do not ingest weather, production, storage, pipeline,
  cash-market, futures-curve, EIA, or external API data at runtime. They use the
  official EIA lineage only to constrain the setup to January-February and then
  require XNGUSD.DWX D1 price confirmation. The fade card requires
  spike/rejection; the breakout card requires upside shock continuation.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive parameter fitting, grid, or martingale.
- Single-position XNGUSD.DWX sleeve, one magic slot.
