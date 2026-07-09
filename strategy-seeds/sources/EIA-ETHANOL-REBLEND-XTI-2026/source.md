---
source_id: EIA-ETHANOL-REBLEND-XTI-2026
title: EIA ethanol blending and spring gasoline reblend structure
publisher: U.S. Energy Information Administration
source_type: official_agency_source_packet
status: cards_ready
created: 2026-07-09
created_by: Codex
cards_extracted:
  - xti-ethanol-reblend
---

# EIA Ethanol Reblend XTI Source

## Source Identity

- Primary source: U.S. Energy Information Administration, "Ethanol blending
  provides another proxy for gasoline demand", Today in Energy, October 7,
  2013, URL https://www.eia.gov/todayinenergy/detail.php?id=13271.
- Supporting source: U.S. Energy Information Administration, "U.S. fuel ethanol
  production continues to grow in 2017", Today in Energy, July 21, 2017, URL
  https://www.eia.gov/todayinenergy/detail.php?id=32152.
- Supporting source: U.S. Energy Information Administration, "What's in your
  gasoline? Understanding U.S. motor gasoline formulations", Today in Energy,
  April 15, 2026, URL https://www.eia.gov/todayinenergy/detail.php?id=67464.
- Data cadence reference: U.S. Energy Information Administration, "Weekly
  Petroleum Status Report", URL https://www.eia.gov/petroleum/supply/weekly/.

## Research Use

The EIA ethanol-blending source states that weekly gasoline blended with ethanol
is a proxy for gasoline consumption when most gasoline is E10. The 2017 EIA
ethanol article documents that fuel ethanol production can dip during April
plant maintenance, and the 2026 gasoline formulation article documents the
spring/summer gasoline formulation switch. The WPSR table list confirms that
fuel ethanol and gasoline stock series are published in the weekly petroleum
data complex.

This card converts that official-source lineage into a deterministic Darwinex
`XTIUSD.DWX` D1 spring reblend sleeve. Runtime does not read EIA data. The EA
waits for a late-April to mid-June WTI pullback below its D1 mean, then buys
only after a completed D1 bar reclaims the mean with ATR-sized body/range and
upper-range close confirmation.

## Guardrails

- Runtime uses native MT5 `XTIUSD.DWX` D1 OHLC, spread, ATR, SMA, broker
  calendar, and V5 framework state only.
- No EIA API, fuel-ethanol feed, WPSR values, gasoline stock feed, refinery
  statistic, futures curve, volume, open interest, CSV, analyst forecast,
  discretionary override, ML, adaptive PnL fitting, grid, martingale, or
  pyramiding.
- One position per `XTIUSD.DWX` magic slot.
- The rule is intentionally not a generic Wednesday/Thursday WPSR aftershock,
  broad May-August gasoline-stock momentum rule, holiday gasoline pull-forward
  fade, RBOB crack-spread sleeve, XTI/XNG ratio sleeve, XNG RSI sleeve, or
  XAU/XAG basket.

## R-Rules

- R1 reputable source: PASS. Official EIA source packet with primary and
  supporting public pages.
- R2 mechanical: PASS. Fixed D1 spring date window, pullback/reclaim entry,
  ATR stop/target, SMA/time/window exits, and one-position guard.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic single-position D1 sleeve.
