---
ea_id: QM5_12593
slug: eia-wti-ref-fade
type: strategy
source_id: EIA-WTI-REFINERY-MAINT-2026
source_citation: "U.S. Energy Information Administration. Refinery outages: planned and unplanned outages, 2007-2011. URL https://www.eia.gov/petroleum/articles/refoutagesindex.php"
sources:
  - "[[sources/EIA-WTI-REFINERY-MAINT-2026]]"
concepts:
  - "[[concepts/refinery-turnaround-season]]"
  - "[[concepts/shoulder-month-mean-reversion]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
target_symbols: [XTIUSD.DWX]
logical_symbol: QM5_12593_XTI_REFINERY_FADE_D1
period: D1
expected_trade_frequency: "Spring/autumn refinery-turnaround stretch rejection fade; estimate 6-12 trades/year on XTIUSD.DWX D1 after range/body/stretch filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS official EIA refinery outage/utilization lineage; R2 PASS deterministic D1 calendar-window stretch rejection fade; R3 PASS XTIUSD.DWX; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 20.0
---

# EIA WTI Refinery Turnaround Fade

## Source

- Source: [[sources/EIA-WTI-REFINERY-MAINT-2026]]
- Primary citation: U.S. Energy Information Administration, "Refinery outages:
  planned and unplanned outages, 2007-2011", URL
  https://www.eia.gov/petroleum/articles/refoutagesindex.php.
- Structural supplement: U.S. Energy Information Administration, "U.S. refinery
  utilization rates slightly higher than last year heading into summer", URL
  https://www.eia.gov/todayinenergy/detail.php?id=61543.

## Concept

WTI often trades through refinery-turnaround shoulder periods where planned
maintenance, changing crude runs, and product-season transitions can create
short-lived overshoots rather than clean sustained trends. This card does not
forecast refinery outages or ingest EIA data. It uses only the market's D1
reaction during fixed shoulder windows: fade a stretched bar that closes back
against the direction of the stretch, then exit at the slow mean or by time.

This is deliberately different from:

- `QM5_12576_eia-wti-season`: broad monthly WTI seasonality.
- `QM5_12579_eia-wti-aftershock`: follows WPSR reaction bars.
- `QM5_12590_eia-wti-wpsr-fade`: fades weekly WPSR event-day exhaustion.
- `QM5_12591_eia-wti-hurr-brk`: hurricane-season upside breakout.
- `QM5_12592_eia-wti-prewpsr`: pre-WPSR compression positioning.
- `QM5_12589_eia-rbob-shoulder`: autumn gasoline crack failed-rally short.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: 8 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC only; no EIA feed, refinery data, product
  spread feed, futures curve, API, CSV, or external input.

## Entry Rules

- Evaluate only on a new D1 bar.
- The prior closed D1 bar must fall in the spring shoulder window
  March-April or autumn shoulder window September-October.
- Compute prior D1 open, high, low, close, ATR(`strategy_atr_period`), and
  SMA(`strategy_mean_period`).
- Prior-bar range must be at least `strategy_min_range_atr` times ATR.
- Prior-bar body size must be at least `strategy_min_body_ratio` of total range.
- Stretch from SMA must be at least `strategy_min_stretch_atr` times ATR.
- Short fade: prior close is above SMA, the bar has a negative body, and the
  close is in the lower `strategy_reversal_tail_ratio` of its range.
- Long fade: prior close is below SMA, the bar has a positive body, and the
  close is in the upper `strategy_reversal_tail_ratio` of its range.
- No entry if an open position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close a long when the prior D1 close reaches or exceeds SMA(`strategy_mean_period`).
- Close a short when the prior D1 close reaches or falls below SMA(`strategy_mean_period`).
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Skip entries when ATR/SMA/OHLC are unavailable.
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
  default: 0.80
  sweep_range: [0.60, 0.80, 1.10]
- name: strategy_min_body_ratio
  default: 0.35
  sweep_range: [0.25, 0.35, 0.50]
- name: strategy_reversal_tail_ratio
  default: 0.35
  sweep_range: [0.25, 0.35, 0.45]
- name: strategy_min_stretch_atr
  default: 0.90
  sweep_range: [0.70, 0.90, 1.20]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.0, 2.75, 3.5]
- name: strategy_max_hold_days
  default: 6
  sweep_range: [3, 6, 9]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from EIA. EIA is used only as official structural
lineage for refinery maintenance and utilization seasonality. The edge claim is
tested by the QM Q02+ pipeline on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 20
- expected_trade_frequency: approximately 6-12 trades/year on D1.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA refinery outage and utilization URLs.
- [x] R2 mechanical: fixed calendar windows, D1 stretch rejection, ATR stop,
  SMA mean-reversion exit, and max-hold exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Not a duplicate of the existing WTI WPSR, hurricane, broad seasonality, or
  product-spread cards.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, parameter guard, spread cap.
- trade_entry: spring/autumn D1 stretch rejection fade.
- trade_management: SMA mean-reversion and fixed max-hold exits.
- trade_close: framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural WTI refinery-turnaround fade build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
