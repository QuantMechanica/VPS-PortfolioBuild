---
source_id: EIA-XTI-DAYS-SUPPLY-FADE-2026
title: EIA crude-oil days of supply and WPSR loose-cover proxy
status: cards_ready
created: 2026-07-07
created_by: Codex
source_type: official_energy_statistics
uri: https://www.eia.gov/dnav/pet/PET_SUM_SNDW_A_EPC0_VSD_DAYS_W.htm
---

# EIA Crude-Oil Days Of Supply Loose-Cover Proxy

## Source Identity

- Publisher: U.S. Energy Information Administration.
- Primary source: EIA "Crude Oil Days of Supply" weekly data series.
- Primary URL: https://www.eia.gov/dnav/pet/PET_SUM_SNDW_A_EPC0_VSD_DAYS_W.htm
- Supplement: EIA "Weekly Petroleum Status Report".
- Supplement URL: https://www.eia.gov/petroleum/supply/weekly/

## Mining Scope

One card was extracted for a structural WTI crude-oil CFD sleeve:

- `xti-loose-supply-fade`: `XTIUSD.DWX` D1 short-only loose-cover breakdown
  proxy during the WPSR information window.

## Evidence Notes

- EIA publishes the crude-oil days-of-supply series inside its weekly petroleum
  supply estimates.
- The same weekly petroleum source family provides the regular WPSR cadence
  used as a Wednesday/Thursday broker-calendar proxy.
- The card does not forecast or ingest EIA data at runtime. It expresses the
  lineage as a Darwinex-native D1 price proxy on `XTIUSD.DWX`.

## Guardrails

- Runtime data is limited to MT5 `XTIUSD.DWX` OHLC, broker calendar, spread,
  ATR, SMA, and channel calculations.
- No ML, adaptive PnL fitting, grid, martingale, external API, CSV feed, live
  manifest, portfolio gate, `T_Live`, or AutoTrading change.
- One `XTIUSD.DWX` magic slot only.
