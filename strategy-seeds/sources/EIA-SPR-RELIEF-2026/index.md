---
source_id: EIA-SPR-RELIEF-2026
title: "EIA weekly SPR stock disclosure and WTI release-window policy-buffer context"
publisher: "U.S. Energy Information Administration / U.S. Department of Energy"
source_type: official_government_energy_data
status: mined
last_reviewed: 2026-07-03
cards_extracted:
  - xti-spr-relief
---

# EIA SPR Relief Source

## Source Links

- U.S. Energy Information Administration, Weekly Petroleum Status Report:
  https://www.eia.gov/petroleum/supply/weekly/
- U.S. Energy Information Administration, Weekly U.S. Ending Stocks of Crude
  Oil in SPR:
  https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCSSTUS1
- U.S. Department of Energy, SPR Quick Facts:
  https://www.energy.gov/hgeo/opr/spr-quick-facts

## Research Use

EIA publishes weekly official petroleum data that includes Strategic Petroleum
Reserve stock levels. The DOE SPR reference supplies the structural rationale
that the SPR is a government crude-oil buffer. This source is used only for the
hypothesis that WTI failed extremes during the official weekly SPR disclosure
window can mean-revert as a policy-buffer relief pattern.

The derived EA does not ingest DOE, EIA, SPR inventory, tender, news, API, CSV,
or policy-calendar data at runtime. It uses Darwinex `XTIUSD.DWX` D1 OHLC bars,
broker calendar time, framework spread/news/friday guards, ATR, and SMA.

## Gate Notes

- R1 PASS: official U.S. EIA/DOE source lineage.
- R2 PASS: deterministic D1 failed-extreme release-window rules can be coded
  and audited.
- R3 PASS: `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 PASS: no ML, no external runtime feed, no grid, no martingale.
