---
ea_id: QM5_13000
slug: xng-rig-fri-fade
type: strategy
strategy_id: BAKERHUGHES-XNG-RIGCOUNT-FRI-FADE-2026
source_id: BAKERHUGHES-RIGCOUNT-2026
source_citation: "Baker Hughes. Rig Count Overview and Summary Count; Baker Hughes Rig Count FAQ. URLs https://rigcount.bakerhughes.com/ and https://bakerhughesrigcount.gcs-web.com/rig-count-faqs."
source_citations:
  - type: official_industry_data
    citation: "Baker Hughes. North America Rig Count Overview and Summary Count."
    location: "https://rigcount.bakerhughes.com/"
    quality_tier: A
    role: primary
  - type: official_faq
    citation: "Baker Hughes. Rig Count FAQ."
    location: "https://bakerhughesrigcount.gcs-web.com/rig-count-faqs"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/BAKERHUGHES-RIGCOUNT-2026]]"
concepts:
  - "[[concepts/natural-gas-drilling-activity]]"
  - "[[concepts/weekly-official-release-window]]"
  - "[[concepts/d1-event-exhaustion-fade]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, official-release-window, n-period-min-reversion, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_13000_XNG_RIGCOUNT_FRI_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 natural-gas last-workday rig-count displacement exhaustion fade; at most one entry per broker week, roughly 5-14 entries/year after displacement, ATR, close-location, and spread filters."
expected_trades_per_year_per_symbol: 9
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.07
expected_dd_pct: 22.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, xng_volatility, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS official Baker Hughes rig-count source packet; R2 PASS deterministic D1 first-new-week fade after a large final-workday XNG displacement with close-location confirmation, ATR stop, favorable/adverse closed-bar exits, and time exit; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate versus QM5_12567 because this is a Baker Hughes weekly release-cadence exhaustion fade, not RSI2 commodity pullback logic."
---

# XNG Rig-Count Friday Fade

## Source

- Source: [[sources/BAKERHUGHES-RIGCOUNT-2026]]
- Primary citation: Baker Hughes Rig Count Overview and Summary Count,
  https://rigcount.bakerhughes.com/.
- Supplement: Baker Hughes Rig Count FAQ,
  https://bakerhughesrigcount.gcs-web.com/rig-count-faqs.

## Concept

Baker Hughes publishes the North America Rig Count weekly, normally Friday at
noon central U.S. time, and describes the count as a petroleum-industry activity
barometer. This card treats the completed final-workday `XNGUSD.DWX` D1 bar as
the market response proxy around that cadence.

The edge is a short-horizon natural-gas exhaustion sleeve. When the final
broker-week D1 bar posts an unusually large directional move and closes near
that bar's extreme, the EA enters opposite the move on the first D1 bar of the
new broker week. The position exits on short reversion, adverse continuation,
time stop, ATR hard stop, or the standard V5 Friday-close guard.

This is deliberately different from:

- `QM5_12997_xng-rig-fri-mom`: same source cadence but opposite entry side.
  That card follows the displacement; this card fades only extended closes and
  uses a favorable-reversion exit.
- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or generic commodity
  pullback rule is used.
- XNG storage, winter/summer/fall/shoulder, hurricane/freeze, LNG, Thursday
  storage-report, weekend, month, volshock, and multiday-drift sleeves: this
  card uses a Baker Hughes weekly rig-count cadence and final-workday price
  reaction proxy.
- XTI/XNG, gas/gold, oil/gold, oil/silver, XAU/XAG, Brent, WTI, index, and
  metals-ratio logic: no basket, hedge ratio, or cross-asset spread is used.

## Markets And Timeframe

- Target symbol: `XNGUSD.DWX`.
- Period: `D1`.
- Expected frequency: roughly 5-14 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker calendar, and V5
  framework state only. No Baker Hughes download, EIA feed, futures curve,
  CSV, API, analyst forecast, discretionary override, or ML model is used at
  runtime.

## Entry Rules

- Evaluate only on a new `XNGUSD.DWX` D1 bar.
- Require the current D1 bar to be the first trading bar of a new broker week.
- Use the prior completed D1 bar as the rig-count reaction proxy.
- The prior bar must be the last workday of the prior broker week; accepted
  day-of-week values are Thursday or Friday to allow market holidays.
- Compute `signal_return_pct = 100 * ln(Close[1] / Close[2])`.
- Compute `atr_pct = 100 * ATR(strategy_atr_period)[1] / Close[1]`.
- Require `abs(signal_return_pct) >= strategy_min_signal_return_pct`.
- Require `abs(signal_return_pct) >= strategy_min_atr_return_mult * atr_pct`.
- Skip if `abs(signal_return_pct) > strategy_max_signal_return_pct`.
- For a short fade after an up displacement, require `Close[1]` to be in the
  top `strategy_close_location_min` fraction of the signal bar range.
- For a long fade after a down displacement, require `Close[1]` to be in the
  bottom `strategy_close_location_min` fraction of the signal bar range.
- Skip if an open `XNGUSD.DWX` position already exists for this EA magic.
- Skip if spread exceeds `strategy_max_spread_points`.
- Enter SELL after a qualifying positive last-workday displacement.
- Enter BUY after a qualifying negative last-workday displacement.

## Exit Rules

- Stop loss: ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close after `strategy_max_hold_days` calendar days.
- Close a long if a completed D1 close has moved at least
  `strategy_reversion_close_atr_mult * ATR(strategy_atr_period)` above the
  entry price.
- Close a short if a completed D1 close has moved at least
  `strategy_reversion_close_atr_mult * ATR(strategy_atr_period)` below the
  entry price.
- Close early if a completed D1 close continues against the fade beyond
  `strategy_adverse_close_atr_mult * ATR(strategy_atr_period)`.
- Friday Close remains enabled by the V5 framework.

## Filters

- Host chart must be `XNGUSD.DWX` on D1.
- Magic slot must be 0.
- Skip entries when D1 history, ATR, range, spread, entry price, or stop price
  is unavailable.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short single-symbol sleeve.
- One open position per magic/symbol.
- No pyramiding, gridding, martingale, partial close, or trailing stop.
- Time stop, favorable-reversion exit, and adverse-continuation exit are checked
  on completed D1 bars.

## Parameters To Test

- name: strategy_min_signal_return_pct
  default: 1.40
  sweep_range: [1.00, 1.40, 1.90]
- name: strategy_min_atr_return_mult
  default: 0.55
  sweep_range: [0.40, 0.55, 0.75]
- name: strategy_max_signal_return_pct
  default: 14.0
  sweep_range: [10.0, 14.0, 18.0]
- name: strategy_close_location_min
  default: 0.68
  sweep_range: [0.60, 0.68, 0.78]
- name: strategy_signal_min_dow
  default: 4
  sweep_range: [4, 5]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.00
  sweep_range: [2.50, 3.00, 3.75]
- name: strategy_max_hold_days
  default: 3
  sweep_range: [2, 3, 5]
- name: strategy_reversion_close_atr_mult
  default: 0.90
  sweep_range: [0.60, 0.90, 1.20]
- name: strategy_adverse_close_atr_mult
  default: 0.90
  sweep_range: [0.60, 0.90, 1.20]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 4000]

## Author Claims

No performance claim is imported from Baker Hughes. The source provides
structural lineage: weekly rig-count release cadence and rig count as an
industry activity barometer. Q02 and later phases must validate whether the
Darwinex `XNGUSD.DWX` price-reaction proxy has tradable exhaustion-fade value.

## Initial Risk Profile

- expected_pf: 1.07.
- expected_dd_pct: 22.
- expected_trade_frequency: approximately 5-14 entries/year on D1.
- risk_class: medium-high because natural gas gaps, roll behaviour, weather
  sensitivity, and sparse event-response samples require Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official Baker Hughes rig-count source packet.
- [x] R2 mechanical: fixed new-week gate, fixed final-workday displacement and
  close-location rules, ATR stop, favorable/adverse closed-bar exits, and time
  exit.
- [x] R3 testable: `XNGUSD.DWX` exists in the DWX symbol universe.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: not `QM5_12567` RSI2 pullback, not `QM5_12997` continuation,
  not XNG storage/freeze/hurricane/LNG/month/weekday/weekend logic, and not an
  energy or metals ratio basket.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XNGUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: host/timeframe guard, magic-slot guard, parameter guard, spread cap,
  first-new-week gate, and last-workday signal quality checks.
- trade_entry: D1 XNG exhaustion fade after a large completed final-workday
  Baker Hughes release-cadence reaction proxy bar.
- trade_management: max-hold, favorable reversion, and adverse-continuation
  exits.
- trade_close: ATR hard stop plus deterministic time/favorable/adverse exits
  and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-03 | initial Baker Hughes XNG rig-count Friday fade build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
| Q01 Build Validation | TBD | TBD | TBD |
| Q02 Baseline Screening | TBD | TBD | TBD |
