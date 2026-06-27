---
source_id: EIA-NOAA-XNG-HURR-2026
title: EIA and NOAA natural-gas hurricane supply-risk packet
status: cards_ready
created: 2026-06-27
created_by: Codex
source_type: official_energy_weather_research
uri: https://www.eia.gov/todayinenergy/detail.php?id=62104
---

# EIA And NOAA Natural-Gas Hurricane Supply-Risk Packet

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: EIA Today in Energy, "Forecast strong hurricane season presents risk for U.S. oil and natural gas industry", 2024-06-13, URL https://www.eia.gov/todayinenergy/detail.php?id=62104.
- Supplemental source: NOAA National Hurricane Center, Tropical Cyclone Climatology, URL https://www.nhc.noaa.gov/climo/.
- Supplemental source: EIA Today in Energy, "Hurricane Ida disrupted crude oil production and refining activity", 2021-09-14, URL https://www.eia.gov/todayinenergy/detail.php?id=49576.

## Mining Scope

One card was extracted for a structural natural-gas CFD sleeve:

- `eia-xng-hurr-brk`: XNGUSD.DWX D1 peak hurricane-season supply-risk breakout.

## Evidence Notes

- EIA documents that Atlantic hurricanes can affect U.S. oil and natural gas markets through Gulf of Mexico production interruptions, LNG export disruptions, and energy infrastructure outages.
- NOAA/NHC defines the Atlantic hurricane season and shows activity clustering around the mid-August to mid-October peak window.
- The QM implementation does not ingest EIA, NOAA, hurricane-track, weather, production, LNG, storage, futures-curve, or external API data at runtime. It uses the official sources only for structural lineage, then requires XNGUSD.DWX D1 price confirmation during a fixed peak-season window.

## Guardrails

- No external data calls in the EA.
- No ML, adaptive parameter fitting, grid, or martingale.
- Single-position XNGUSD.DWX sleeve, one magic slot.
