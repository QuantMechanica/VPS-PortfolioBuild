---
ea_id: QM5_12590
slug: eia-wti-wpsr-fade
type: strategy
source_id: EIA-WTI-WPSR-FADE-2026
source_citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report and release schedule. URLs https://www.eia.gov/petroleum/supply/weekly/ and https://www.eia.gov/petroleum/supply/weekly/schedule.php"
sources:
  - "[[sources/EIA-WTI-WPSR-FADE-2026]]"
concepts:
  - "[[concepts/crude-oil-inventory-event]]"
  - "[[concepts/post-event-exhaustion-fade]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
target_symbols: [XTIUSD.DWX]
logical_symbol: QM5_12590_XTI_WPSR_FADE_D1
period: D1
expected_trade_frequency: "Weekly WTI post-WPSR exhaustion fade; estimate 6-14 trades/year on D1 after event-day range/body/stretch filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS official EIA WPSR/release schedule; R2 PASS deterministic D1 post-event exhaustion fade; R3 PASS XTIUSD.DWX; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.12
expected_dd_pct: 18.0
---

# EIA WTI Weekly Inventory Exhaustion Fade

## Source

- Source: [[sources/EIA-WTI-WPSR-FADE-2026]]
- Primary citation: U.S. Energy Information Administration, "Weekly Petroleum Status Report", URL https://www.eia.gov/petroleum/supply/weekly/.
- Release schedule citation: U.S. Energy Information Administration, "Weekly Petroleum Status Report Schedule", URL https://www.eia.gov/petroleum/supply/weekly/schedule.php.
- Structural supplement: U.S. Energy Information Administration, "Oil and petroleum products explained", URL https://www.eia.gov/energyexplained/oil-and-petroleum-products/.

## Concept

Crude oil has a recurring official weekly information event: the EIA Weekly
Petroleum Status Report. This card does not forecast the inventory number or
ingest EIA data. It waits for the market's own D1 reaction to the scheduled
event. When that event-day bar is unusually wide, directional, closes in the
outer part of its range, and is stretched away from a slow D1 mean, the EA fades
the move for a short mean-reversion window.

This is deliberately different from:

- `QM5_12579_eia-wti-aftershock`: follows the event-day direction after a large WPSR reaction.
- `QM5_12576_eia-wti-season`: monthly petroleum-demand seasonality.
- `QM5_12585_eia-rbob-pullback`: March-August gasoline-season pullback continuation.
- `QM5_12589_eia-rbob-shoulder`: autumn gasoline shoulder failed-rally short.
- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI-style commodity pullback.

## Markets And Timeframe

- Target symbol: XTIUSD.DWX.
- Period: D1.
- Expected trade frequency: 10 trades/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no EIA feed, inventory surprise feed,
  futures curve, analyst forecast, CSV, or external API.

## Entry Rules

- Evaluate only on a new D1 bar.
- Treat the prior closed D1 bar as eligible only if its broker calendar day is
  Wednesday or Thursday. Thursday is allowed for holiday-shifted WPSR releases.
- Compute prior D1 open, high, low, close, ATR(`strategy_atr_period`), and
  SMA(`strategy_mean_period`).
- Event-day range must be at least `strategy_min_range_atr` times ATR.
- Event-day body size must be at least `strategy_min_body_ratio` of total range.
- Event-day close must be in the outer `strategy_close_tail_ratio` of the bar:
  top tail for bearish fade, bottom tail for bullish fade.
- Stretch from SMA must be at least `strategy_min_stretch_atr` times ATR.
- Short fade: event-day body is positive, close is above SMA by the stretch gate,
  and close location is in the upper tail.
- Long fade: event-day body is negative, close is below SMA by the stretch gate,
  and close location is in the lower tail.
- No entry if an open position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close a long when the prior D1 close reaches or exceeds SMA(`strategy_mean_period`).
- Close a short when the prior D1 close reaches or falls below SMA(`strategy_mean_period`).
- Close after `strategy_max_hold_days` calendar days.
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
- name: strategy_mean_period
  default: 50
  sweep_range: [34, 50, 84]
- name: strategy_min_range_atr
  default: 1.25
  sweep_range: [1.0, 1.25, 1.5, 1.75]
- name: strategy_min_body_ratio
  default: 0.45
  sweep_range: [0.35, 0.45, 0.6]
- name: strategy_close_tail_ratio
  default: 0.20
  sweep_range: [0.15, 0.20, 0.30]
- name: strategy_min_stretch_atr
  default: 0.75
  sweep_range: [0.50, 0.75, 1.00]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.0, 2.75, 3.5]
- name: strategy_max_hold_days
  default: 4
  sweep_range: [2, 4, 6]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from EIA. EIA is used only as official structural
lineage for the weekly petroleum information event. The edge claim is tested by
the QM Q02+ pipeline on Darwinex XTIUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 18
- expected_trade_frequency: approximately 6-14 trades/year on D1.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA WPSR and schedule URLs.
- [x] R2 mechanical: fixed calendar gate, D1 event-day exhaustion, ATR stop, SMA mean-reversion exit, and max-hold exit.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] No duplicate of `QM5_12579`: this fades stretched WPSR bars instead of following them.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, parameter guard, spread cap.
- trade_entry: prior D1 WPSR-day range/body/tail/stretch fade.
- trade_management: SMA mean-reversion and fixed max-hold exits.
- trade_close: framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-26 | initial structural WTI WPSR exhaustion-fade build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | APPROVED | this card |
