---
ea_id: QM5_12738
slug: xng-weekend-gap
type: strategy
source_id: EIA-XNG-WEEKEND-GAP-2026
source_citation: "U.S. Energy Information Administration. Factors affecting natural gas prices. Energy Explained. URL https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php"
sources:
  - "[[sources/EIA-XNG-WEEKEND-GAP-2026]]"
concepts:
  - "[[concepts/natural-gas-weather-demand]]"
  - "[[concepts/weekend-gap-continuation]]"
  - "[[concepts/energy-structural-flow]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-weather-proxy, weekend-gap, continuation, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "D1 natural-gas Monday weather-gap continuation; estimate 6-14 trades/year after gap, confirmation, and spread filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS single official EIA natural-gas price/weather source; R2 PASS deterministic Monday gap plus same-day continuation and time/ATR exits; R3 PASS XNGUSD.DWX; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.10
expected_dd_pct: 24.0
---

# XNG Weekend Weather-Gap Continuation

## Source

- Source: [[sources/EIA-XNG-WEEKEND-GAP-2026]]
- Primary citation: U.S. Energy Information Administration, "Factors affecting natural gas prices", Energy Explained, URL https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php.

## Concept

Natural gas is unusually sensitive to weekend weather repricing because heating and electric-power demand forecasts update while the CFD market is closed or thin. This card expresses that structural lineage as an OHLC-only Darwinex sleeve: after a Monday D1 bar gaps away from the prior trading-day close and then closes in the same direction, enter continuation for a short fixed hold.

This is intentionally not a duplicate of:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or short-horizon pullback logic.
- `QM5_12575_eia-xng-season`: not a broad monthly season map.
- `QM5_12584_eia-xng-storage`: not a weekly EIA storage-report aftershock.
- `QM5_12586_eia-xng-winter-brk`: not a withdrawal-season channel breakout.
- `QM5_12587_eia-xng-inj-brk`: not an injection-season downside breakout.
- `QM5_12588_eia-xng-sum-sqz`: not summer compression breakout logic.
- `QM5_12595_eia-xng-shfade`: not shoulder-season failed-rally fade.
- `QM5_12601_eia-xng-hurr-brk`: not hurricane-season breakout.
- `QM5_12602_eia-xng-frzfade`: not January-February spike/rejection fade.
- `QM5_12725_eia-xng-prestor`: not a storage-season pre-positioning sleeve.
- `QM5_12733_xti-xng-xmom`: not a two-leg energy relative-momentum basket.

## Markets And Timeframe

- Symbol: XNGUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only.

## Entry Rules

- Evaluate only on a new D1 bar.
- Inspect the prior completed D1 bar; it must be a Monday broker-calendar bar.
- Compute the prior completed bar open, close, high, low, previous trading-day close, and ATR(20).
- Calculate gap size: `abs(prior_open - previous_close)`.
- Long entry: Monday opens above the previous close by at least `strategy_min_gap_atr * ATR`, closes above Monday open, and Monday body is at least `strategy_min_body_atr * ATR`.
- Short entry: Monday opens below the previous close by at least `strategy_min_gap_atr * ATR`, closes below Monday open, and Monday body is at least `strategy_min_body_atr * ATR`.
- No entry if an open XNGUSD.DWX position already exists for this EA magic.
- No entry if XNGUSD.DWX spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit after `strategy_max_hold_days` calendar days.
- Exit long if a later closed D1 bar closes below the entry signal close.
- Exit short if a later closed D1 bar closes above the entry signal close.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be XNGUSD.DWX on D1.
- Monday signal bar only; entry happens at the next new D1 bar after confirmation.
- Skip entries when ATR/OHLC history is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Direction follows the Monday gap and same-day body.
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
- name: strategy_min_gap_atr
  default: 0.35
  sweep_range: [0.25, 0.35, 0.50, 0.75]
- name: strategy_min_body_atr
  default: 0.20
  sweep_range: [0.10, 0.20, 0.30]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.0, 2.75, 3.5]
- name: strategy_max_hold_days
  default: 4
  sweep_range: [2, 4, 6]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported from EIA. The source is used only for official structural lineage that natural-gas pricing is weather-sensitive. Q02+ tests the deterministic Monday gap rule on Darwinex `XNGUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 24
- expected_trade_frequency: approximately 6-14 trades/year.
- risk_class: high for natural-gas volatility and gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: one EIA Energy Explained URL and one `source_id`.
- [x] R2 mechanical: fixed weekday gate, ATR-normalized gap/body thresholds, ATR stop, and deterministic exits.
- [x] R3 testable: `XNGUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: weekend weather-gap continuation is not RSI, broad seasonality, storage, freeze fade, hurricane, injection, shoulder, prestorage, or XTI/XNG relative-value logic.

## Framework Alignment

- no_trade: D1/XNGUSD.DWX guard, Monday signal gate, spread cap, parameter sanity.
- trade_entry: confirmed Monday weekend-gap continuation.
- trade_management: max-hold and signal-close invalidation exits.
- trade_close: hard ATR stop plus framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-28 | initial structural XNG weekend-gap continuation build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
