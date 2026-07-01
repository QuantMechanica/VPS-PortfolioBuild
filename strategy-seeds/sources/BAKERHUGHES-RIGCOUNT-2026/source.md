---
source_id: BAKERHUGHES-RIGCOUNT-2026
title: Baker Hughes North America Rig Count
publisher: Baker Hughes
source_type: official_industry_data
status: mined
last_reviewed: 2026-07-01
cards_extracted:
  - rigcount-fri-mom
---

# Baker Hughes Rig Count Source

## Source Identity

- Baker Hughes Rig Count Overview and Summary Count,
  https://rigcount.bakerhughes.com/
- Baker Hughes Rig Count FAQ,
  https://bakerhughesrigcount.gcs-web.com/rig-count-faqs

## Research Use

Baker Hughes describes the North America Rig Count as a weekly census of active
drilling rigs exploring for or developing oil, natural gas, or geothermal energy
in the United States and Canada. The FAQ states that the North America report is
published each Friday at noon central U.S. time, and the overview describes rig
counts as an important petroleum-industry business barometer and leading
indicator for drilling-related demand.

The QM expression does not import Baker Hughes data at runtime. It uses the
last completed D1 bar of the broker week as the market's price reaction proxy
around the weekly rig-count release. The strategy enters only after a large,
directional last-workday displacement and holds briefly into the following week.

## R-Rules

- R1 reputable source: PASS. Baker Hughes is the official rig-count publisher.
- R2 mechanical: PASS. Fixed new-week gate, last-workday return threshold,
  close-location confirmation, ATR stop, and time exit.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, external runtime API, grid, martingale,
  pyramiding, or adaptive PnL fitting.
