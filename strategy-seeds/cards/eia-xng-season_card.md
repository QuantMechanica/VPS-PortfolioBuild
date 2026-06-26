---
ea_id: QM5_12575
slug: eia-xng-season
type: strategy
source_id: 706222b7-2d60-5fdb-8dab-d722d3c96f92
source_citation: "U.S. Energy Information Administration. (2015). Natural gas consumption, production respond to seasonal changes. Today in Energy, 2015-09-24. URL https://www.eia.gov/todayinenergy/detail.php?id=22892"
sources:
  - "[[sources/706222b7-2d60-5fdb-8dab-d722d3c96f92]]"
concepts:
  - "[[concepts/natural-gas-seasonality]]"
  - "[[concepts/calendar-trend-filter]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
target_symbols: [XNGUSD.DWX]
period: D1
expected_trade_frequency: "Monthly seasonal rebalance on XNGUSD.DWX with active windows in 10 calendar months and a 63-day price confirmation filter; estimate 4-8 trades/year/symbol."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS single official EIA source; R2 PASS deterministic monthly XNG calendar/SMA/ATR rules; R3 PASS XNGUSD.DWX testable; R4 PASS no ML/grid/martingale and one magic position."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# EIA XNG Seasonal Demand Trend

## Source

- Source: [[sources/706222b7-2d60-5fdb-8dab-d722d3c96f92]]
- Citation: U.S. Energy Information Administration, "Natural gas consumption, production respond to seasonal changes", Today in Energy, 2015-09-24, URL https://www.eia.gov/todayinenergy/detail.php?id=22892.
- Source location: the EIA article describes natural gas consumption as seasonal, with winter heating demand and summer electric-sector demand creating distinct demand peaks.

## Concept

Natural gas has a structural calendar component because heating demand is concentrated in winter and power-generation demand rises in hot summer periods. This card converts that fundamental seasonality into a low-frequency XNGUSD.DWX sleeve: trade only at monthly D1 rebalances, require price confirmation, and stay flat in ambiguous transition months.

This is deliberately different from `QM5_12567_cum-rsi2-commodity`, which is a short-horizon cumulative RSI pullback port. This card uses calendar regime plus slow price confirmation only.

## Markets And Timeframe

- Target symbol: XNGUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no EIA feed, storage report, external API, or discretionary override.

## Entry Rules

- Evaluate only on the first new D1 bar of a calendar month.
- Long season months: November, December, January, February, July, August.
- Short season months: April, May, September, October.
- Neutral months: March and June.
- Compute the prior closed D1 close and SMA(63) on XNGUSD.DWX.
- Entry Long: if the new month is a long season month and the prior D1 close is above SMA(63), BUY XNGUSD.DWX at market.
- Entry Short: if the new month is a short season month and the prior D1 close is below SMA(63), SELL XNGUSD.DWX at market.
- No entry in neutral months.
- No entry if an open position already exists for the EA magic.

## Exit Rules

- Stop loss: fixed hard SL at ATR(20) * 3.0 from entry.
- Exit Long if the active month is no longer long-season eligible.
- Exit Short if the active month is no longer short-season eligible.
- Exit Long if the prior D1 close falls below SMA(63).
- Exit Short if the prior D1 close rises above SMA(63).
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XNGUSD.DWX on D1.
- Skip entries when current spread exceeds 800 points.
- Skip entries when ATR(20) or SMA(63) is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1; the card uses the hard ATR stop and daily/monthly close rules.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_trend_period
  default: 63
  sweep_range: [42, 63, 84, 126]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0, 5.0]
- name: strategy_max_spread_points
  default: 800
  sweep_range: [500, 800, 1200]

## Author Claims

No performance claim is taken from the EIA source. The source is used only for structural seasonality lineage.

## Initial Risk Profile

- expected_pf: 1.20
- expected_dd_pct: 18
- expected_trade_frequency: approximately 6 trades/year/symbol.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 single source: one EIA URL and one `source_id`.
- [x] R2 mechanical: fixed calendar windows, SMA confirmation, ATR stop, and deterministic exits.
- [x] R3 testable: XNGUSD.DWX is a DWX commodity CFD used elsewhere in the pipeline.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] No duplicate of QM5_12567: this is not RSI pullback logic.

## Framework Alignment

- no_trade: D1 and XNGUSD.DWX guard, spread cap.
- trade_entry: monthly seasonal direction plus SMA(63) confirmation.
- trade_management: none beyond the entry stop.
- trade_close: season-window end or SMA confirmation failure.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-26 | initial structural XNG sleeve build | G0 | DRAFT |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | DRAFT | this card |
