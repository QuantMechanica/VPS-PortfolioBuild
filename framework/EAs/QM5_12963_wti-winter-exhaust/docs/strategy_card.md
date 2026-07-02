---
ea_id: QM5_12963
slug: wti-winter-exhaust
type: strategy
source_id: EIA-HEATOIL-EXHAUST-2026
source_citation: "U.S. Energy Information Administration. Factors affecting heating oil prices. Energy Explained. URL https://www.eia.gov/energyexplained/heating-oil/factors-affecting-heating-oil-prices.php"
source_citations:
  - type: government_energy_research
    citation: "U.S. Energy Information Administration. Factors affecting heating oil prices. Energy Explained."
    location: "https://www.eia.gov/energyexplained/heating-oil/factors-affecting-heating-oil-prices.php"
    quality_tier: A
    role: primary
  - type: government_energy_research
    citation: "U.S. Energy Information Administration. What drives crude oil prices: Balance."
    location: "https://www.eia.gov/finance/markets/crudeoil/balance.php"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-HEATOIL-EXHAUST-2026]]"
concepts:
  - "[[concepts/heating-oil-winter-demand]]"
  - "[[concepts/wti-winter-exhaustion-fade]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, mean-reversion, trend-filter-ma, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12963_XTI_WINTER_EXHAUST_D1
period: D1
expected_trade_frequency: "D1 WTI winter heating-oil exhaustion fade; estimate 5-12 trades/year after stretch, rejection, spread, and framework filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-02
expected_pf: 1.10
expected_dd_pct: 20.0
g0_approval_reasoning: "R1 PASS official EIA heating-oil/crude-inventory sources; R2 PASS deterministic D1 winter exhaustion fade with SMA mean, ATR stop, and time/window exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# WTI Winter Heating-Oil Exhaustion Fade

## Source

- Primary citation: U.S. Energy Information Administration, "Factors affecting heating oil prices", Energy Explained, URL https://www.eia.gov/energyexplained/heating-oil/factors-affecting-heating-oil-prices.php.
- Supplement: U.S. Energy Information Administration, "What drives crude oil prices: Balance", URL https://www.eia.gov/finance/markets/crudeoil/balance.php.

## Concept

The EIA heating-oil source describes winter cold-weather demand shocks that can
draw down inventories faster than they are replenished and can sharply lift
heating-oil prices. The EIA crude-balance source separately describes petroleum
inventories as the balancing point between supply and demand and notes that
heating oil has pronounced seasonal demand variation. This card expresses that
structural winter stress through `XTIUSD.DWX` only after the market shows a D1
exhaustion/rejection bar: it fades stretched upside winter moves back toward a
slow mean.

Runtime data stays Darwinex MT5 OHLC-only. The EA does not read EIA, weather,
inventory, product-spread, futures-curve, CSV, API, or external data at runtime.

This is deliberately different from:

- `QM5_12583_eia-distillate-winter`: winter long channel breakout, not an
  exhaustion fade.
- `QM5_12748_eia-distill-pb`: winter long pullback in an uptrend, not a
  short-only stretched-bar rejection.
- `QM5_12593_eia-wti-ref-fade`: spring/autumn refinery-turnaround fade, not a
  winter heating-oil demand shock.
- `QM5_12740_eia-wti-postdrive` and month/weekday WTI cards: this is not a
  static calendar short; it requires D1 stretch, body, tail, and mean filters.
- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator pullback, grid, martingale,
  or broad commodity basket.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 5-12 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only.

## Entry Rules

- Evaluate only on a new D1 bar.
- The prior closed D1 bar must fall inside the winter heating-oil shock window:
  November 1 through February 28, inclusive.
- Short only.
- Skip if an open `XTIUSD.DWX` position already exists for this EA magic.
- Skip if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.
- Compute prior D1 open, high, low, close, ATR(`strategy_atr_period`), and
  SMA(`strategy_mean_period`) on completed D1 bars.
- Prior close must be above SMA(`strategy_mean_period`).
- Stretch from SMA must be at least `strategy_min_stretch_atr * ATR`.
- Prior-bar range must be at least `strategy_min_range_atr * ATR`.
- Prior-bar body size must be at least `strategy_min_body_ratio` of total range.
- Entry Short: prior bar body is negative and closes in the lower
  `strategy_reversal_tail_ratio` fraction of its D1 range.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit when the prior closed D1 bar is outside the winter window.
- Exit when prior closed D1 close reaches or falls below
  SMA(`strategy_mean_period`).
- Exit when the position has been held for more than `strategy_max_hold_days`
  calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- No long entries.
- No pyramiding, gridding, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Short-only.
- One open position per magic/symbol.
- No trailing stop in v1.
- Strategy exits run even when the framework news gate blocks new entries.

## Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_mean_period
  default: 50
  sweep_range: [34, 50, 84]
- name: strategy_min_range_atr
  default: 0.60
  sweep_range: [0.50, 0.60, 0.80, 1.00]
- name: strategy_min_body_ratio
  default: 0.25
  sweep_range: [0.20, 0.25, 0.35, 0.45]
- name: strategy_reversal_tail_ratio
  default: 0.45
  sweep_range: [0.30, 0.40, 0.45]
- name: strategy_min_stretch_atr
  default: 0.60
  sweep_range: [0.50, 0.60, 0.90, 1.20]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.0, 2.75, 3.5]
- name: strategy_max_hold_days
  default: 7
  sweep_range: [4, 7, 10]
- name: strategy_winter_start_month
  default: 11
  sweep_range: [11]
- name: strategy_winter_start_day
  default: 1
  sweep_range: [1, 15]
- name: strategy_winter_end_month
  default: 2
  sweep_range: [2]
- name: strategy_winter_end_day
  default: 28
  sweep_range: [15, 28]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from EIA. The sources provide only structural
lineage: winter heating-oil demand can create sharp price increases, and
petroleum inventories mediate seasonal demand and price pressure. The Q02+
pipeline tests whether this deterministic WTI winter exhaustion rule has value
on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 20
- expected_trade_frequency: approximately 5-12 trades/year on D1.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA heating-oil and crude-balance URLs.
- [x] R2 mechanical: fixed winter window, D1 stretch rejection entry, SMA mean
  exit, ATR stop, and max-hold exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: not existing WTI distillate long breakout/pullback,
  refinery shoulder fade, driving-season, WPSR, hurricane, OPEC, expiry, roll,
  month/weekday, XTI/XNG, XAU/XAG, or RSI commodity logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: winter D1 stretched upside rejection short.
- trade_management: season-window end, SMA mean-reversion, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/window exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-02 | initial structural WTI winter heating-oil exhaustion fade build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
