---
ea_id: QM5_12755
slug: wti-spr-refill-bounce
type: strategy
source_id: DOE-WTI-SPR-REFILL-2024
source_citation: "U.S. Department of Energy / CESER. Strategic Petroleum Reserve purchase solicitations and replenishment strategy, including SPR repurchases around at or below USD 79 per barrel. URLs https://www.energy.gov/ceser/articles/us-department-energy-announces-solicitation-purchase-oil-strategic-petroleum-1 and https://www.energy.gov/ceser/articles/us-department-energy-announces-solicitation-purchase-oil-strategic-petroleum-7"
source_citations:
  - type: government_energy_policy
    citation: "U.S. Department of Energy / CESER, Strategic Petroleum Reserve purchase solicitation and replenishment strategy"
    location: "https://www.energy.gov/ceser/articles/us-department-energy-announces-solicitation-purchase-oil-strategic-petroleum-1"
    quality_tier: A
    role: primary
  - type: government_energy_policy
    citation: "U.S. Department of Energy / CESER, Strategic Petroleum Reserve purchase solicitation"
    location: "https://www.energy.gov/ceser/articles/us-department-energy-announces-solicitation-purchase-oil-strategic-petroleum-7"
    quality_tier: A
    role: corroborating
sources:
  - "[[sources/DOE-WTI-SPR-REFILL-2024]]"
concepts:
  - "[[concepts/strategic-petroleum-reserve]]"
  - "[[concepts/policy-price-zone]]"
  - "[[concepts/wti-reclaim-bounce]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [structural, policy-price-zone, price-reclaim, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12755_XTI_SPR_REFILL_D1
period: D1
expected_trade_frequency: "D1 WTI SPR refill-zone reclaim sleeve; estimate 3-10 trades/year after policy-zone, reclaim, cooldown, spread, and framework filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS official DOE energy-policy source; R2 PASS deterministic D1 policy-zone reclaim entry with ATR stop, failed-reclaim exit, rebound exit, and time stop; R3 PASS XTIUSD.DWX; R4 PASS no ML, grid, martingale, or external runtime data."
expected_pf: 1.10
expected_dd_pct: 18.0
---

# DOE WTI SPR Refill-Zone Reclaim Bounce

## Source

- Source: [[sources/DOE-WTI-SPR-REFILL-2024]]
- Primary citation: U.S. Department of Energy / CESER, Strategic Petroleum
  Reserve purchase solicitations and replenishment strategy, URLs
  https://www.energy.gov/ceser/articles/us-department-energy-announces-solicitation-purchase-oil-strategic-petroleum-1
  and
  https://www.energy.gov/ceser/articles/us-department-energy-announces-solicitation-purchase-oil-strategic-petroleum-7.

## Concept

DOE public SPR replenishment communications create a visible structural demand
reference for crude purchases around the refill price zone. This card tests
whether WTI has a tradable low-frequency bounce when price probes that zone but
then reclaims it on a completed D1 bar.

The EA does not fetch DOE announcements, EIA inventory data, SPR stock data,
auction files, news, APIs, CSVs, or a policy calendar at runtime. DOE is used
only for official source lineage. The live mechanical signal comes from
Darwinex `XTIUSD.DWX` D1 OHLC bars and broker calendar time.

This is intended as a distinct commodity sleeve: it is not XAU/XAG ratio
reversion, not an XTI/XNG spread, not an XNG RSI/cumulation edge, not WTI WPSR,
not hurricane, not refinery turnaround, not OPEC meeting, not ETF roll, not
month/weekday seasonality, not driving/winter distillate, not CAD/oil, and not a
generic time-series momentum or reversal sleeve.

## Hypothesis

When WTI probes the DOE SPR refill price zone and then closes back above it, the
market may be absorbing supply in an area where policy demand is economically
and publicly visible. A long-only D1 reclaim entry, bounded by an ATR hard stop,
a failed-reclaim exit, a rebound-target exit, and a max-hold guard, may capture
structural support without importing external data into the tester.

## Rules

- Trade only `XTIUSD.DWX` on D1.
- Evaluate entries only on a new D1 bar.
- Use only magic slot 0.
- No entry if this EA already has an open `XTIUSD.DWX` position.
- No entry if the current spread exceeds `strategy_max_spread_points`.
- Load the prior completed D1 bar and ATR(`strategy_atr_period`).
- The prior D1 low must probe at or below
  `strategy_refill_zone_price + strategy_zone_buffer_price`.
- The prior D1 close must be at or above `strategy_refill_zone_price`.
- The prior D1 close must be no higher than `strategy_max_entry_price`.
- The prior D1 bar must be bullish: close greater than open.
- The prior close location within the bar range must be at least
  `strategy_min_close_location`.
- The reclaim distance from low to close must be at least
  `strategy_min_reclaim_atr` ATR.
- Enforce `strategy_cooldown_days` between entry signals.
- Enter BUY at market with an ATR hard stop.

## Risk

Backtests use `RISK_FIXED=1000` with `RISK_PERCENT=0`. The EA is long-only,
one-position-only, and uses a fixed ATR hard stop. No grid, martingale,
pyramiding, partial close, external feed, discretionary input, or ML component
is permitted.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC bars and broker calendar only.

## Entry Rules

- Load the prior completed D1 OHLC bar and ATR on each new D1 bar.
- Require `low <= strategy_refill_zone_price + strategy_zone_buffer_price`.
- Require `close >= strategy_refill_zone_price`.
- Require `close <= strategy_max_entry_price`.
- Require `close > open`.
- Require `(close - low) / (high - low) >= strategy_min_close_location`.
- Require `(close - low) / ATR >= strategy_min_reclaim_atr`.
- Enter BUY at market with an ATR hard stop.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit if the prior completed D1 close is at or above
  `strategy_rebound_exit_price`.
- Exit if the prior completed D1 close is below
  `strategy_failed_reclaim_price`.
- Exit after `strategy_max_hold_days` calendar days.
- Framework Friday close remains enabled.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when ATR or prior-bar state is unavailable.
- Framework news, kill-switch, magic, stress-reject, and Friday-close guards
  remain active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_refill_zone_price
  default: 79.00
  sweep_range: [77.00, 79.00, 80.00]
- name: strategy_zone_buffer_price
  default: 1.50
  sweep_range: [0.75, 1.50, 2.50]
- name: strategy_max_entry_price
  default: 81.00
  sweep_range: [80.00, 81.00, 82.50]
- name: strategy_rebound_exit_price
  default: 85.00
  sweep_range: [83.00, 85.00, 88.00]
- name: strategy_failed_reclaim_price
  default: 76.00
  sweep_range: [74.00, 76.00, 77.50]
- name: strategy_min_close_location
  default: 0.60
  sweep_range: [0.55, 0.60, 0.70]
- name: strategy_min_reclaim_atr
  default: 0.25
  sweep_range: [0.15, 0.25, 0.40]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.00, 2.75, 3.50]
- name: strategy_max_hold_days
  default: 12
  sweep_range: [8, 12, 18]
- name: strategy_cooldown_days
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from DOE. DOE is used only as official structural
lineage for an SPR refill-zone hypothesis. The edge claim is tested by the QM
Q02+ pipeline on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 3-10 trades/year when WTI probes and
  reclaims the refill zone.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: U.S. DOE / CESER SPR purchase and refill policy.
- [x] R2 mechanical: fixed D1 policy-zone reclaim rules, ATR stop,
  failed-reclaim exit, rebound exit, cooldown, and max-hold exit.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol matrix.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: this is a WTI SPR policy-zone reclaim sleeve, not the
  existing XAU/XAG, XTI/XNG, XNG RSI, WTI WPSR, hurricane, refinery, OPEC,
  roll, calendar, CAD/oil, or momentum/reversal family.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, and
  spread cap.
- trade_entry: prior D1 low probes refill zone and close reclaims it with
  bullish close-location and ATR-distance confirmation.
- trade_management: rebound exit, failed-reclaim exit, max-hold exit, and ATR
  hard stop.
- trade_close: framework Friday close and strategy exits.

## Pipeline History

- 2026-06-28: Card approved for build as `QM5_12755`.
