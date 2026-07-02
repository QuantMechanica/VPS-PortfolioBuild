---
ea_id: QM5_12873
slug: xng-latewinter-decay-short
type: strategy
strategy_id: EIA-XNG-SHOULDER-2026_S03
source_id: EIA-XNG-SHOULDER-2026
source_citation: "U.S. Energy Information Administration. Natural gas consumption, production respond to seasonal changes. Today in Energy, 2015-09-24. URL https://www.eia.gov/todayinenergy/detail.php?id=22892"
source_citations:
  - type: government_energy_research
    citation: "U.S. Energy Information Administration. Natural gas consumption, production respond to seasonal changes. Today in Energy, 2015-09-24."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=22892"
    quality_tier: A
    role: primary
sources:
  - "[[sources/EIA-XNG-SHOULDER-2026]]"
concepts:
  - "[[concepts/natural-gas-seasonality]]"
  - "[[concepts/shoulder-season-demand]]"
  - "[[concepts/late-winter-risk-premium-decay]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, structural-demand, trend-filter-ma, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [XNGUSD.DWX]
timeframes: [D1]
logical_symbol: QM5_12873_XNG_LATEWINTER_DECAY_D1
single_symbol_only: true
period: D1
expected_trade_frequency: "Low-frequency late-winter natural-gas decay sleeve; weekly entry cadence from Feb 15 through Mar 31, about 4-9 trade attempts/year before Q02 validates fill history."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS official EIA natural-gas seasonality source; R2 PASS deterministic Feb 15-Mar 31 weekly short rule using winter-high drawdown, SMA slope, ATR stop, time/season exits; R3 PASS XNGUSD.DWX exists in the DWX symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XNG Late-Winter Decay Short

## Source

- Source: [[sources/EIA-XNG-SHOULDER-2026]]
- Primary citation: U.S. Energy Information Administration, "Natural gas consumption, production respond to seasonal changes", Today in Energy, 2015-09-24, URL https://www.eia.gov/todayinenergy/detail.php?id=22892.

## Concept

The EIA source describes natural gas demand as seasonal, with winter heating demand and summer electric-sector demand peaks separated by lower-demand shoulder periods. This card isolates the late-winter transition from heating-risk premium toward shoulder-season demand: after mid-February, the EA shorts `XNGUSD.DWX` only when price has already decayed materially from the prior winter high and the D1 fast average is falling.

This is intentionally not a duplicate of:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator pullback, or short-horizon commodity mean-reversion logic.
- `QM5_12575_eia-xng-season`: not a broad two-sided monthly season map.
- `QM5_12587_eia-xng-inj-brk`: not a Donchian downside breakout.
- `QM5_12595_eia-xng-shfade`: not a failed-rally candle or wick fade.
- `QM5_12602_xng-freeze-fade`: not a weather-spike or rejection fade; this requires an established decay from the winter high after Feb 15.
- `QM5_12703_xngusd-spring-shoulder-short`: not a broad March-May spring-shoulder short; this is a Feb 15-Mar 31 late-winter premium-decay sleeve with weekly cadence and winter-high drawdown confirmation.
- `QM5_12874_xng-inject-slope-short`: not an April-October monthly injection-season trend-slope rule.
- XNG storage-report, hurricane, weekend-gap, carry, and energy basket sleeves: no event-day, weather-shock, storage-report timing, broker-swap, or pair-basket logic.

## Markets And Timeframe

- Target symbol: `XNGUSD.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, broker calendar, spread, SMA, ATR, and V5 framework state only. No EIA data, storage report feed, weather feed, power-load feed, futures curve, CSV, API, analyst forecast, or ML model is read at runtime.

## Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the first tradable D1 bar of a new broker week.
- Eligible dates are Feb 15 through Mar 31, inclusive.
- Compute the prior completed D1 close, fast SMA, ATR, the fast SMA `strategy_slope_lookback_days` earlier, and the highest D1 high over `strategy_winter_high_lookback` completed bars.
- SELL `XNGUSD.DWX` if:
  - prior close is below fast SMA,
  - fast SMA slope over the lookback is at or below `-strategy_min_decay_slope_atr` ATR,
  - prior close is at least `strategy_min_drawdown_atr` ATR below the winter-high lookback.
- No long entries.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if `XNGUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit when the broker calendar is outside Feb 15-Mar 31.
- Exit when the prior D1 close recovers above fast SMA.
- Exit when fast SMA slope is non-negative.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when SMA, ATR, OHLC, spread, or symbol data is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Short-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_start_month
  default: 2
  sweep_range: [2]
- name: strategy_start_day
  default: 15
  sweep_range: [10, 15, 20]
- name: strategy_end_month
  default: 3
  sweep_range: [3]
- name: strategy_end_day
  default: 31
  sweep_range: [20, 31]
- name: strategy_fast_period
  default: 21
  sweep_range: [14, 21, 34]
- name: strategy_slope_lookback_days
  default: 5
  sweep_range: [3, 5, 10]
- name: strategy_winter_high_lookback
  default: 45
  sweep_range: [30, 45, 60]
- name: strategy_min_drawdown_atr
  default: 1.20
  sweep_range: [0.80, 1.20, 1.80]
- name: strategy_min_decay_slope_atr
  default: 0.15
  sweep_range: [0.10, 0.15, 0.25]
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

No performance claim is imported into QM. The EIA source is used only for official structural lineage around natural-gas seasonal demand and the lower-demand shoulder transition. Q02 and later phases must validate or reject the mechanical Darwinex `XNGUSD.DWX` port.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 20.
- expected_trade_frequency: about 4-9 trade attempts/year before Q02.
- risk_class: high because natural-gas volatility can gap sharply around weather and storage shocks.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official U.S. Energy Information Administration natural-gas seasonality source.
- [x] R2 mechanical: fixed Feb 15-Mar 31 calendar window, weekly entry cadence, winter-high drawdown, SMA slope confirmation, ATR hard stop, and time/season/trend exits.
- [x] R3 testable: `XNGUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external runtime feed, or more than one position per magic.
- [x] Non-duplicate: late-winter premium decay short, not cumulative RSI2, Donchian breakdown, failed-rally fade, broad seasonal map, spring shoulder, injection-season slope, storage event, weather event, carry, or basket logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XNGUSD.DWX` setfile. Live risk is intentionally not configured here; any future live allocation must come from the portfolio process. The EA does not touch `T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio gate.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, magic-slot guard, parameter guard, spread cap, and data-availability checks.
- trade_entry: weekly Feb 15-Mar 31 short entry after prior D1 close is below fast SMA, the fast SMA is declining, and price has decayed from the winter high by the configured ATR amount.
- trade_management: season end, fast-SMA recovery, slope recovery, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/season/trend exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-02 | initial structural XNG late-winter decay build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
| Q01 Build Validation | 2026-07-02 | PASS | `artifacts/qm5_12873_build_result.json` |
| Q02 Baseline Screening | 2026-07-02 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `0b1d9261-48d3-4ef4-a743-a0915a8ab722` |
