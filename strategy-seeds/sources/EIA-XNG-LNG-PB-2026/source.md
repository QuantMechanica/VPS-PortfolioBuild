---
source_id: EIA-XNG-LNG-PB-2026
title: EIA natural-gas LNG export demand pullback-continuation source
publisher: U.S. Energy Information Administration
source_type: official_government_energy_reference
status: cards_ready
created: 2026-07-09
created_by: Codex
cards_extracted:
  - xng-lng-pb
---

# EIA Natural Gas LNG Pullback Source

## Source URLs

- U.S. Energy Information Administration, "Factors affecting natural gas
  prices", Natural Gas Explained:
  https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php
- U.S. Energy Information Administration, "We expect Henry Hub natural gas spot
  prices to fall slightly in 2026 before rising in 2027", Today in Energy,
  January 14, 2026:
  https://www.eia.gov/todayinenergy/detail.php?id=67004
- U.S. Energy Information Administration, "U.S. natural gas exports to grow
  nearly 30% by 2027 as LNG facilities ramp up", Today in Energy, May 26,
  2026:
  https://www.eia.gov/todayinenergy/detail.php?id=67484
- U.S. Energy Information Administration, Natural Gas Weekly Update:
  https://www.eia.gov/naturalgas/weekly/

## Research Use

EIA identifies natural gas exports as a price-relevant supply-demand factor and
links forecast demand growth to LNG export-facility ramp-up. This source packet
uses those official observations only as structural lineage for an `XNGUSD.DWX`
D1 rule. The EA does not read EIA releases, LNG feedgas, weather, terminal
utilization, futures curves, CSV files, APIs, or discretionary inputs at
runtime.

The mechanized edge is a pullback-continuation variant, not the existing
`QM5_12769_eia-xng-lng-brk` compression breakout. It requires a recent
close-confirmed upside channel breakout in an LNG-demand month, then waits for a
controlled pullback toward the D1 SMA and a bullish reclaim bar before entering
long. The intent is lower-frequency continuation after demand-theme
confirmation, not immediate breakout chasing and not RSI mean reversion.

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher and all primary source URLs are EIA pages.
- R2 mechanical: PASS. Fixed LNG-demand months, recent breakout memory,
  SMA/ATR pullback zone, bullish reclaim trigger, ATR stop/target, time exit,
  and one-entry-per-month limiter are deterministic.
- R3 data available: PASS. `XNGUSD.DWX` is present in the DWX symbol matrix and
  has D1 history for Q02.
- R4 no ML/banned logic: PASS. No ML, adaptive PnL fitting, grid, martingale,
  external runtime data, or multiple positions per magic.
