---
ea_id: QM5_12725
slug: eia-xng-prestor
type: strategy
source_id: EIA-XNG-PRESTORAGE-2026
source_citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report and release schedule. URLs https://www.eia.gov/naturalgas/storage/ and https://www.eia.gov/naturalgas/schedule/"
sources:
  - "[[sources/EIA-XNG-PRESTORAGE-2026]]"
concepts:
  - "[[concepts/natural-gas-storage]]"
  - "[[concepts/pre-event-positioning]]"
  - "[[concepts/volatility-compression]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
  - "[[indicators/rate-of-change]]"
strategy_type_flags: [calendar-seasonality, pre-event-positioning, vol-regime-gate, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12725_XNG_PRESTOR_D1
period: D1
expected_trade_frequency: "Weekly natural-gas pre-storage compression setup on D1 bars; estimate 10-22 trades/year after compression, trend, spread, news, and one-position filters."
expected_trades_per_year_per_symbol: 16
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS official EIA weekly natural-gas storage report and release schedule; R2 PASS deterministic D1 pre-storage weekday, compression, trend/momentum, ATR stop, and time/SMA exits; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.12
expected_dd_pct: 22.0
---

# EIA XNG Pre-Storage Compression Trend

## Source

- Source: [[sources/EIA-XNG-PRESTORAGE-2026]]
- Primary citation: U.S. Energy Information Administration, "Weekly Natural Gas Storage Report", URL https://www.eia.gov/naturalgas/storage/.
- Release schedule citation: U.S. Energy Information Administration, "Natural Gas Weekly Update and Storage Report Schedule", URL https://www.eia.gov/naturalgas/schedule/.
- Structural supplement: U.S. Energy Information Administration, "Natural gas explained", URL https://www.eia.gov/energyexplained/natural-gas/.

## Concept

The EIA Weekly Natural Gas Storage Report is a recurring official information event for natural gas. This card does not forecast storage, import storage data, or read a release feed at runtime. It targets the pre-event risk window: when recent XNGUSD.DWX D1 ranges are compressed and the prior close confirms a directional trend, enter on the expected storage-report D1 bar and exit quickly after the event window.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI pullback logic and no broad commodity fanout.
- `QM5_12575_eia-xng-season`: not a monthly winter/summer/shoulder season map.
- `QM5_12584_eia-xng-storage`: this trades before the storage report bar develops; it does not follow an already-closed event-day aftershock.
- `QM5_12586`, `QM5_12587`, and `QM5_12588`: not winter/injection/summer seasonal channel breakout logic.
- `QM5_12595` and `QM5_12602`: not a failed-rally or winter spike fade.
- `QM5_12620_comm-reversal-4wk-xngusd`: not a fixed 20-D1-bar return-extreme reversal.

## Markets And Timeframe

- Symbol: XNGUSD.DWX.
- Period: D1.
- Expected trade frequency: about 10-22 trades/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no EIA feed, storage level, analyst forecast, weather feed, futures curve, CSV, API, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- The current broker-calendar D1 bar must be Wednesday, Thursday, or Friday. Thursday is the standard EIA storage-report day; Wednesday and Friday tolerate holiday-shifted releases without importing a schedule file.
- Compute prior completed D1 bars only.
- Compression gate: the average high-low range over `strategy_compression_lookback` prior completed D1 bars must be less than or equal to ATR(`strategy_atr_period`) times `strategy_compression_atr_mult`.
- Long setup: prior D1 close is above SMA(`strategy_trend_period`) and above the close `strategy_momentum_period` bars earlier.
- Short setup: prior D1 close is below SMA(`strategy_trend_period`) and below the close `strategy_momentum_period` bars earlier.
- No entry if an open XNGUSD.DWX position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit after `strategy_max_hold_days` calendar days.
- Exit long if the prior D1 close falls below SMA(`strategy_trend_period`).
- Exit short if the prior D1 close rises above SMA(`strategy_trend_period`).
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XNGUSD.DWX on D1.
- Skip entries when ATR, SMA, compression, or momentum history is unavailable.
- Framework news, kill-switch, magic, spread, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short.
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
- name: strategy_trend_period
  default: 63
  sweep_range: [40, 63, 84]
- name: strategy_momentum_period
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_compression_lookback
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_compression_atr_mult
  default: 0.85
  sweep_range: [0.70, 0.85, 1.00]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.25, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 2
  sweep_range: [1, 2, 3]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported from EIA. The source is used only for official structural lineage: the weekly storage report is a scheduled natural-gas information event, and the QM Q02+ pipeline tests whether a mechanical pre-event compression/trend port works on Darwinex XNGUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 22
- expected_trade_frequency: approximately 10-22 trades/year.
- risk_class: high for natural-gas volatility and event-gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA weekly storage report and release schedule.
- [x] R2 mechanical: fixed event weekday gate, D1 compression/trend/momentum filters, ATR stop, SMA failure exit, and max-hold exit.
- [x] R3 testable: XNGUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: pre-storage compression positioning is not RSI2 pullback, broad XNG seasonality, post-storage aftershock, seasonal breakout, shoulder fade, freeze fade, or 4-week return reversal.

## Framework Alignment

- no_trade: D1 and XNGUSD.DWX guard, parameter guard, spread cap.
- trade_entry: current expected storage-report D1 bar plus prior-bar compression and trend/momentum confirmation.
- trade_management: SMA failure and fixed max-hold exits.
- trade_close: hard ATR stop plus deterministic time exits and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural XNG pre-storage compression build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
