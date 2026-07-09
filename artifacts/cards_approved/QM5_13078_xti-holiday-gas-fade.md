---
ea_id: QM5_13078
slug: xti-holiday-gas-fade
type: strategy
strategy_id: EIA-GAS-HOLIDAY-PULLFORWARD-2018
source_id: EIA-GAS-HOLIDAY-PULLFORWARD-2018
source_citation: "U.S. Energy Information Administration, Today in Energy, Shipments to gas stations before certain holidays affect gasoline product supplied, 2018-08-30."
source_citations:
  - type: government_research
    citation: "U.S. Energy Information Administration. Shipments to gas stations before certain holidays affect gasoline product supplied. Today in Energy, 2018-08-30."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=36992"
    quality_tier: A
    role: primary
sources:
  - "[[sources/EIA-GAS-HOLIDAY-PULLFORWARD-2018]]"
concepts:
  - "[[concepts/gasoline-holiday-pull-forward]]"
  - "[[concepts/energy-demand-seasonality]]"
  - "[[concepts/post-event-fade]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, structural-demand, post-event-fade, trend-exhaustion, atr-hard-stop, atr-profit-target, time-stop, short-only, low-frequency, energy]
target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 WTI post-driving-holiday gasoline pull-forward fade; 3 trades/year from Memorial Day, Independence Day, and Labor Day after pre-holiday rally confirmation."
expected_trades_per_year_per_symbol: 3
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.06
expected_dd_pct: 18.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [holiday_calendar, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS single official EIA source; R2 PASS deterministic XTIUSD.DWX D1 post-driving-holiday short fade with pre-holiday rally confirmation, ATR stop/target, time exit, and spread cap; R3 PASS XTIUSD.DWX exists in the DWX matrix with D1 history; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate because it shorts only after Memorial Day/July 4/Labor Day gasoline pull-forward windows, not the existing broad preholiday long, WTI month/weekday seasonality, WPSR, Cushing, refinery, hurricane, COT, roll, OPEC, SPR, XTI/XNG, oil/metal, or commodity-RSI logic."
---

# XTI Post-Holiday Gasoline Pull-Forward Fade

## Source

- Source: [[sources/EIA-GAS-HOLIDAY-PULLFORWARD-2018]]
- Citation: U.S. Energy Information Administration, "Shipments to gas stations
  before certain holidays affect gasoline product supplied", Today in Energy,
  2018-08-30.
- URL: https://www.eia.gov/todayinenergy/detail.php?id=36992

## Concept

EIA describes holiday-linked swings in gasoline product supplied around U.S.
driving holidays and notes that retail stations often receive product before
holiday weekends so they can serve expected driver demand. This card expresses
that pull-forward as a price-only `XTIUSD.DWX` D1 post-event fade: if WTI has
rallied into Memorial Day, Independence Day, or Labor Day, the EA opens a short
on the first trading day after the holiday and exits after the demand window has
decayed or a risk boundary is hit.

This is deliberately different from:

- `QM5_1168_qp-oil-preholiday`: that EA buys broad holidays five trading days
  before the holiday and exits before it. This card enters only after the
  gasoline-driving holiday and is short-only.
- WTI calendar sleeves such as `wti-may-prem`, `wti-jul-prem`, `wti-sep-prem`,
  `wti-oct-fade`, `wti-nov-fade`, `wti-dec-fade`, weekday sleeves, and broad
  driving-season swing cards: this card is event-anchored to the first trading
  day after three U.S. driving holidays and requires a pre-holiday rally.
- WPSR, Cushing, refinery, hurricane, COT, roll, OPEC, IEA/JODI, SPR, PADD,
  product-stock, XTI/XNG, Brent/WTI, oil/metal, XNG, index, and commodity-RSI
  sleeves: no report release, external runtime feed, pair basket, or oscillator
  is used.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: 3 trades/year before spread and rally filters.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, broker calendar, spread, ATR, SMA, and V5
  framework state only. No EIA data, WPSR data, API, CSV, futures curve, analyst
  forecast, or ML model is consumed at runtime.

## Entry Rules

- Evaluate only on a new D1 bar of the `XTIUSD.DWX` host chart.
- Compute the current broker date and the current year's Memorial Day, observed
  Independence Day, and Labor Day.
- Entry date is the first scheduled trading day after one of those holidays.
- Only one entry is allowed per holiday date.
- Short entry only:
  - the prior completed D1 close is above `strategy_trend_period` SMA,
  - the D1 close before the holiday is at least `strategy_min_rally_atr` ATR
    above the close `strategy_rally_lookback_days` completed bars earlier,
  - the prior completed close is not below the holiday close by more than
    `strategy_max_post_drop_atr` ATR,
  - current spread is at or below `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) times
  `strategy_atr_sl_mult` above the short entry.
- Take profit: ATR(`strategy_atr_period`) times `strategy_atr_tp_mult` below the
  short entry.
- Close after `strategy_max_hold_days`.
- Close early if the prior completed D1 close is below the trend SMA by at least
  `strategy_mean_reclaim_atr` ATR.
- Friday close remains enabled by the V5 framework.

## Filters

- Only run from `XTIUSD.DWX` D1 with `qm_magic_slot_offset=0`.
- Skip if required holiday, D1, ATR, SMA, or spread state is unavailable.
- Skip if the configured holiday date has already been traded for this year.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding, grid, martingale, partial close, or trailing stop.
- One open short position per magic number.
- Management is limited to the deterministic time and mean-reclaim close.

## Parameters To Test

- name: strategy_rally_lookback_days
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_trend_period
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_rally_atr
  default: 0.70
  sweep_range: [0.45, 0.70, 1.00]
- name: strategy_max_post_drop_atr
  default: 1.25
  sweep_range: [0.75, 1.25, 1.75]
- name: strategy_mean_reclaim_atr
  default: 0.20
  sweep_range: [0.0, 0.20, 0.50]
- name: strategy_atr_sl_mult
  default: 2.60
  sweep_range: [2.0, 2.6, 3.4]
- name: strategy_atr_tp_mult
  default: 2.20
  sweep_range: [1.6, 2.2, 3.0]
- name: strategy_max_hold_days
  default: 7
  sweep_range: [4, 7, 10]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source packet establishes official structural lineage for gasoline
holiday-pull-forward behavior and product-supplied measurement quirks. No EIA
performance claim is imported into QM. Q02 and later phases must validate or
reject this mechanical Darwinex `XTIUSD.DWX` port.

## Initial Risk Profile

- expected_pf: 1.06.
- expected_dd_pct: 18.
- expected_trade_frequency: 3 trades/year before filters.
- risk_class: medium because the rule is intentionally sparse and energy gaps
  around holidays need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: single official EIA Today in Energy article.
- [x] R2 mechanical: fixed U.S. driving-holiday dates, pre-holiday rally filter,
  short-only entry, ATR hard stop/target, spread cap, time exit, and mean exit.
- [x] R3 testable: `XTIUSD.DWX` exists in the Darwinex symbol matrix with D1
  history.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: post-driving-holiday short fade, not broad preholiday long,
  not monthly/weekday WTI seasonality, not WPSR/product/PADD event logic, not
  XNG, not XTI basket/ratio logic, and not commodity RSI logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and a single `XTIUSD.DWX`
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Registry And Queue Notes

- Slot 0: `XTIUSD.DWX`.
- Q02 setfile: `QM5_13078_xti-holiday-gas-fade_XTIUSD.DWX_D1_backtest.set`.
- Keep Q02 setfile on `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Framework Alignment

- no_trade: host chart guard, D1 guard, parameter guard, spread cap, data
  availability, news, Friday close, and one-position-per-magic guard.
- trade_entry: D1 post-driving-holiday short after pre-holiday rally
  confirmation.
- trade_management: max-hold and mean-reclaim close.
- trade_close: framework hard stop/target and Friday close.

## Kill Criteria

Kill or recycle the card if Q02 cannot produce at least one valid post-holiday
trade, if Q02 PF is below 1.0 after costs, if the sparse holiday sample produces
unstable fill behavior, or if the post-holiday fade is materially correlated
with an existing WTI calendar sleeve.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-09 | initial WTI post-driving-holiday gasoline pull-forward fade build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
| Q01 Build Validation | 2026-07-09 | PENDING | `artifacts/qm5_13078_build_result.json` |
| Q02 Baseline Screening | 2026-07-09 | PENDING | enqueue after compile |
