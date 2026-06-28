---
ea_id: QM5_12748
slug: eia-distill-pb
type: strategy
source_id: EIA-HEATOIL-PB-2026
source_citation: "U.S. Energy Information Administration. Factors affecting heating oil prices. Energy Explained. URL https://www.eia.gov/energyexplained/heating-oil/factors-affecting-heating-oil-prices.php"
source_citations:
  - type: government_energy_research
    citation: "U.S. Energy Information Administration. Factors affecting heating oil prices. Energy Explained."
    location: "https://www.eia.gov/energyexplained/heating-oil/factors-affecting-heating-oil-prices.php"
    quality_tier: A
    role: primary
sources:
  - "[[sources/EIA-HEATOIL-PB-2026]]"
concepts:
  - "[[concepts/heating-oil-winter-demand]]"
  - "[[concepts/wti-seasonal-pullback]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, n-period-min-reversion, trend-filter-ma, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12748_XTI_DISTILL_PB_D1
period: D1
expected_trade_frequency: "D1 WTI winter distillate/heating-oil pullback sleeve; estimate 4-10 trades/year after pullback, trend, spread, and framework filters."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
expected_pf: 1.10
expected_dd_pct: 18.0
g0_approval_reasoning: "R1 PASS official EIA heating-oil price/demand source; R2 PASS deterministic D1 winter pullback with SMA trend/rebound gates, ATR stop, and time/window exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# EIA Winter Distillate Pullback

## Source

- Source: [[sources/EIA-HEATOIL-PB-2026]]
- Primary citation: U.S. Energy Information Administration, "Factors affecting heating oil prices", Energy Explained, URL https://www.eia.gov/energyexplained/heating-oil/factors-affecting-heating-oil-prices.php.

## Concept

The EIA source describes heating oil as a seasonal petroleum product whose
prices are affected by winter demand and crude-oil input costs. This card does
not trade heating-oil futures and does not import EIA, weather, inventory, or
distillate-spread data at runtime. It expresses the structural lineage as a
low-frequency WTI pullback sleeve: during the October-March winter heating
season, buy only after a short D1 downside pullback while price remains above a
slow trend filter, then exit on rebound, trend failure, season end, max hold, or
ATR hard stop.

This is deliberately different from:

- `QM5_12583_eia-distillate-winter`: winter channel-breakout continuation, not pullback mean reversion.
- `QM5_12746_eia-wti-drive-pb`: gasoline driving-season pullback in April-August, not winter distillate/heating-oil season.
- `QM5_12576_eia-wti-season`: broad monthly WTI season map with SMA/ROC confirmation.
- WPSR, hurricane, refinery, OPEC, expiry, ETF-roll, weekday/month WTI, XTI/XNG, XAU/XAG, oil/gold, oil/silver, XNG, and RSI commodity sleeves already in the registry.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 4-10 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no EIA feed,
  heating-oil spread, weather feed, futures curve, refinery feed, inventory
  feed, CSV, API, or external input.

## Entry Rules

- Evaluate only on a new D1 bar.
- The prior closed D1 bar must fall inside the winter heating-oil season window: October 1 through March 31, inclusive.
- Long only.
- Skip if an open `XTIUSD.DWX` position already exists for this EA magic.
- Skip if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.
- Buy when the prior closed D1 close is at or below the lowest low of the previous `strategy_pullback_lookback` completed D1 bars, excluding the signal bar.
- Require the prior closed D1 close to be above SMA(`strategy_trend_period`).
- Require the prior closed D1 close to remain below SMA(`strategy_rebound_period`).
- Require the prior close-to-close return to be at or below `-strategy_min_down_return_pct`.
- Use ATR(`strategy_atr_period`) on completed D1 bars for the hard stop.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit when the prior closed D1 bar is outside the winter heating-oil season window.
- Exit when prior closed D1 close falls below SMA(`strategy_trend_period`).
- Exit when prior closed D1 close rebounds to or above SMA(`strategy_rebound_period`).
- Exit when the position has been held for more than `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- No short entries.
- Skip entries when ATR, SMA, or OHLC state is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_start_month
  default: 10
  sweep_range: [10]
- name: strategy_start_day
  default: 1
  sweep_range: [1, 15]
- name: strategy_end_month
  default: 3
  sweep_range: [3]
- name: strategy_end_day
  default: 31
  sweep_range: [15, 31]
- name: strategy_pullback_lookback
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_min_down_return_pct
  default: 0.75
  sweep_range: [0.50, 0.75, 1.00]
- name: strategy_trend_period
  default: 50
  sweep_range: [40, 50, 75]
- name: strategy_rebound_period
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.0, 2.75, 3.5]
- name: strategy_max_hold_days
  default: 8
  sweep_range: [5, 8, 12]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from EIA. The source is used only for official
structural lineage around heating-oil winter seasonality and crude-oil input
costs. The Q02+ pipeline tests whether this deterministic WTI seasonal pullback
rule has value on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 18
- expected_trade_frequency: approximately 4-10 trades/year on D1.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA heating-oil price/demand URL and one `source_id`.
- [x] R2 mechanical: fixed date window, D1 pullback entry, SMA trend/rebound gates, date/time exits, and ATR stop.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: not winter channel breakout, driving-season pullback, broad WTI seasonality, WPSR, hurricane, refinery, OPEC, expiry, ETF-roll, weekday/month, medium-term momentum, ratio basket, XNG, or RSI commodity logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: winter heating-oil season D1 long pullback above slow SMA trend filter.
- trade_management: season-window end, trend failure, rebound SMA, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/window exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-28 | initial structural WTI winter distillate pullback card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
