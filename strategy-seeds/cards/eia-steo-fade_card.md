---
ea_id: QM5_13047
slug: eia-steo-fade
type: strategy
strategy_id: EIA-STEO-XTI-FADE-2026
source_id: EIA-STEO-XTI-BRK-2026
source_citation: "U.S. Energy Information Administration, Short-Term Energy Outlook, https://www.eia.gov/outlooks/steo/; STEO release schedule, https://www.eia.gov/outlooks/steo/release_schedule.php; STEO global oil markets, https://www.eia.gov/outlooks/steo/report/global_oil.php"
source_citations:
  - type: official_report
    citation: "U.S. Energy Information Administration. Short-Term Energy Outlook."
    location: "https://www.eia.gov/outlooks/steo/"
    quality_tier: A
    role: primary
  - type: official_release_schedule
    citation: "U.S. Energy Information Administration. Short-Term Energy Outlook release schedule."
    location: "https://www.eia.gov/outlooks/steo/release_schedule.php"
    quality_tier: A
    role: timing_rule
  - type: official_report
    citation: "U.S. Energy Information Administration. STEO global oil markets."
    location: "https://www.eia.gov/outlooks/steo/report/global_oil.php"
    quality_tier: A
    role: crude_oil_context
sources:
  - "[[sources/EIA-STEO-XTI-BRK-2026]]"
concepts:
  - "[[concepts/monthly-energy-information-window]]"
  - "[[concepts/crude-oil-forecast-reaction]]"
  - "[[concepts/failed-breakout-reversal]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [official-release-window, failed-breakout-fade, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13047_XTI_STEO_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly EIA STEO D1 failed-breakout fade; estimate 5-10 entries/year after range, probe, reclaim, spread, and one-entry-per-release filters."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-08
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [official_release_window_proxy, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-08: R1 PASS official EIA STEO source, release schedule, and global oil-market context; R2 PASS deterministic monthly release-window calendar proxy, D1 failed Donchian probe/reclaim fade, ATR stop/target, and time exit; R3 PASS XTIUSD.DWX is in the DWX symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate versus QM5_12992 because this fades failed release-window probes instead of following closing breakouts."
---

# EIA STEO WTI Failed-Breakout Fade

## Source

- Primary reference: U.S. Energy Information Administration, Short-Term Energy
  Outlook, https://www.eia.gov/outlooks/steo/.
- Timing reference: U.S. Energy Information Administration, Short-Term Energy
  Outlook release schedule, https://www.eia.gov/outlooks/steo/release_schedule.php.
- Oil-market context: U.S. Energy Information Administration, STEO global oil
  markets, https://www.eia.gov/outlooks/steo/report/global_oil.php.

## Concept

The STEO is a recurring official EIA monthly information event covering global
oil supply, demand, inventories, and WTI/Brent price context. `QM5_12992` already
tests whether the release-window D1 bar can continue after a closing breakout.
This card tests the opposite structural behavior: when the STEO proxy day probes
outside the recent D1 crude range but closes back inside it, the next session
fades that failed breakout.

This is deliberately different from:

- `QM5_12992_eia-steo-brk`: that EA follows release-window closing breakouts;
  this EA requires an outside probe and close-back-inside failure.
- `QM5_12994_iea-omr-fade` and `QM5_12995_opec-momr-brk`: different official
  monthly report calendars.
- WPSR, DPR, PSM, Cushing, SPR, import/export, production, refinery, hurricane,
  OPEC, IEA, roll, month, weekday, XTI/XNG, oil/metal, XAU/XAG, XNG, and RSI
  commodity sleeves already in the registry.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected frequency: approximately 5-10 trades/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker calendar, and V5
  framework state only. No EIA website read, release-content feed, CSV, API,
  futures curve, inventory data, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- The prior completed D1 bar must be the STEO proxy day: first Tuesday after
  the first Thursday of the broker-calendar month, with optional Wednesday
  delay handling.
- Build a Donchian context from the prior `strategy_context_lookback` completed
  D1 bars excluding the STEO proxy day.
- Require the STEO proxy D1 range to be at least
  `strategy_min_range_atr * ATR(strategy_atr_period)`.
- Require the STEO proxy D1 body to be at least
  `strategy_min_body_atr * ATR(strategy_atr_period)`.
- Short fade: the STEO proxy high probes above the context high by at least
  `strategy_min_probe_atr * ATR`, but the close is back at or below the context
  high and in the lower half of the D1 range.
- Long fade: the STEO proxy low probes below the context low by at least
  `strategy_min_probe_atr * ATR`, but the close is back at or above the context
  low and in the upper half of the D1 range.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Take profit: ATR(`strategy_atr_period`) * `strategy_atr_tp_mult`.
- Close any still-open position after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- Invalid parameters fail closed.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_context_lookback
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.50
  sweep_range: [0.40, 0.50, 0.80]
- name: strategy_min_body_atr
  default: 0.10
  sweep_range: [0.05, 0.10, 0.20]
- name: strategy_min_probe_atr
  default: 0.05
  sweep_range: [0.00, 0.05, 0.15]
- name: strategy_long_min_close_location
  default: 0.50
  sweep_range: [0.45, 0.50, 0.60]
- name: strategy_short_max_close_location
  default: 0.50
  sweep_range: [0.40, 0.50, 0.55]
- name: strategy_atr_sl_mult
  default: 2.25
  sweep_range: [1.75, 2.25, 3.0]
- name: strategy_atr_tp_mult
  default: 2.75
  sweep_range: [2.0, 2.75, 3.5]
- name: strategy_max_hold_days
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_allow_wed_delay
  default: true
  sweep_range: [true, false]

## Author Claims

The EIA source establishes only the recurring official STEO information window
and oil-market context. This card imports no EIA performance claim. Q02 and
later phases must validate or reject the deterministic OHLC-only realization on
Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 5-10 entries/year.
- risk_class: medium-high because crude oil report windows can gap and trend.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA STEO report and release schedule.
- [x] R2 mechanical: fixed monthly calendar proxy, failed Donchian probe/reclaim,
  ATR stop/target, spread cap, and time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, adaptive fitting, grid, martingale, external runtime
  feed, or discretionary override.
- [x] Non-duplicate: failed STEO probe fade, not STEO breakout, WPSR, OPEC,
  IEA, roll, COT, production, refinery, hurricane, XNG, XAU/XAG, or commodity
  RSI logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, release-window proxy, and valid data checks.
- trade_entry: monthly STEO failed-breakout fade on completed D1 OHLC.
- trade_management: max-hold stale-position exit.
- trade_close: hard ATR stop, ATR target, and deterministic time exit.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-08 | initial structural EIA STEO failed-breakout fade build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-08 | APPROVED | this card |
| Q01 Build Validation | 2026-07-08 | PENDING | `artifacts/qm5_13047_build_result.json` |
| Q02 Baseline Screening | 2026-07-08 | PENDING | `D:\QM\strategy_farm\state\farm_state.sqlite` |
