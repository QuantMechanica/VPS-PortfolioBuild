---
source_id: BAKERHUGHES-RIGCOUNT-2026
title: Baker Hughes North America Rig Count
publisher: Baker Hughes
source_type: official_industry_data
status: mined
last_reviewed: 2026-07-03
cards_extracted:
  - rigcount-fri-mom
  - rigcount-fri-fade
  - xng-rig-fri-mom
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

The second extracted card, `rigcount-fri-fade`, uses the same official release
cadence but tests the opposite reaction profile: it fades unusually large
last-workday displacements that close at an extreme, seeking short-horizon
normalization during the first new-week bars. It is intentionally separated from
`rigcount-fri-mom` so Q02 can judge continuation and exhaustion as independent
WTI event-response hypotheses.

The third extracted card, `xng-rig-fri-mom`, applies the same official
Friday-release cadence to `XNGUSD.DWX` and treats the previous completed broker
week's final D1 bar as the market's response proxy for natural-gas drilling
activity. It is intentionally separate from the WTI cards because natural gas
has different storage, weather, power-burn, LNG, and rig-activity sensitivities,
and it is also separate from the existing `QM5_12567` commodity RSI pullback
logic.

## R-Rules

- R1 reputable source: PASS. Baker Hughes is the official rig-count publisher.
- R2 mechanical: PASS. Fixed new-week gate, last-workday return threshold,
  close-location confirmation, ATR stop, and time exit.
- R3 data available: PASS. `XTIUSD.DWX` and `XNGUSD.DWX` exist in the DWX
  symbol matrix.
- R4 no ML/banned logic: PASS. No ML, external runtime API, grid, martingale,
  pyramiding, or adaptive PnL fitting.
