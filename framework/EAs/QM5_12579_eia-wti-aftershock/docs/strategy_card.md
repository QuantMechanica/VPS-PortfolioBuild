---
ea_id: QM5_12579
slug: eia-wti-aftershock
type: strategy
source_id: EIA-WTI-WPSR-AFTERSHOCK-2026
source_citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report and release schedule. URLs https://www.eia.gov/petroleum/supply/weekly/ and https://www.eia.gov/petroleum/supply/weekly/schedule.php"
sources:
  - "[[sources/EIA-WTI-WPSR-AFTERSHOCK-2026]]"
concepts:
  - "[[concepts/crude-oil-inventory-event]]"
  - "[[concepts/post-event-price-reaction]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
target_symbols: [XTIUSD.DWX]
period: D1
expected_trade_frequency: "Weekly WTI post-inventory aftershock gate; estimate 8-20 D1 trades/year after range/body filters."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS official EIA WPSR/release schedule; R2 PASS deterministic D1 post-event range/body/SMA reaction; R3 PASS XTIUSD.DWX matrix-valid; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.15
expected_dd_pct: 18.0
---

# EIA WTI Weekly Inventory Aftershock

## Source

- Source: [[sources/EIA-WTI-WPSR-AFTERSHOCK-2026]]
- Primary citation: U.S. Energy Information Administration, "Weekly Petroleum Status Report", URL https://www.eia.gov/petroleum/supply/weekly/.
- Release schedule citation: U.S. Energy Information Administration, "Weekly Petroleum Status Report Schedule", URL https://www.eia.gov/petroleum/supply/weekly/schedule.php.
- Structural supplement: U.S. Energy Information Administration, "Oil and petroleum products explained", URL https://www.eia.gov/energyexplained/oil-and-petroleum-products/.

## Concept

Crude oil has a recurring official weekly information event: the EIA Weekly
Petroleum Status Report. This card does not forecast the inventory number or
ingest EIA data. It waits for the market's own D1 reaction to the scheduled
event. When the event day expands versus normal range and closes directionally,
the EA follows that direction for a short fixed D1 aftershock window.

This is deliberately different from `QM5_1121_unger-crude-inventory-release`,
which is an M5 release-window stop-straddle around the announcement. This card
does not place intraday bracket orders and never trades before the release-day
D1 bar has closed. It is also different from `QM5_12576_eia-wti-season`, which
is a monthly petroleum-demand seasonal sleeve.

## Markets And Timeframe

- Target symbol: XTIUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no EIA feed, inventory surprise feed,
  futures curve, analyst forecast, CSV, or external API.

## Entry Rules

- Evaluate only on a new D1 bar.
- Treat the prior closed D1 bar as eligible only if its broker calendar day is
  Wednesday or Thursday. Thursday is allowed for holiday-shifted WPSR releases.
- Compute prior D1 open, high, low, close, ATR(20), and SMA(50).
- Event-day range must be at least `strategy_min_range_atr` times ATR(20).
- Event-day body size must be at least `strategy_min_body_ratio` of total range.
- Long entry: event-day close is above open and above SMA(50).
- Short entry: event-day close is below open and below SMA(50).
- No entry if an open position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(20) * `strategy_atr_sl_mult`.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XTIUSD.DWX on D1.
- Skip entries when ATR/SMA/event-day OHLC are unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_trend_period
  default: 50
  sweep_range: [34, 50, 84]
- name: strategy_min_range_atr
  default: 1.15
  sweep_range: [1.0, 1.15, 1.35, 1.6]
- name: strategy_min_body_ratio
  default: 0.35
  sweep_range: [0.25, 0.35, 0.5]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0, 3.5]
- name: strategy_max_hold_days
  default: 3
  sweep_range: [2, 3, 5]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from EIA. EIA is used only as official structural
lineage for the weekly petroleum information event. The edge claim is tested by
the QM Q02+ pipeline on Darwinex XTIUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.15
- expected_dd_pct: 18
- expected_trade_frequency: approximately 8-20 trades/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA WPSR and schedule URLs.
- [x] R2 mechanical: fixed calendar gate, D1 event-day reaction, ATR stop, and max-hold exit.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] No duplicate of QM5_1121: D1 post-event reaction, not M5 release straddle.
- [x] No duplicate of QM5_12576: weekly information-event aftershock, not monthly seasonality.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, parameter guard, spread cap.
- trade_entry: prior D1 WPSR-day range/body reaction plus SMA confirmation.
- trade_management: none beyond hard stop.
- trade_close: fixed calendar-day max hold plus framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-26 | initial structural WTI WPSR aftershock build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | APPROVED | this card |
