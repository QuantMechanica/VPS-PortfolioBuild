---
ea_id: QM5_12744
slug: eia-xng-storfade
type: strategy
source_id: EIA-XNG-STORAGE-FADE-2026
source_citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report and release schedule. URLs https://www.eia.gov/naturalgas/storage/ and https://www.eia.gov/naturalgas/schedule/"
sources:
  - "[[sources/EIA-XNG-STORAGE-FADE-2026]]"
concepts:
  - "[[concepts/natural-gas-storage]]"
  - "[[concepts/post-event-exhaustion-fade]]"
  - "[[concepts/energy-event-risk]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [storage-report, post-event-fade, mean-reversion, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly natural-gas storage-report exhaustion fade on D1 bars; estimate 6-14 trades/year after event-day range/body/tail/stretch filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS official EIA weekly natural-gas storage report and release schedule; R2 PASS deterministic D1 event-day exhaustion fade, ATR stop, SMA reversion exit, and max-hold exit; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 24.0
---

# EIA XNG Storage Exhaustion Fade

## Source

- Source: [[sources/EIA-XNG-STORAGE-FADE-2026]]
- Primary citation: U.S. Energy Information Administration, "Weekly Natural
  Gas Storage Report", URL https://www.eia.gov/naturalgas/storage/.
- Release schedule citation: U.S. Energy Information Administration, "Natural
  Gas Weekly Update and Storage Report Schedule", URL https://www.eia.gov/naturalgas/schedule/.
- Structural supplement: U.S. Energy Information Administration, "Natural gas
  explained", URL https://www.eia.gov/energyexplained/natural-gas/.

## Concept

The EIA Weekly Natural Gas Storage Report is a recurring official information
event for natural gas. This card does not forecast the report, import storage
data, or read a release feed at runtime. It waits for the market's own D1
reaction and fades only unusually wide, directional event-day bars that close
in an outer tail and are stretched away from a slow D1 mean.

This is deliberately different from:

- `QM5_12584_eia-xng-storage`: that EA follows storage-report aftershocks; this
  card fades stretched storage-report bars.
- `QM5_12725_eia-xng-prestor`: not pre-event positioning.
- `QM5_12575`, `QM5_12586`, `QM5_12587`, `QM5_12588`, `QM5_12595`, `QM5_12601`,
  and `QM5_12602`: not monthly/seasonal natural-gas weather or storage-season
  windows.
- `QM5_12620_comm-reversal-4wk-xngusd`: not a fixed 20-D1-bar commodity
  reversal.
- `QM5_12738_xng-weekend-gap`: not a Monday weekend-gap continuation rule.
- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or broad commodity
  pullback logic.

## Markets And Timeframe

- Symbol: `XNGUSD.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no storage level,
  consensus forecast, surprise feed, weather feed, futures curve, CSV, API, or
  discretionary input.

## Entry Rules

- Evaluate only on a new D1 bar.
- Inspect the prior completed D1 bar if its broker-time day is Wednesday,
  Thursday, or Friday. Thursday is the standard storage-report day; Wednesday
  and Friday tolerate holiday schedule shifts without importing a schedule file.
- Compute prior D1 open, high, low, close, ATR(`strategy_atr_period`), and
  SMA(`strategy_mean_period`).
- Event-day range must be at least `strategy_min_range_atr` times ATR.
- Event-day body size must be at least `strategy_min_body_ratio` of total range.
- Event-day close must be in the outer `strategy_close_tail_ratio` of the bar:
  top tail for bearish fade, bottom tail for bullish fade.
- Stretch from SMA must be at least `strategy_min_stretch_atr` times ATR.
- Short fade: event-day body is positive, close is above SMA by the stretch
  gate, and close location is in the upper tail.
- Long fade: event-day body is negative, close is below SMA by the stretch
  gate, and close location is in the lower tail.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close a long when the prior D1 close reaches or exceeds
  SMA(`strategy_mean_period`).
- Close a short when the prior D1 close reaches or falls below
  SMA(`strategy_mean_period`).
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when ATR, SMA, or event-day OHLC are unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short event-day fade.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_mean_period
  default: 40
  sweep_range: [34, 40, 63]
- name: strategy_min_range_atr
  default: 1.35
  sweep_range: [1.0, 1.35, 1.75]
- name: strategy_min_body_ratio
  default: 0.40
  sweep_range: [0.30, 0.40, 0.55]
- name: strategy_close_tail_ratio
  default: 0.20
  sweep_range: [0.15, 0.20, 0.30]
- name: strategy_min_stretch_atr
  default: 0.85
  sweep_range: [0.60, 0.85, 1.10]
- name: strategy_atr_sl_mult
  default: 3.25
  sweep_range: [2.5, 3.25, 4.0]
- name: strategy_max_hold_days
  default: 3
  sweep_range: [2, 3, 5]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported from EIA. The source is used only as official
structural lineage for the weekly natural-gas storage information event. Q02+
tests this deterministic storage-event fade on Darwinex `XNGUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 24
- expected_trade_frequency: approximately 6-14 trades/year.
- risk_class: high for natural-gas volatility and event-gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA weekly storage report and release schedule.
- [x] R2 mechanical: fixed event-day set, D1 range/body/tail/stretch filters,
  ATR stop, SMA mean-reversion exit, and max-hold exit.
- [x] R3 testable: `XNGUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: storage-report exhaustion fade is not RSI2 pullback,
  broad XNG seasonality, post-storage aftershock, pre-storage positioning,
  seasonal breakout, shoulder/freeze fade, weekend gap, or 4-week return
  reversal.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, event-day gate, parameter guard, spread cap.
- trade_entry: prior D1 storage-report range/body/tail/stretch fade.
- trade_management: SMA mean-reversion and max-hold exits.
- trade_close: hard ATR stop plus deterministic time exits and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-28 | initial structural XNG storage-report exhaustion-fade build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
