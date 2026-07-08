---
source_id: VANHEMERT-MOMTOM-2014
title: Van Hemert MOM-TOM CTA-flow timing and time-series momentum lineage
publisher: SSRN / Journal of Financial Economics lineage
source_type: working_paper_plus_journal_lineage
status: cards_ready
created: 2026-07-04
created_by: Codex
uri: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2515900
cards_extracted:
  - wti-tom-mom
  - xng-tom-mom
  - brent-tom-mom
---

# VANHEMERT-MOMTOM-2014

## Source Identity

- Primary: Van Hemert, Otto. "The MOM-TOM Effect: Detecting the Market Impact
  of CTA Trading." SSRN, 2014. URL:
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2515900.
- Momentum lineage: Moskowitz, Tobias J., Yao Hua Ooi and Lasse Heje Pedersen.
  "Time Series Momentum." Journal of Financial Economics, 104(2), 2012. URL:
  https://docs.lhpedersen.com/TimeSeriesMomentum.pdf.

## Research Use

This source is used for deterministic turn-of-month momentum cards. Van Hemert
tests whether trend-following CTA flow around turn-of-month windows pushes
momentum strategy returns temporarily in the direction of existing trends.
Moskowitz, Ooi and Pedersen provide the broader time-series momentum lineage
across futures and forwards, including commodities.

The QM implementation does not ingest CTA flows, futures curves, volume, open
interest, CFTC data, EIA data, external APIs, CSV files, analyst forecasts, or
ML output at runtime. It converts the source idea into Darwinex-native D1 rules:
inside a fixed broker-calendar turn-of-month window, trade in the direction of
a fixed completed-D1 momentum lookback, then flatten when the window ends or a
time/ATR exit fires.

## Extracted Cards

- `wti-tom-mom`: `XTIUSD.DWX` D1 turn-of-month momentum.
- `xng-tom-mom`: `XNGUSD.DWX` D1 turn-of-month momentum.
- `brent-tom-mom`: `XBRUSD.DWX` D1 turn-of-month momentum.

## Duplicate Boundary

The XNG card is not `QM5_12567_cum-rsi2-commodity`: it uses no RSI, oscillator,
short-horizon pullback, grid, martingale, ML, or cross-commodity basket. It is
also not XNG storage/weather/month-seasonality/month-open/rig-count or 12-month
TSMOM: the entry is a fixed turn-of-month timing window conditioned on a
medium-horizon D1 return sign.

The Brent card ports the same turn-of-month timing hypothesis to the Brent
benchmark proxy. It is separate from WTI TOM by benchmark, from Brent
month-of-year cards by using a recurring month-turn window conditioned on
medium-horizon momentum, and from Brent TSMOM/52-week/spread sleeves by using a
short deterministic holding window rather than a broad monthly trend or
relative-value basket.

## R-Rules

- R1 reputable source: PASS. Van Hemert SSRN source with public abstract page;
  JFE time-series momentum paper used as lineage.
- R2 mechanical: PASS. Fixed calendar window, fixed return lookback, ATR stop
  and target, time/window exits.
- R3 data available: PASS. `XTIUSD.DWX`, `XNGUSD.DWX`, and `XBRUSD.DWX` have
  active local routes through existing V5 energy builds; Q02 validates current
  history sufficiency for each concrete EA.
- R4 no ML/banned logic: PASS. Deterministic, one position per magic/symbol, no
  grid, no martingale, no adaptive PnL fitting.
