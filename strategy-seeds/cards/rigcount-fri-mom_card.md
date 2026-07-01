---
ea_id: QM5_12858
slug: rigcount-fri-mom
type: strategy
strategy_id: BAKERHUGHES-RIGCOUNT-FRI-MOM-2026
source_id: BAKERHUGHES-RIGCOUNT-2026
source_citation: "Baker Hughes. Rig Count Overview and Summary Count. URL https://rigcount.bakerhughes.com/; Baker Hughes Rig Count FAQ. URL https://bakerhughesrigcount.gcs-web.com/rig-count-faqs"
source_citations:
  - type: official_industry_data
    citation: "Baker Hughes. Rig Count Overview and Summary Count; Baker Hughes Rig Count FAQ."
    location: "Rig Count overview lines covering release cadence and industry-barometer role; FAQ North America report description."
    quality_tier: A
    role: primary
sources:
  - "[[sources/BAKERHUGHES-RIGCOUNT-2026]]"
concepts:
  - "[[concepts/rig-count-supply-signal]]"
  - "[[concepts/weekly-event-continuation]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, n-period-max-continuation, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12858_XTI_RIGCOUNT_FRI_MOM_D1
period: D1
expected_trade_frequency: "D1 WTI last-workday rig-count displacement continuation; estimate 8-18 trades/year after return, close-location, spread, and framework filters."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
expected_pf: 1.08
expected_dd_pct: 16.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine, news_pause_default]
g0_approval_reasoning: "R1 PASS official Baker Hughes rig-count source packet; R2 PASS deterministic D1 first-new-week entry after large last-workday WTI displacement with close-location confirmation, ATR stop, and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# Baker Hughes Rig-Count Friday Momentum

## Source

- Source: [[sources/BAKERHUGHES-RIGCOUNT-2026]]
- Primary citation: Baker Hughes Rig Count Overview and Summary Count,
  https://rigcount.bakerhughes.com/; Baker Hughes Rig Count FAQ,
  https://bakerhughesrigcount.gcs-web.com/rig-count-faqs.

## Concept

Baker Hughes publishes the North America rig-count report weekly on the last
workday, normally Friday at noon central U.S. time. The rig count is a drilling
activity and petroleum-industry barometer. This card treats the completed
last-workday `XTIUSD.DWX` D1 bar as the market's price-reaction proxy to that
weekly supply-information event.

The edge is a short-horizon continuation sleeve: when WTI closes the final
broker-week bar with a large directional move and near that day's extreme, enter
in the same direction at the first bar of the new broker week and exit after a
few D1 bars or an ATR hard stop.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or generic pullback.
- WTI weekday/month sleeves such as Monday fade, Friday premium, October/November
  fades, and fixed monthly premia: this card requires a large last-workday
  displacement and close-location confirmation, not a static calendar side.
- WTI weekend gap bounce/fade sleeves: this card does not use the weekend gap.
  The signal is the previous completed last-workday bar's displacement.
- WPSR, Cushing, refinery, hurricane, OPEC, SPR, expiry, ETF-roll, driving-season,
  distillate, jet-fuel, Brent/WTI, XTI/XNG, oil/gold, oil/silver, XAU/XAG, and
  XNG sleeves: no event data, ratio, season map, storage, futures curve, or
  multi-leg basket is used.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected frequency: about 8-18 trades/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ATR, broker calendar, and V5
  framework state only. No Baker Hughes download, EIA feed, futures curve,
  volume, open interest, CSV, API, alternative data, or ML model at runtime.

## Entry Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Require the current D1 bar to be the first trading bar of a new broker week.
- Use the prior completed D1 bar as the rig-count reaction proxy.
- The prior bar must be the last workday of the prior broker week; accepted
  day-of-week values are Thursday or Friday to allow market holidays.
- Compute `signal_return_pct = 100 * ln(Close[1] / Close[2])`.
- Compute `atr_pct = 100 * ATR(strategy_atr_period)[1] / Close[1]`.
- Require `abs(signal_return_pct) >= strategy_min_signal_return_pct`.
- Require `abs(signal_return_pct) >= strategy_min_atr_return_mult * atr_pct`.
- Skip if `abs(signal_return_pct) > strategy_max_signal_return_pct`.
- For a long signal, require `Close[1]` to be in the top
  `strategy_close_location_min` fraction of the signal bar range.
- For a short signal, require `Close[1]` to be in the bottom
  `strategy_close_location_min` fraction of the signal bar range.
- Skip if an open `XTIUSD.DWX` position already exists for this EA magic.
- Skip if spread exceeds `strategy_max_spread_points`.
- Enter BUY after a qualifying positive last-workday displacement.
- Enter SELL after a qualifying negative last-workday displacement.

## Exit Rules

- Hard stop: ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close after `strategy_max_hold_days` calendar days.
- Close early if a completed D1 close reverses beyond
  `strategy_adverse_close_atr_mult * ATR(strategy_atr_period)` against the entry
  price.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- No pyramiding, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short single-symbol sleeve.
- One open position per magic/symbol.
- Time stop and adverse-close exit are checked on closed D1 bars.
- No external runtime data is read.

## Parameters To Test

- name: strategy_min_signal_return_pct
  default: 0.80
  sweep_range: [0.60, 0.80, 1.10, 1.50]
- name: strategy_min_atr_return_mult
  default: 0.45
  sweep_range: [0.35, 0.45, 0.60, 0.80]
- name: strategy_max_signal_return_pct
  default: 8.0
  sweep_range: [6.0, 8.0, 12.0]
- name: strategy_close_location_min
  default: 0.60
  sweep_range: [0.55, 0.60, 0.70]
- name: strategy_signal_min_dow
  default: 4
  sweep_range: [4, 5]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.50
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_max_hold_days
  default: 3
  sweep_range: [2, 3, 5]
- name: strategy_adverse_close_atr_mult
  default: 0.75
  sweep_range: [0.50, 0.75, 1.00]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from Baker Hughes. The source provides
structural lineage: weekly rig-count release cadence and rig count as an
industry activity barometer. Q02 and later phases must validate whether the
Darwinex `XTIUSD.DWX` price-reaction proxy has tradable continuation value.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 16.
- expected_trade_frequency: approximately 8-18 trades/year on D1.
- risk_class: medium for crude-oil event/overnight gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official Baker Hughes rig-count source packet.
- [x] R2 mechanical: fixed new-week gate, fixed last-workday displacement and
  close-location rules, ATR stop, adverse-close exit, and time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  no pyramiding, one position per magic.
- [x] Non-duplicate: not RSI commodity logic, not a static WTI weekday/month
  anomaly, not a weekend-gap rule, not WPSR/Cushing/refinery/hurricane/OPEC/SPR/
  expiry/ETF-roll/seasonality, and not an energy or metals ratio basket.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` setfile.
Live risk is intentionally not configured here; any future live allocation must
come from the portfolio process. The EA does not touch `T_Live`, AutoTrading,
deploy manifests, portfolio admission, or the portfolio gate.

## Framework Alignment

- no_trade: host/timeframe guard, magic-slot guard, parameter guard, spread cap,
  first-new-week gate, and last-workday signal quality checks.
- trade_entry: D1 WTI continuation after a large completed last-workday
  rig-count reaction proxy bar.
- trade_management: max-hold and adverse-close exits.
- trade_close: ATR hard stop plus deterministic time/adverse-close exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-01 | initial Baker Hughes rig-count Friday momentum build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | TBD | `artifacts/qm5_12858_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` |
