---
ea_id: QM5_12705
slug: xngusd-fall-storage-short
type: strategy
source_id: 706222b7-2d60-5fdb-8dab-d722d3c96f92
source_citation: "U.S. Energy Information Administration. (2015). Natural gas use features two seasonal peaks per year. Today in Energy, 2015-09-11. URL https://www.eia.gov/todayinenergy/detail.php?id=22892"
sources:
  - "[[sources/706222b7-2d60-5fdb-8dab-d722d3c96f92]]"
strategy_type_flags: [calendar-seasonality, seasonal-window, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Fall shoulder/storage-fill XNG sleeve on D1; weekly entry gate inside September-October after negative SMA confirmation; estimate 4-8 entries/year after framework filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS official EIA Today in Energy source; R2 PASS deterministic September-October XNG short-only calendar window with SMA confirmation, ATR stop, and time/season exits; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 18.0
---

# XNG Fall Storage Short

## Source

U.S. Energy Information Administration, "Natural gas use features two seasonal peaks per year", Today in Energy, 2015-09-11, URL https://www.eia.gov/todayinenergy/detail.php?id=22892.

## Concept

The EIA source describes natural-gas consumption as seasonally shaped, with winter heating demand and summer electric-sector demand creating the two main demand peaks. This card isolates the post-summer/pre-winter shoulder as a low-frequency `XNGUSD.DWX` D1 sleeve: short only during September and October, only when price confirms below a slow D1 mean, and flat outside the window.

This is deliberately different from `QM5_12567_cum-rsi2-commodity` because it uses no RSI, oscillator, or short-horizon pullback logic. It is fall-only and short-only, not the broader `QM5_12575` winter/summer/shoulder calendar map, not the spring-only `QM5_12703` sleeve, not the winter/summer long sleeves `QM5_12702` and `QM5_12704`, and not an XNG storage-report/event/fade/weekend-gap or energy-ratio basket.

## Markets And Timeframe

- Target symbol: `XNGUSD.DWX`.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no EIA feed, storage report, weather feed, power-load feed, futures curve, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the first D1 bar of a new broker-calendar week.
- Eligible months are September and October.
- Compute the prior completed D1 close and SMA(`strategy_trend_period`).
- SELL `XNGUSD.DWX` if the eligible month is active and the prior close is below the SMA.
- No long entries.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if `XNGUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit when the broker-calendar month is outside September-October.
- Exit when the prior D1 close rises above SMA(`strategy_trend_period`).
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Parameters To Test

- name: strategy_trend_period
  default: 42
  sweep_range: [21, 42, 63, 84]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 21
  sweep_range: [14, 21, 28]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Strategy Allowability Check

- [x] R1 reputable source: official U.S. Energy Information Administration source.
- [x] R2 mechanical: fixed September-October calendar window, weekly gate, SMA confirmation, ATR hard stop, trend exit, season exit, and max-hold exit.
- [x] R3 testable: `XNGUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: not RSI commodity logic, not broad dual-peak/shoulder-season XNG, not spring shoulder, not winter/summer long XNG, not XNG breakout/event/fade/weekend-gap logic, not an energy ratio basket.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, magic-slot guard, parameter guard, spread cap.
- trade_entry: fall shoulder/storage short entry after D1 SMA confirmation on a weekly calendar gate.
- trade_management: season end, SMA recovery, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/season/trend exits.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
