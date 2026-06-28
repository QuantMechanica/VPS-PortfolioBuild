---
ea_id: QM5_12702
slug: xngusd-winter-withdrawal-long
type: strategy
source_id: 706222b7-2d60-5fdb-8dab-d722d3c96f92
source_citation: "U.S. Energy Information Administration. (2015). Natural gas consumption, production respond to seasonal changes. Today in Energy, 2015-09-24. URL https://www.eia.gov/todayinenergy/detail.php?id=22892"
sources:
  - "[[sources/706222b7-2d60-5fdb-8dab-d722d3c96f92]]"
concepts:
  - "[[concepts/natural-gas-seasonality]]"
  - "[[concepts/winter-withdrawal-demand]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, seasonal-window, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Winter withdrawal/heating-demand XNG sleeve on D1; estimate 3-5 monthly entries/year after trend confirmation and framework filters."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS official EIA Today in Energy source; R2 PASS deterministic November-March XNG long-only calendar window with SMA confirmation, ATR stop, and time/season exits; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 18.0
---

# XNG Winter Withdrawal Long

## Source

- Source: [[sources/706222b7-2d60-5fdb-8dab-d722d3c96f92]]
- Primary citation: U.S. Energy Information Administration, "Natural gas consumption, production respond to seasonal changes", Today in Energy, 2015-09-24, URL https://www.eia.gov/todayinenergy/detail.php?id=22892.

## Concept

The EIA source describes natural gas consumption and storage behavior as seasonal, with winter heating demand and the withdrawal season creating a distinct cold-season regime. This card isolates that regime as a low-frequency `XNGUSD.DWX` D1 sleeve: long only during November through March, only when price confirms above a slow D1 mean, and flat outside the window.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or short-horizon pullback logic.
- `QM5_12575_eia-xng-season`: this card is winter-only and long-only, not the broader winter/summer/shoulder calendar map.
- `QM5_12586_eia-xng-winter-brk`: this card does not trade a Donchian or breakout trigger; it is a monthly seasonal allocation with SMA confirmation.
- XNG storage, hurricane, freeze-fade, shoulder-fade, prestorage, weekend-gap, and XTI/XNG basket sleeves: no event day, weather shock, storage-report timing, or pair basket logic.

## Markets And Timeframe

- Target symbol: `XNGUSD.DWX`.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no EIA feed, storage report, weather feed, futures curve, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the first D1 bar of a new broker-calendar month.
- Eligible months are November, December, January, February, and March.
- Compute the prior completed D1 close and SMA(`strategy_trend_period`).
- BUY `XNGUSD.DWX` if the eligible month is active and the prior close is above the SMA.
- No short entries.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if `XNGUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit when the broker-calendar month is outside November-March.
- Exit when the prior D1 close falls below SMA(`strategy_trend_period`).
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when SMA/ATR/OHLC data is unavailable.
- Framework news, kill-switch, magic, spread, and Friday-close guards remain active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

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
  default: 35
  sweep_range: [21, 35, 45]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported into QM. The EIA source is used only for structural lineage around natural-gas seasonal consumption, winter heating demand, and storage withdrawal behavior. The Q02+ pipeline tests the mechanical Darwinex `XNGUSD.DWX` port.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 18
- expected_trade_frequency: approximately 3-5 entries/year.
- risk_class: medium-high for natural-gas volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official U.S. Energy Information Administration source.
- [x] R2 mechanical: fixed November-March calendar window, SMA confirmation, ATR hard stop, trend exit, season exit, and max-hold exit.
- [x] R3 testable: `XNGUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: not RSI commodity logic, not broad dual-peak/short-season XNG, not XNG breakout/event/fade/weekend-gap logic, not an energy ratio basket.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XNGUSD.DWX` setfile. Live risk is intentionally not configured here; any future live allocation must come from the portfolio process. The EA does not touch `T_Live`, AutoTrading, deploy manifests, or the portfolio gate.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, magic-slot guard, parameter guard, spread cap.
- trade_entry: monthly winter-withdrawal long entry after D1 SMA confirmation.
- trade_management: season end, SMA failure, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/season/trend exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-28 | initial structural XNG winter withdrawal long build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
