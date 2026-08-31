---
card_schema_version: 2
type: strategy
strategy_id: YE-KARALI-EIA-WTI-LAG2-FADE-M5-2026_S01
variant_id: YE-KARALI-EIA-WTI-LAG2-FADE-M5-2026_S01
source_id: YE-KARALI-EIA-WTI-LAG2-FADE-M5-2026
ea_id: QM5_41243
slug: wti-eia-lag2-fade-m5
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41243_wti-eia-lag2-fade-m5_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41243_wti_eia_lag2_fade_m5_g0.md
source_approval: decisions/2026-08-31_wti_eia_lag2_fade_m5_source_approval.md
source_author: "Shiyu Ye; Berna Karali"
source_authors: "Shiyu Ye; Berna Karali"
source_citation: "Ye, Shiyu, and Karali, Berna (2016), The informational content of inventory announcements: Intraday evidence from crude oil futures market, Energy Economics 59, 349-364, DOI 10.1016/j.eneco.2016.08.011."
source_citations:
  - type: peer_reviewed_intraday_event_study
    citation: "Ye, S., and Karali, B. (2016). The informational content of inventory announcements: Intraday evidence from crude oil futures market. Energy Economics 59, 349-364."
    location: "https://doi.org/10.1016/j.eneco.2016.08.011"
    quality_tier: A
    role: five_minute_return_model_negative_first_and_second_lags_and_eia_event_response
  - type: complete_authors_conference_poster
    citation: "Ye, S., and Karali, B. (2015). The Informational Content of Inventory Announcements: Intraday Evidence from Crude Oil Futures Market. AAEA/WAEA poster."
    location: "https://ageconsearch.umn.edu/record/205595/files/AAEA_Ye_Karali-2015.pdf"
    quality_tier: A_bounded_complete
    role: release_clock_main_market_mover_and_intraday_jump_context
  - type: official_government_schedule
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report Schedule."
    location: "https://www.eia.gov/petroleum/supply/weekly/schedule.php"
    quality_tier: A
    role: standard_wednesday_1030_eastern_release_clock_and_holiday_exceptions
  - type: governed_bounded_source
    citation: "QuantMechanica WTI EIA lag-2 fade bounded extraction."
    location: "strategy-seeds/sources/YE-KARALI-EIA-WTI-LAG2-FADE-M5-2026/source.md"
    quality_tier: internal_governed_complete
    role: exact_price_proxy_risk_and_lifecycle_boundary
strategy_mechanic: xtiusd-standard-wednesday-eia-completed-m5-price-reaction-opposite-sign-lag2-fade-1035-to-1045-new-york
sources:
  - "[[sources/YE-KARALI-EIA-WTI-LAG2-FADE-M5-2026]]"
concepts:
  - "[[concepts/public-information-reaction]]"
  - "[[concepts/crude-oil-inventory-event]]"
  - "[[concepts/short-lag-return-reversal]]"
indicators:
  - "[[indicators/completed-m5-price-reaction]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, scheduled-event, reaction-fade, symmetric-long-short, same-session-exit, low-frequency, atr-hard-stop]
markets: [commodities, energy, crude_oil]
timeframes: [M5]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412430000
period: M5
timeframe: M5
execution_timeframe: M5
signal_timeframe: M5
direction: symmetric_opposite_completed_release_reaction
expected_trade_frequency: "Approximately 35-48 completed WTI positions per full year from one standard-Wednesday attempt and a low equality/missing-bar prior; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 44
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_TRANSLATION_AND_ACCESS_BOUNDARY
r1_reasoning: "A complete bounded review of accessible publisher material and the complete authors' poster for a named-author, DOI-bearing, peer-reviewed Energy Economics study directly supports an EIA five-minute return model with negative first and second lags. The paywalled journal PDF was not retrieved, and the M5 CFD return-sign fade is a disclosed QM translation rather than the paper's inventory-surprise variable."
r2_mechanical: PASS
r2_reasoning: "Exact DST-aware standard-Wednesday clock, completed M5 labels, strict opposite sign, consumed date, fixed risk, frozen stop, spread ceiling, and 10:45 exit are deterministic and locked."
r3_data_available: PASS
r3_qualification: CFD_MICROSTRUCTURE_HOLIDAY_AND_TIME_MAPPING_RISK
r3_reasoning: "The governed registry records XTIUSD.DWX M5 coverage for 2017-2025 on T1-T10, and native MT5 time, OHLC, quote, position, deal, and persistent state provide every runtime input. Futures/CFD basis, M5 aggregation, DST, gaps, spreads, and holiday-shift false labels remain binding."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed OHLC, strict comparisons, ATR risk control, quotes, positions, deals, and terminal state; no trained signal, banned signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid."
parameters_to_test: "Locked Q02 baseline only: standard Wednesday; 10:30 release-proxy M5 bar; 10:35 decision; strict opposite-sign fade; 30-second entry grace; ATR(20,M5)*3.0 frozen stop; 10:45 flat; twenty-minute stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: true
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_ENQUEUED
force_build: true
review_focus: "Falsify a WTI public-information reaction-fade sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact New York M5 labels, strict opposite completed-reaction sign, one-shot execution, fixed risk, frozen stop, and 10:45 flat. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, event_clock_dst, completed_release_proxy_bar, strict_opposite_sign, restart_safe_attempt, risk_mode_dual, hard_stop_present, same_session_flat, holiday_shift_false_label, futures_cfd_microstructure_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 reputable peer-reviewed Ye-Karali plus complete poster and EIA schedule with translation boundary; R2 exact M5 opposite-sign event fade; R3 governed XTI M5 history; R4 deterministic native arithmetic only; no exact semantic duplicate."
---

# QM5_41243 WTI EIA Five-Minute Lag-2 Reaction Fade

## Hypothesis

A peer-reviewed intraday study models five-minute crude-oil futures returns
around recurring inventory announcements and reports negative first- and
second-lag return coefficients. This card tests a deliberately simple native
CFD translation: after the completed standard-Wednesday 10:30-10:35 New York
M5 reaction, trade the opposite direction at 10:35 and flatten after two M5
lag intervals at 10:45.

This is a WTI event-microstructure candidate outside the certified
XAU/SP500/NDX/XNG carrier set. It is not evidence of profitability, low
correlation, or portfolio value. Only unchanged downstream gates may
establish those outcomes.

## Source Traceability And Claim Boundary

The source is Ye and Karali (2016), "The informational content of inventory
announcements: Intraday evidence from crude oil futures market," *Energy
Economics* 59, 349-364, DOI `10.1016/j.eneco.2016.08.011`. The exact standard
release clock comes from the U.S. EIA WPSR schedule.

Complete bounded source evidence is preserved in
`strategy-seeds/sources/YE-KARALI-EIA-WTI-LAG2-FADE-M5-2026/source.md` and
`decisions/2026-08-31_wti_eia_lag2_fade_m5_source_approval.md`.

The paper supports an EIA crude-futures information event, a five-minute
return model, and negative first/second return lags. It does not define a
single completed CFD candle as inventory news, prescribe an unconditional
opposite-sign order, or establish CFD profitability. The M5 proxy can
misclassify ordinary price moves, especially on holiday-shifted weeks. No
source performance statistic is an expected card result.

## Rules

On the first executable tick of the standard-Wednesday 10:35 New York M5 bar,
consume the New York date. Require the immediately preceding completed M5 bar
to be same-date, labeled 10:30 New York, and exactly 300 broker-time seconds
older.

```text
signal = SELL when release_close > release_open
         BUY  when release_close < release_open
         FLAT otherwise
```

Enter only in seconds 0-29 of 10:35, with one frozen hard stop and no target.
Close at the first tick at or after 10:45 New York.

## Markets And Timeframe

- Exact host and traded symbol: `XTIUSD.DWX`.
- Host, signal, and execution timeframe: M5.
- Symbol slot: 0; intended magic: `412430000`.
- Decision cadence: once per standard Wednesday.
- Expected cadence: approximately 35-48 completed positions/year; Q02 must
  prove at least five in every full scored year.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX`, M5, slot 0, and every locked input.
2. Convert broker timestamps through the V5 broker-to-UTC and U.S.-DST
   helpers to New York time.
3. Evaluate only on the first observed tick of a current Wednesday 10:35 New
   York M5 bar. Persist the New York `yyyymmdd` attempt before every fallible
   entry gate. No retry after rejection, restart, or stop-out.
4. Require the current tick's New York seconds to be 0-29 and the previous
   completed M5 bar to be same-date 10:30 with exactly 300 seconds between bar
   opens.
5. Require valid finite positive OHLC with high not below low and open/close
   inside the completed bar range.
6. Enter SELL when the completed close is strictly above the completed open.
   Enter BUY when it is strictly below. Equality is flat.
7. Reject an owned position, crossed or negative quote, or a genuinely
   positive spread above 1,500 points. A modeled zero spread is valid.
8. Compute ATR(20,M5) on the completed release-proxy bar and attach a frozen
   `3.0 * ATR` normalized broker hard stop. No take-profit.
9. Use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Signal magnitude never sizes risk.

## 5. Exit Rules

- Close on the first tick at or after 10:45 New York on the entry date.
- Close if the New York date differs from the entry date.
- Close after twenty elapsed minutes as a survivor repair.
- Close duplicate, wrong-symbol, wrong-direction for the persisted entry
  state, wrong-magic, or stopless owned exposure immediately.
- Framework kill-switch and Friday closure remain authoritative.
- No target, trailing stop, break-even move, partial exit, or signal reversal.

## 6. Filters (No-Trade Module)

- Exact symbol/timeframe/slot and exact parameter locks.
- Both current news axes and legacy news mode are OFF because WPSR is the
  strategy event and runtime external calendars are forbidden.
- Standard Wednesday only; shifted holiday releases are not inferred or
  traded on their shifted day. The ordinary Wednesday proxy can be false in a
  holiday week and remains a declared kill risk.
- History, labels, time separation, OHLC, sign, quote, spread, ATR, position,
  and attempt checks fail closed.

## 7. Trade Management Rules

- At most one owned position and one consumed attempt per New York date.
- Same-session lifecycle checks run every tick before entry-only filters.
- No retry, reversal, pending order, scale-in, pyramid, grid, martingale,
  partial close, adaptive parameter, external runtime input, trained signal,
  or portfolio-state dependency.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| parameter | value | role |
|---|---:|---|
| `strategy_release_hhmm_ny` | 1030 | completed proxy-bar label |
| `strategy_decision_hhmm_ny` | 1035 | opposite-sign decision |
| `strategy_flat_hhmm_ny` | 1045 | two five-minute lags after entry |
| `strategy_entry_grace_seconds` | 30 | late-attach ceiling |
| `strategy_atr_period_m5` | 20 | completed M5 risk estimator |
| `strategy_atr_stop_multiple` | 3.0 | frozen hard-stop distance |
| `strategy_max_hold_minutes` | 20 | survivor repair only |
| `strategy_max_spread_points` | 1500 | entry ceiling |

Changing the clock, sign, direction, grace, risk, stop, hold, or spread
requires a new source decision and card. There is no after-result rescue
parameter.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_eia_lag2_fade_m5_preallocation_dedup_20260831.json`,
SHA-256
`856BD94846ADB0A82E31D6FD899F69DE285AA410511E2AF006FB7C764278BF44`,
contains no exact match across 4,742 registry rows, 1,380 cards, and 45
Strategy Wiki nodes. Generic `fade` token matches resolve to different
calendar and event mechanics.

No built WPSR system combines opposite sign to the completed 10:30 M5
reaction, a 10:35 entry, and a 10:45 exit. The existing nearest systems decide
before the release, in the final session window, from D1 state, after a deep
M30 reclaim, or follow a negative M1 reaction until 10:35.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_STANDARD_WEDNESDAY_COMPLETED_M5_REACTION_LAG2_FADE`.

## Risk And Falsification

This is a high-risk translation. A small regression lag, price-proxy
misclassification, holiday shifts, M5 aggregation, spreads, gaps, slippage,
DST mapping, and CFD/futures basis can eliminate the effect. `expected_pf=1.01`
and cadence are queue-ordering priors, not evidence.

Q02 must retire the unchanged baseline on zero positions, fewer than five in
any full scored year, nonpositive governed economics, invalid risk mode,
wrong bar/clock, same-side entry, repeated entry, missing stop, wrong exit, or
nondeterminism. Q09 alone may measure overlap with the certified book.

Only one `RISK_FIXED` backtest setfile is authorized. No live, demo, shadow,
stress, or optimization preset; AutoTrading action; `T_Live`; deploy or live
manifest; portfolio-gate edit; portfolio admission; decorrelation claim; or
correlation waiver is authorized.

## Framework Alignment

- no_trade: exact host, slot, parameters, framework kill switch, and
  fail-closed validation.
- trade_entry: DST-aware event labels, persistent attempt, exact completed M5
  proxy, strict opposite sign, quote/spread/ATR gates, and fixed-risk request.
- trade_management: malformed-state repair plus every-tick 10:45, date-change,
  and stale closure before entry-only gates.
- trade_close: owned tickets close through the framework transaction manager;
  the broker hard stop is the intrabar backstop.

## Falsification And Pipeline Status

Passing Q02 would establish only executable baseline evidence. It would not
validate the price proxy, source-to-CFD equivalence, profitability,
robustness, low correlation, or portfolio admission.

| Phase | Date | Verdict | Evidence |
|---|---|---|---|
| Source Approval | 2026-08-31 | APPROVED_SOURCE | `decisions/2026-08-31_wti_eia_lag2_fade_m5_source_approval.md` |
| G0 | 2026-08-31 | APPROVED | `decisions/2026-08-31_qm5_41243_wti_eia_lag2_fade_m5_g0.md` |
| Q01 | 2026-08-31 | PENDING | build not yet recorded |
| Q02 | 2026-08-31 | NOT_ENQUEUED | requires strict Q01 PASS and clear CPU window |
