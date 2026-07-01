---
ea_id: QM5_12820
slug: eia-xng-frzbrk
type: strategy
source_id: EIA-XNG-FREEZE-2026
strategy_id: EIA-XNG-FREEZE-2026_S02
source_citation: "U.S. Energy Information Administration. U.S. natural gas prices spiked in February 2021, then generally increased through October. Today in Energy, 2022-01-06. URL https://www.eia.gov/todayinenergy/detail.php?id=50778; February 2021 weather triggers largest monthly decline in U.S. natural gas production. Today in Energy, 2021-05-10. URL https://www.eia.gov/todayinenergy/detail.php?id=47896; Cold weather brings near record-high natural gas spot prices. Today in Energy, 2021-03-05. URL https://www.eia.gov/todayinenergy/detail.php?id=47016"
source_citations:
  - type: official_energy_research
    citation: "U.S. Energy Information Administration. U.S. natural gas prices spiked in February 2021, then generally increased through October. Today in Energy, 2022-01-06."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=50778"
    quality_tier: A
    role: primary
  - type: official_energy_research
    citation: "U.S. Energy Information Administration. February 2021 weather triggers largest monthly decline in U.S. natural gas production. Today in Energy, 2021-05-10."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=47896"
    quality_tier: A
    role: supplement
  - type: official_energy_research
    citation: "U.S. Energy Information Administration. Cold weather brings near record-high natural gas spot prices. Today in Energy, 2021-03-05."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=47016"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-XNG-FREEZE-2026]]"
concepts:
  - "[[concepts/natural-gas-winter-freeze-off]]"
  - "[[concepts/weather-shock-continuation]]"
  - "[[concepts/channel-breakout]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
  - "[[indicators/donchian-channel]]"
strategy_type_flags: [calendar-seasonality, weather-shock-proxy, channel-breakout, trend-filter-ma, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12820_XNG_FRZBRK_D1
period: D1
expected_trade_frequency: "January-February D1 natural-gas winter freeze-off continuation breakout; estimate 4-8 trades/year after shock, channel, close-location, and spread filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
expected_pf: 1.10
expected_dd_pct: 24.0
g0_approval_reasoning: "R1 PASS official EIA winter natural-gas price shock source packet; R2 PASS deterministic Jan-Feb D1 upside shock/channel breakout with SMA, ATR stop, and time exits; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# EIA XNG Winter Freeze-Off Breakout

This approved card is the build-time mirror of
`strategy-seeds/cards/eia-xng-frzbrk_card.md`.

## Source

- Source: [[sources/EIA-XNG-FREEZE-2026]]
- Primary citation: U.S. Energy Information Administration, "U.S. natural gas
  prices spiked in February 2021, then generally increased through October",
  Today in Energy, 2022-01-06, URL
  https://www.eia.gov/todayinenergy/detail.php?id=50778.
- Supplemental citation: U.S. Energy Information Administration, "February
  2021 weather triggers largest monthly decline in U.S. natural gas
  production", Today in Energy, 2021-05-10, URL
  https://www.eia.gov/todayinenergy/detail.php?id=47896.
- Supplemental citation: U.S. Energy Information Administration, "Cold weather
  brings near record-high natural gas spot prices", Today in Energy,
  2021-03-05, URL https://www.eia.gov/todayinenergy/detail.php?id=47016.

## Concept

EIA documents that severe winter weather can create abrupt natural-gas price
spikes through heating demand, production interruptions, and regional market
constraints. This card tests the continuation side of that structure: during
January-February, buy `XNGUSD.DWX` only after the CFD itself confirms an upside
shock with a close-through D1 channel breakout, a positive ATR-scaled impulse,
and a strong close location.

Runtime data stays Darwinex MT5 OHLC only. The EA does not read weather,
production, storage, pipeline-flow, cash-market, futures-curve, EIA, CSV, API,
analyst forecast, or ML data at runtime.

This is intentionally not a duplicate of `QM5_12602_eia-xng-frzfade`,
`QM5_12586_eia-xng-winter-brk`, `QM5_12817_xng-volshock-fade`, or
`QM5_12567_cum-rsi2-commodity`.

## Markets And Timeframe

- Symbol: `XNGUSD.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, broker calendar, broker spread, SMA, ATR,
  and Donchian-style channel state only.

## Entry Rules

- Evaluate only on a new D1 bar.
- Trade only when the prior closed D1 bar is in January or February.
- Long only.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if the current spread exceeds `strategy_max_spread_points`.
- Require the signal-bar close to be above the previous channel high and above
  SMA(`strategy_trend_period`).
- Require signal-bar range to be at least `strategy_min_range_atr * ATR`.
- Require close-to-close impulse to be at least
  `strategy_min_impulse_atr * ATR`.
- Require close location within the bar to be at least
  `strategy_min_close_location` and upper wick ratio to be no more than
  `strategy_max_upper_wick_ratio`.
- Entry: BUY `XNGUSD.DWX` at market with a hard ATR stop.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit when the broker date leaves January-February.
- Exit when prior closed D1 close returns to or below SMA
  (`strategy_trend_period`).
- Exit when prior closed D1 close breaks below the lowest low of the previous
  `strategy_exit_channel` completed D1 bars excluding the signal bar.
- Exit when the position has been held for more than
  `strategy_max_hold_days`.
- Friday close remains enabled by the V5 framework.

## Parameters To Test

- name: strategy_entry_channel
  default: 12
  sweep_range: [8, 12, 20]
- name: strategy_exit_channel
  default: 8
  sweep_range: [5, 8, 12]
- name: strategy_trend_period
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.90
  sweep_range: [0.75, 0.90, 1.10]
- name: strategy_min_impulse_atr
  default: 0.55
  sweep_range: [0.40, 0.55, 0.75]
- name: strategy_min_close_location
  default: 0.62
  sweep_range: [0.55, 0.62, 0.70]
- name: strategy_max_upper_wick_ratio
  default: 0.35
  sweep_range: [0.25, 0.35, 0.45]
- name: strategy_atr_sl_mult
  default: 3.25
  sweep_range: [2.5, 3.25, 4.0]
- name: strategy_max_hold_days
  default: 10
  sweep_range: [6, 10, 14]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Strategy Allowability Check

- [x] R1 official source: EIA winter natural-gas price shock material.
- [x] R2 mechanical: fixed January-February window, D1 channel breakout,
  ATR/SMA/close-location shock filters, ATR stop, deterministic exits.
- [x] R3 testable: `XNGUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.

## Framework Alignment

- no_trade: D1/`XNGUSD.DWX` guard, January-February entry gate, spread cap,
  parameter sanity.
- trade_entry: long-only winter freeze-off upside shock/channel breakout after
  ATR impulse confirmation.
- trade_management: close on winter-window end, SMA failure, channel failure,
  or max-hold timeout.
- trade_close: hard ATR stop plus framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-30 | initial structural XNG winter freeze-off continuation breakout card | G0 | APPROVED |
| v1-q02 | 2026-07-01 | strict compile/build_check PASS; Q02 paced-fleet enqueue | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | this card |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | work_items/7e315613-2db7-4b3f-be9d-99ce53bdcfbc |
