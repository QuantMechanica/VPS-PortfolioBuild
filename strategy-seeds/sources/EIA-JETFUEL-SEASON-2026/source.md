---
source_id: EIA-JETFUEL-SEASON-2026
title: EIA jet fuel refinery yield and air-travel demand research
publisher: U.S. Energy Information Administration
source_type: government_energy_research
status: cards_ready
created: 2026-06-30
created_by: Codex
uri: https://www.eia.gov/todayinenergy/detail.php?id=64786
cards_extracted:
  - eia-jetfuel-brk
  - eia-jetfuel-pb
---

# EIA Jet Fuel Season Source

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: U.S. Energy Information Administration, "Jet fuel made up a
  record share of U.S. refinery output in 2024", Today in Energy, March 24,
  2025, URL https://www.eia.gov/todayinenergy/detail.php?id=64786.
- Secondary source: U.S. Energy Information Administration, "U.S. jet fuel
  consumption growth slows after air travel recovers from pandemic slowdown",
  Today in Energy, August 26, 2025, URL
  https://www.eia.gov/todayinenergy/detail.php?id=66004.
- Current confirmation: U.S. Energy Information Administration, "U.S. jet fuel
  production rises after prices doubled in March", Today in Energy, June 8,
  2026, URL https://www.eia.gov/todayinenergy/detail.php?id=67764.

## Research Use

The source is used for structural lineage around jet fuel as a refinery-output
and air-travel-demand channel that can move WTI differently from gasoline-only
driving-season, distillate winter, WPSR-inventory, OPEC, hurricane, roll, and
weekday crude-oil sleeves.

The mechanized cards narrow the source to Darwinex-native WTI expressions:
trade `XTIUSD.DWX` D1 upside breakouts or controlled pullback continuations
during the summer air-travel demand window after a crude trend filter confirms
that the refinery/feedstock impulse is already visible in price.

No EIA data, jet fuel prices, refinery yields, crack spreads, production data,
inventories, airline data, CSV files, APIs, or external feeds are read at
runtime. The EA uses Darwinex MT5 OHLC, broker calendar state, spread, ATR, and
SMA only.

## Guardrails

- Runtime uses `XTIUSD.DWX` D1 OHLC and broker calendar only.
- No external API calls or CSV dependencies.
- No ML, adaptive PnL fitting, grid, martingale, pyramiding, or discretionary
  override.
- One position per `XTIUSD.DWX` magic slot.

## R-Rules

- R1 reputable source: PASS. Official U.S. EIA energy analysis with dated URLs.
- R2 mechanical: PASS. Fixed date window, D1 breakout or pullback-continuation
  triggers, SMA trend gate, ATR hard stop, and deterministic channel/date/time
  exits.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic one-position structural sleeve.
