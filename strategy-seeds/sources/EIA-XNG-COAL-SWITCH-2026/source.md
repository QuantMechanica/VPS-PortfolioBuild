---
source_id: EIA-XNG-COAL-SWITCH-2026
title: EIA natural-gas fuel-switching and electric-power demand packet
publisher: U.S. Energy Information Administration
source_type: official_agency_web
status: approved
approved_by: mission-directed fleet assignment
approved_at: 2026-07-09
primary_url: https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php
---

# EIA Natural-Gas Fuel-Switching Source

## Primary source

U.S. Energy Information Administration, "Factors affecting natural gas
prices", Energy Explained, updated October 25, 2023:

https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php

The page identifies weather, economic growth, storage, and the availability and
prices of competing fuels as natural-gas price drivers. It explains that some
large fuel users can switch among natural gas, coal, and petroleum based on
relative cost. It also states that favorable natural-gas prices have supported
greater electric-power-sector gas use.

## Supporting source

U.S. Energy Information Administration, "Electricity generation from coal and
natural gas both increased with summer heat", October 19, 2012:

https://www.eia.gov/todayinenergy/detail.php?id=8450

The article documents the dispatch mechanism more specifically: lower natural-
gas prices allowed gas-fired generators to compete with coal, while fuel-price
sensitivity is lower at the height of summer when peaking generation is needed
regardless of relative fuel cost. That distinction supports testing the price-
elastic demand-floor thesis in spring and early-autumn shoulder windows rather
than duplicating the existing summer-power sleeve.

## Current structural context

U.S. Energy Information Administration, "Natural gas for power generation flat
this summer, record high expected in 2027", May 28, 2026:

https://www.eia.gov/todayinenergy/detail.php?id=67725

EIA reports that summer electric-power gas consumption remains near recent
highs, that gas has become more competitive with coal in PJM, and that the
national summer generation mix has continued to shift away from coal toward
natural gas and renewables. This is context for a continuing demand channel,
not a performance claim.

## Mechanization boundary

The source establishes a physical demand response, not a ready-made trading
rule. The V5 expression tests a deliberately conservative proxy using only
Darwinex `XNGUSD.DWX` D1 OHLC, ATR, SMA, broker dates, and spread:

- spring and early-autumn shoulder windows, when dispatch is more price
  sensitive than at the summer peak;
- a bottom-quartile 252-D1 closing-price rank as the favorable-price regime;
- a completed-bar SMA reclaim and strong close as confirmation that the demand
  floor is being recognized;
- ATR stop/target, price-rank normalization, SMA failure, and time exits.

No EIA data, coal price, power load, weather, storage, futures curve, CSV, API,
forecast, volume, open interest, or discretionary input is read at runtime.
No source performance number is imported. Q02 and later phases must validate or
reject trade generation, profitability, cost tolerance, and book correlation.

## Reputable-source criteria

- R1: PASS. EIA is the official U.S. energy-statistics agency and every cited
  page has a stable public URL.
- R2: PASS. The port is fully deterministic and documented in the approved
  card.
- R3: PASS. `XNGUSD.DWX` exists in the local DWX matrix and magic registry.
- R4: PASS. No machine learning, adaptive PnL fitting, grid, martingale, or
  external runtime data.

