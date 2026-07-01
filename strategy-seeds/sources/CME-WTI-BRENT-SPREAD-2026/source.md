---
source_id: CME-WTI-BRENT-SPREAD-2026
title: "WTI-Brent crude oil spread structure"
quality_tier: A
source_type: exchange_and_agency_reference
primary_links:
  - https://www.cmegroup.com/markets/energy/crude-oil/wti-brent-ice-calendar-swap-futures.html
  - https://www.eia.gov/todayinenergy/detail.php?id=67424
  - https://www.ice.com/products/1242/Brent-WTI-Futures-Spread/data
collected_by: Codex
collected_date: 2026-07-01
approved_for_cards: true
---

# WTI-Brent Crude Oil Spread Structure

## Reputable Source Basis

- CME lists an exchange-traded WTI-Brent Financial futures contract whose
  reference instruments are NYMEX WTI and ICE Brent futures.
- ICE lists a Brent/WTI Futures Spread contract, confirming that the cross-market
  crude benchmark spread is a standard traded energy structure rather than an
  invented synthetic.
- EIA publishes regular analysis of the Brent-WTI spread as a market structure
  variable tied to crude benchmark fundamentals, transport constraints,
  inventory location, and geopolitical/supply shocks.

## Mechanical Translation

This source packet supports a low-frequency market-neutral D1 basket:

- Host leg: `XTIUSD.DWX` as the WTI CFD proxy.
- Second leg: `XBRUSD.DWX` as the Brent CFD proxy.
- Signal: rolling z-score of `log(Brent) - beta * log(WTI)` on completed D1
  closes.
- Entry: fade extreme relative deviations in the benchmark spread.
- Exit: flatten near the rolling mean, on max hold, on Friday close, or through
  hard per-leg ATR stops.

The same source packet also supports a separate continuation variant when the
completed D1 benchmark spread exits a long channel:

- Signal: Donchian breakout of `log(Brent) - beta * log(WTI)`.
- Entry: buy Brent/sell WTI on upside spread breakout; sell Brent/buy WTI on
  downside spread breakout.
- Exit: flatten on an opposite shorter-channel break, max hold, Friday close,
  broken-package repair, or hard per-leg ATR stops.

The runtime EA uses broker OHLC data only. It does not consume futures curves,
inventory releases, EIA tables, ICE data, CME data, forecasts, options, analyst
feeds, ML models, grids, or martingale sizing.

## Non-Duplicate Notes

This packet is not the existing `QM5_12840` XTI/XNG return-spread reversion,
not the EIA XTI/XNG price-ratio sleeves, not WTI calendar/event logic, not Brent
weekday seasonality, and not a generic commodity RSI or trend-following build.
The S01 card is specifically a Brent-vs-WTI crude benchmark spread reversion
basket; the S02 card is a Brent-vs-WTI crude benchmark spread breakout basket.

## Q02 Data Note

`XBRUSD.DWX` is already represented in the local magic registry by
`QM5_12841_brent-thu-prem`, but it is not currently listed in
`framework/registry/dwx_symbol_history_ranges.csv`. Q02 must therefore validate
history sufficiency for this logical basket before any downstream phase can
promote it.
