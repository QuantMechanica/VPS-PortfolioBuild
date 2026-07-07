---
ea_id: QM5_12872
slug: eia-xng-stor-drift
type: strategy
strategy_id: EIA-XNG-STOR-DRIFT-2026
source_id: EIA-XNG-STOR-DRIFT-2026
source_citation: "U.S. Energy Information Administration Weekly Natural Gas Storage Report and natural gas storage season definitions."
source_citations:
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report."
    location: https://www.eia.gov/naturalgas/storage/
    quality_tier: A
    role: primary
  - type: official_release_schedule
    citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report Schedule."
    location: https://ir.eia.gov/ngs/schedule.html
    quality_tier: A
    role: release_timing
  - type: official_energy_context
    citation: "U.S. Energy Information Administration. Injection season forecast for natural gas storage."
    location: https://www.eia.gov/todayinenergy/detail.php?id=1310
    quality_tier: A
    role: seasonal_context
strategy_type_flags: [official-release-window, natural-gas-storage, seasonal-storage-cycle, drift-continuation, atr-hard-stop, sma-trend-exit, time-stop, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_12872_XNG_STOR_DRIFT_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Storage-report drift continuation, max one signal per broker-calendar month; estimate 5-9 entries/year before Q02."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.05
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [official-release-window, storage-season-filter, closed-bar-drift, atr-risk, sma-trend-exit, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-entry, trade-management, news-gate, friday-close, setfile-risk]
---

# EIA XNG Storage Drift

## Hypothesis

EIA's weekly natural gas storage process is a structural supply-demand anchor
for `XNGUSD.DWX`. The report is normally released on Thursday morning U.S.
Eastern time, and EIA documentation separates the storage year into withdrawal
and injection seasons. This card does not import EIA values, analyst
expectations, weather, futures curves, CSV files, APIs, or web data at runtime.
It uses the official report cadence and storage-season structure only as
lineage, then trades deterministic Darwinex D1 price confirmation.

The mechanical edge is a low-frequency continuation proxy: if the market has
already drifted in the direction consistent with the current storage season on
a report-window D1 bar, and the close confirms a trend-side displacement from
a medium D1 mean, follow the drift for a short holding window. Only one signal
is consumed per broker-calendar month.

## Non-Duplicate Boundary

This is not `QM5_12567_cum-rsi2-commodity`; it uses no RSI, no cumulative RSI,
and no generic commodity oscillator logic. It is not `QM5_12584_eia-xng-storage`
storage aftershock, which follows any large report-window bar for a short fixed
window. It is not `QM5_12744_eia-xng-storfade`, which fades an exhausted
storage bar toward a mean. It is not `QM5_12761_eia-xng-stor-idbrk`, which
waits for an inside-bar range break after the event. It is not XNG COT,
production, rig-count, hurricane, freeze, LNG, Tuesday/Thursday, month-ORB,
12-month carry, 52-week anchor, oil/gas, gas/metal, or index-beta logic.

The edge is narrower: a seasonal withdrawal/injection storage-drift
continuation, gated to EIA report-window D1 bars and max one entry per month.

## Market and Timeframe

- Host symbol: `XNGUSD.DWX`.
- Timeframe: D1 only.
- Magic slot: 0.
- Direction: long in withdrawal season, short in injection shoulder months.
- Runtime data: native MT5 OHLC, spread, ATR/SMA helpers, and broker calendar.

## Entry Rules

Evaluate once per new D1 bar, using the prior completed D1 bar as the signal
bar.

1. Signal bar day-of-week must be Wednesday, Thursday, or Friday in broker
   time to proxy the EIA storage release window and holiday shifts.
2. Withdrawal-season long window is November through March.
3. Injection-shoulder short window is April, May, September, and October.
4. The signal bar must close in the seasonal direction, have sufficient body
   quality, and close in the relevant part of its range.
5. The multi-day drift ending on the signal bar must exceed the configured ATR
   threshold.
6. The signal close must sit on the trend side of the SMA anchor by the
   configured ATR distance.
7. Skip if an open position already exists, the broker-calendar month is
   already consumed, spread is too wide, the symbol/timeframe/slot is wrong, or
   any guardrail input is invalid.

## Exit Rules

- ATR hard stop is set at entry.
- Close on max-hold timeout.
- Close a long when the previous D1 close falls back below the SMA anchor.
- Close a short when the previous D1 close rises back above the SMA anchor.
- Framework news gate, Friday close, kill switch, and one-position-per-magic
  guardrails remain active.
- No pyramiding, grid, martingale, ML, or external runtime data.

## Parameters

| param | default | range | meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for drift and stop scaling |
| `strategy_trend_period` | 50 | 35-80 | D1 SMA trend anchor |
| `strategy_drift_lookback` | 3 | 2-5 | Completed D1 bars in the report-window drift |
| `strategy_min_drift_atr` | 0.95 | 0.60-1.40 | Minimum drift in ATR units |
| `strategy_min_body_ratio` | 0.25 | 0.15-0.45 | Minimum signal body/range ratio |
| `strategy_min_trend_stretch_atr` | 0.25 | 0.10-0.60 | Minimum close-to-SMA displacement |
| `strategy_high_close_location` | 0.62 | 0.55-0.75 | Minimum close location for long drift |
| `strategy_low_close_location` | 0.38 | 0.25-0.45 | Maximum close location for short drift |
| `strategy_atr_sl_mult` | 3.10 | 2.4-3.8 | ATR stop distance |
| `strategy_max_hold_days` | 6 | 3-9 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The build does not touch T_Live, AutoTrading, deploy
manifests, portfolio gates, or live setfiles.

## R1-R4 Verdict

- R1 PASS: official EIA WNGSR, official release schedule, and EIA storage
  season context.
- R2 PASS: deterministic D1 calendar, seasonal month, drift, SMA, ATR, spread,
  stop, and time-exit rules.
- R3 PASS: `XNGUSD.DWX` exists in the DWX symbol matrix.
- R4 PASS: no ML, no grid, no martingale, one position per magic/symbol, and
  no external runtime feed.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, slot guard, parameter guard, spread cap,
  report-window day, storage-season month, and one-signal-per-month gate.
- trade_entry: EIA storage-season drift continuation.
- trade_management: SMA trend-failure exit and max-hold exit.
- trade_close: ATR stop plus deterministic strategy exits and framework
  Friday close.

## Pipeline

G0 approved for Q02 on 2026-07-07 by mission-directed commodity/energy sleeve
criteria. Q02 must validate or reject the mechanical Darwinex realization.

## Evidence

- Build evidence: `artifacts/qm5_12872_build_result.json`.
- Q02 enqueue evidence: `artifacts/qm5_12872_q02_enqueue_20260707.json`.
