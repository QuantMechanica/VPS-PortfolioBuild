---
ea_id: QM5_12997
slug: xng-rig-fri-mom
type: strategy
strategy_id: BAKERHUGHES-XNG-RIGCOUNT-FRI-MOM-2026
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
  - "[[concepts/d1-event-momentum]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, official-release-window, n-period-max-continuation, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_12997_XNG_RIGCOUNT_FRI_MOM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 natural-gas last-workday rig-count displacement continuation; at most one entry per broker week, roughly 6-16 entries/year after displacement, ATR, close-location, and spread filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, xng_volatility, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS official Baker Hughes rig-count source packet covering oil and natural gas rigs; R2 PASS deterministic D1 first-new-week entry after a large last-workday XNG displacement with close-location confirmation, ATR stop, adverse-close exit, and time exit; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XNG Rig-Count Friday Momentum

## Hypothesis

Baker Hughes publishes the North America Rig Count each Friday at noon central
U.S. time and describes it as a weekly census of active rigs exploring for or
developing oil, natural gas, or geothermal energy. This card tests whether a
large directional `XNGUSD.DWX` D1 move on the final broker workday of the week,
used as the market response proxy around that release cadence, continues briefly
into the next broker week.

The EA does not parse Baker Hughes data or call any external feed at runtime. It
uses only Darwinex MT5 D1 bars, spread, broker calendar, ATR, and standard V5
framework state.

## Source

- Primary: Baker Hughes, "Rig Count Overview and Summary Count." URL:
  https://rigcount.bakerhughes.com/.
- Supplement: Baker Hughes, "Rig Count FAQ." URL:
  https://bakerhughesrigcount.gcs-web.com/rig-count-faqs.

## Concept

This is a natural-gas drilling-activity event-response sleeve. On the first D1
bar of a new broker week, the EA inspects the prior completed D1 bar. If that
bar was a large final-workday displacement, sized both by percent return and by
ATR, and it closed near the directional extreme, the EA follows continuation in
the same direction for a short holding window.

This is deliberately different from:

- `QM5_12858_rigcount-fri-mom` and `rigcount-fri-fade`: those trade WTI; this
  card trades natural gas with XNG volatility and spread limits.
- `QM5_12567_cum-rsi2-commodity`: no RSI, no oscillator pullback, no generic
  commodity mean-reversion rule.
- XNG storage, winter/summer/fall/shoulder, hurricane/freeze, LNG, Thursday
  storage-report, weekend, month, volshock-fade, and multiday-drift sleeves:
  different event clock and signal definition.
- XTI/XNG baskets, gas/gold, oil/gold, oil/silver, XAU/XAG, and metals-ratio
  logic: no basket, hedge ratio, or cross-asset spread.

## Markets And Timeframe

- Symbol: `XNGUSD.DWX`.
- Period: `D1`.
- Expected frequency: roughly 6-16 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker calendar, and V5
  framework state only.

## Rules

- Evaluate only on a new `XNGUSD.DWX` D1 bar.
- Trade only the first new-week D1 bar after the previous completed D1 bar.
- The previous completed D1 bar must have broker day-of-week >=
  `strategy_signal_min_dow`, normally the final workday of the broker week.
- Compute log return from the previous completed D1 close to the close before
  it.
- Require absolute return of at least `strategy_min_signal_return_pct`.
- Require absolute return of at least `strategy_min_atr_return_mult` times ATR
  expressed as percent of the signal-bar close.
- Reject moves above `strategy_max_signal_return_pct` to avoid extreme gap and
  data-error regimes.
- Long entry: signal-bar return is positive and the close is in the upper
  `strategy_close_location_min` portion of the signal bar's range.
- Short entry: signal-bar return is negative and the close is in the lower
  `strategy_close_location_min` portion of the signal bar's range.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- No profit target in v1.
- Close after `strategy_max_hold_days` calendar days.
- Close early if the latest completed D1 close moves against entry by
  `strategy_adverse_close_atr_mult` ATR.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Magic slot offset must be 0.
- Skip entries when D1 history, ATR, range, spread, entry price, or stop price
  is unavailable.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_min_signal_return_pct
  default: 1.20
  sweep_range: [0.90, 1.20, 1.60]
- name: strategy_min_atr_return_mult
  default: 0.50
  sweep_range: [0.40, 0.50, 0.70]
- name: strategy_max_signal_return_pct
  default: 12.0
  sweep_range: [9.0, 12.0, 16.0]
- name: strategy_close_location_min
  default: 0.62
  sweep_range: [0.58, 0.62, 0.70]
- name: strategy_signal_min_dow
  default: 4
  sweep_range: [4, 5]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.25, 2.75, 3.25]
- name: strategy_max_hold_days
  default: 3
  sweep_range: [2, 3, 5]
- name: strategy_adverse_close_atr_mult
  default: 0.85
  sweep_range: [0.60, 0.85, 1.10]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 4000]

## Author Claims

The source establishes a weekly official rig-count release cadence and a
natural-gas drilling-activity scope. This card imports no source performance
claim. Q02 and later phases must validate or reject the mechanical
`XNGUSD.DWX` realization on Darwinex bars.

## Risk

- expected_pf: 1.08.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 6-16 entries/year.
- risk_class: medium-high because natural gas gaps, roll behaviour, and
  weather-sensitive volatility require Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official Baker Hughes rig-count source and FAQ.
- [x] R2 mechanical: fixed new-week gate, final-workday return threshold,
  close-location confirmation, ATR stop, and deterministic time/adverse-close
  exits.
- [x] R3 testable: `XNGUSD.DWX` exists in the DWX symbol universe.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: no existing Baker Hughes natural-gas rig-count momentum
  sleeve; not XNG RSI, storage, freeze, hurricane, LNG, weekday/month,
  weekend, basket, or metal-ratio logic.

## Framework Alignment

- no_trade: XNG/D1 host guard, magic-slot guard, parameter guard, spread cap,
  and valid data checks.
- trade_entry: first-new-week continuation after large final-workday
  rig-count-cadence proxy displacement.
- trade_management: max-hold stale-position exit and adverse-close exit.
- trade_close: hard ATR stop plus deterministic strategy exits and framework
  Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-03 | initial Baker Hughes natural-gas rig-count Friday momentum card | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
