---
ea_id: QM5_12894
slug: xng-mar-transseason-short
type: strategy
strategy_id: EIA-XNG-SHOULDER-2026_S04
source_id: EIA-XNG-SHOULDER-2026
source_citation: "U.S. Energy Information Administration. Natural gas consumption, production respond to seasonal changes. Today in Energy, 2015-09-24. URL https://www.eia.gov/todayinenergy/detail.php?id=22892"
source_citations:
  - type: government_energy_research
    citation: "U.S. Energy Information Administration. Natural gas consumption, production respond to seasonal changes. Today in Energy, 2015-09-24."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=22892"
    quality_tier: A
    role: primary
  - type: official_energy_statistics
    citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report."
    location: "https://www.eia.gov/naturalgas/storage/"
    quality_tier: A
    role: supplemental_context
sources:
  - "[[sources/EIA-XNG-SHOULDER-2026]]"
concepts:
  - "[[concepts/natural-gas-seasonality]]"
  - "[[concepts/shoulder-season-demand]]"
  - "[[concepts/march-transseason-demand-lull]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, structural-demand, shoulder-season-demand, trend-filter-ma, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
logical_symbol: QM5_12894_XNG_MAR_TRANSSEASON_D1
single_symbol_only: true
period: D1
expected_trade_frequency: "Low-frequency March-to-mid-April natural-gas transseason short sleeve; weekly entry cadence, about 5-8 trade attempts/year before Q02 validates fill history."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-08
expected_pf: 1.05
expected_dd_pct: 20.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, friday_close, magic_schema, single-symbol-host-guard, no-external-runtime-data]
g0_approval_reasoning: "R1 PASS official EIA natural-gas seasonality source; R2 PASS deterministic Mar 1-Apr 15 weekly short rule using transition-rebound, downside-drift, SMA-stretch, ATR stop, time/season exits; R3 PASS XNGUSD.DWX exists in the DWX symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XNG March Transseason Short

## Source

- Source: [[sources/EIA-XNG-SHOULDER-2026]]
- Primary citation: U.S. Energy Information Administration, "Natural gas consumption, production respond to seasonal changes", Today in Energy, 2015-09-24, URL https://www.eia.gov/todayinenergy/detail.php?id=22892.

## Hypothesis

The EIA source describes natural gas demand as seasonal, with winter heating
demand and summer electric-sector demand peaks separated by lower-demand
shoulder periods. This card isolates the March-to-mid-April transition as
heating demand fades but summer cooling demand has not yet become the dominant
load. The EA shorts `XNGUSD.DWX` only when price action confirms that a brief
transition rebound has failed and the market is already drifting below a medium
D1 mean.

This is intentionally not a duplicate of:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator pullback, or generic
  short-horizon commodity mean-reversion logic.
- `QM5_12873_xng-latewinter-decay-short`: not Feb 15-Mar 31 winter-high decay,
  not fast-SMA slope decay, and not a winter-risk-premium rule.
- `QM5_12703_xngusd-spring-shoulder-short`: not a broad March-May spring
  shoulder short; this is a narrow Mar 1-Apr 15 weekly transition-rebound drift
  rule.
- `QM5_12595_eia-xng-shfade`: not a single-candle wick or failed-rally fade;
  the trigger requires a multi-day rebound, multi-day downside drift, and SMA
  stretch confirmation.
- `QM5_12872_eia-xng-stor-drift`: not a storage-report day or one-signal-per-
  month storage-season rule.
- XNG freeze, hurricane, storage aftershock/fade, weekend-gap, carry, oil/gas,
  gas/metal, and basket sleeves: no weather-shock, report value, broker-swap,
  cross-market leg, or pair-basket logic.

## Markets And Timeframe

- Target symbol: `XNGUSD.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, broker calendar, spread, SMA, ATR, and V5
  framework state only. No EIA data, storage report feed, weather feed,
  power-load feed, futures curve, CSV, API, analyst forecast, or ML model is
  read at runtime.

## Rules

The strategy is a deterministic D1 short-only implementation of the March-to-
mid-April shoulder transition. All entries, exits, filters, and risk controls
are fixed in advance and map directly to the V5 modules.

## 4. Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the first tradable D1 bar of a new broker week.
- Eligible dates are Mar 1 through Apr 15, inclusive.
- Compute the prior completed D1 close, medium SMA, ATR, the highest high over
  `strategy_rebound_lookback` completed bars, the close before that rebound
  window, and the close `strategy_drift_lookback` completed bars earlier.
- SELL `XNGUSD.DWX` if:
  - prior close is below the medium SMA,
  - prior close is at least `strategy_min_sma_stretch_atr` ATR below the SMA,
  - the recent high is at least `strategy_min_rebound_atr` ATR above the
    pre-rebound close,
  - the multi-day drift into the signal close is at least
    `strategy_min_down_drift_atr` ATR,
  - the prior bar closes no higher than `strategy_max_close_location` of its
    own range.
- No long entries.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if `XNGUSD.DWX` spread exceeds `strategy_max_spread_points`.

## 5. Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit when the broker calendar is outside Mar 1-Apr 15.
- Exit when the prior D1 close recovers above the medium SMA.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## 6. Filters (No-Trade Module)

- Only trade `XNGUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when SMA, ATR, OHLC, spread, or symbol data is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## 7. Trade Management Rules

- Short-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_start_month
  default: 3
  sweep_range: [3]
- name: strategy_start_day
  default: 1
  sweep_range: [1]
- name: strategy_end_month
  default: 4
  sweep_range: [4]
- name: strategy_end_day
  default: 15
  sweep_range: [10, 15, 20]
- name: strategy_sma_period
  default: 34
  sweep_range: [21, 34, 55]
- name: strategy_rebound_lookback
  default: 4
  sweep_range: [3, 4, 6]
- name: strategy_drift_lookback
  default: 3
  sweep_range: [2, 3, 5]
- name: strategy_min_rebound_atr
  default: 0.35
  sweep_range: [0.20, 0.35, 0.60]
- name: strategy_min_down_drift_atr
  default: 0.55
  sweep_range: [0.35, 0.55, 0.90]
- name: strategy_min_sma_stretch_atr
  default: 0.10
  sweep_range: [0.00, 0.10, 0.30]
- name: strategy_max_close_location
  default: 0.42
  sweep_range: [0.30, 0.42, 0.50]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 7
  sweep_range: [5, 7, 10]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported into QM. The EIA source is used only for
official structural lineage around natural-gas seasonal demand and the lower-
demand shoulder transition. Q02 and later phases must validate or reject the
mechanical Darwinex `XNGUSD.DWX` port.

## Initial Risk Profile

- expected_pf: 1.05.
- expected_dd_pct: 20.
- expected_trade_frequency: about 5-8 trade attempts/year before Q02.
- risk_class: high because natural-gas volatility can gap sharply around weather and storage shocks.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official U.S. Energy Information Administration natural-gas seasonality source.
- [x] R2 mechanical: fixed Mar 1-Apr 15 calendar window, weekly entry cadence, rebound/drift/SMA confirmation, ATR hard stop, and time/season/trend exits.
- [x] R3 testable: `XNGUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external runtime feed, or more than one position per magic.
- [x] Non-duplicate: March-to-mid-April transition-rebound drift short, not cumulative RSI2, winter-high decay, storage-report drift, broad seasonal map, spring shoulder wick fade, injection-season slope, weather event, carry, or basket logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XNGUSD.DWX`
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, magic-slot guard, parameter guard, spread cap, and data-availability checks.
- trade_entry: weekly Mar 1-Apr 15 short entry after a brief transition rebound fails into downside drift below a medium SMA.
- trade_management: season end, SMA recovery, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/season/trend exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-08 | initial structural XNG March transseason build | Q02 | READY_TO_QUEUE |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-08 | APPROVED | this card |
| Q01 Build Validation | 2026-07-08 | PENDING | `artifacts/qm5_12894_build_result.json` |
| Q02 Baseline Screening | 2026-07-08 | PENDING | `artifacts/qm5_12894_q02_enqueue_20260708.json` |
