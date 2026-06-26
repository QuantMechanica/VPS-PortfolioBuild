---
ea_id: QM5_12592
slug: eia-wti-prewpsr
type: strategy
source_id: EIA-WTI-WPSR-PRE-2026
source_citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report and release schedule. URLs https://www.eia.gov/petroleum/supply/weekly/ and https://www.eia.gov/petroleum/supply/weekly/schedule.php"
sources:
  - "[[sources/EIA-WTI-WPSR-PRE-2026]]"
concepts:
  - "[[concepts/crude-oil-inventory-event]]"
  - "[[concepts/pre-event-positioning]]"
  - "[[concepts/volatility-compression]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
target_symbols: [XTIUSD.DWX]
logical_symbol: QM5_12592_XTI_PREWPSR_D1
period: D1
expected_trade_frequency: "Weekly WTI pre-WPSR trend/compression setup; estimate 8-16 trades/year after D1 compression and trend filters."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS official EIA WPSR/release schedule; R2 PASS deterministic D1 pre-event calendar, compression, trend, ATR stop, and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.12
expected_dd_pct: 18.0
---

# EIA WTI Pre-WPSR Positioning

## Source

- Source: [[sources/EIA-WTI-WPSR-PRE-2026]]
- Primary citation: U.S. Energy Information Administration, "Weekly Petroleum Status Report", URL https://www.eia.gov/petroleum/supply/weekly/.
- Release schedule citation: U.S. Energy Information Administration, "Weekly Petroleum Status Report Schedule", URL https://www.eia.gov/petroleum/supply/weekly/schedule.php.
- Structural supplement: U.S. Energy Information Administration, "Oil and petroleum products explained", URL https://www.eia.gov/energyexplained/oil-and-petroleum-products/.

## Concept

The EIA Weekly Petroleum Status Report is a recurring official information
event for crude oil. This card does not forecast the report and does not ingest
inventory data. It targets the pre-event risk window: enter XTIUSD.DWX at the
start of an expected WPSR D1 bar only when recent D1 ranges are compressed and
the prior close confirms a directional trend, then exit shortly after the
scheduled report window has passed.

This is deliberately different from:

- `QM5_12579_eia-wti-aftershock`: follows the closed WPSR event-day reaction.
- `QM5_12590_eia-wti-wpsr-fade`: fades an already stretched closed WPSR event-day reaction.
- `QM5_12576_eia-wti-season`: monthly petroleum-demand seasonality.
- `QM5_12581_eia-rbob-crack`, `QM5_12585_eia-rbob-pullback`, and `QM5_12589_eia-rbob-shoulder`: gasoline-season/refinery-margin windows.
- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI-style commodity pullback.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Expected trade frequency: 12 trades/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no EIA feed, inventory surprise feed,
  analyst forecast, CSV, futures curve, API, or discretionary input.

## Entry Rules

- Evaluate only on a new D1 bar.
- The current broker-calendar D1 bar must be Wednesday or Thursday. Wednesday
  is the standard WPSR day; Thursday is allowed for holiday-shifted releases.
- Compute prior closed D1 bars only.
- Compression gate: the average high-low range over
  `strategy_compression_lookback` prior completed D1 bars must be less than or
  equal to ATR(`strategy_atr_period`) times `strategy_compression_atr_mult`.
- Long setup: prior D1 close is above SMA(`strategy_trend_period`) and above
  the close `strategy_momentum_period` bars earlier.
- Short setup: prior D1 close is below SMA(`strategy_trend_period`) and below
  the close `strategy_momentum_period` bars earlier.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit after `strategy_max_hold_days` calendar days.
- Exit long if the prior D1 close falls below SMA(`strategy_trend_period`).
- Exit short if the prior D1 close rises above SMA(`strategy_trend_period`).
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XTIUSD.DWX on D1.
- Skip entries when ATR, SMA, or compression/momentum history is unavailable.
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
- name: strategy_momentum_period
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_compression_lookback
  default: 3
  sweep_range: [2, 3, 5]
- name: strategy_compression_atr_mult
  default: 0.90
  sweep_range: [0.75, 0.90, 1.05]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.0, 2.75, 3.5]
- name: strategy_max_hold_days
  default: 2
  sweep_range: [1, 2, 3]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from EIA. EIA is used only as official structural
lineage for the weekly petroleum information-event schedule. The edge claim is
tested by the QM Q02+ pipeline on Darwinex XTIUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 18
- expected_trade_frequency: approximately 8-16 trades/year on D1.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA WPSR and release schedule URLs.
- [x] R2 mechanical: fixed pre-event weekday gate, D1 compression/trend filters, ATR stop, SMA failure exit, and max-hold exit.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] No duplicate of `QM5_12579` or `QM5_12590`: this trades before the event day reaction is known.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, parameter guard, spread cap.
- trade_entry: current pre-WPSR D1 day plus prior-bar compression and trend/momentum confirmation.
- trade_management: SMA failure and fixed max-hold exits.
- trade_close: framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural WTI pre-WPSR positioning build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
