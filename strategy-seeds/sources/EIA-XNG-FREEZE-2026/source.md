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

One card was extracted for a structural natural-gas CFD sleeve:

- `eia-xng-frzfade`: XNGUSD.DWX D1 winter freeze-off spike fade.

## Evidence Notes

- EIA documents that severe U.S. winter weather can create sharp natural-gas price spikes through heating demand, supply interruptions, and regional constraints.
- EIA also documents that extreme winter spot-price shocks can normalize after the acute weather stress passes.
- The QM implementation does not ingest weather, production, storage, pipeline, cash-market, futures-curve, EIA, or external API data at runtime. It uses the official EIA lineage only to constrain the setup to January-February and then requires XNGUSD.DWX D1 spike/rejection confirmation.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive parameter fitting, grid, or martingale.
- Single-position XNGUSD.DWX sleeve, one magic slot.
