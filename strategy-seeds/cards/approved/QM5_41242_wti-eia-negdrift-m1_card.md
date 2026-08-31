---
card_schema_version: 2
type: strategy
strategy_id: ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026_S01
variant_id: ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026_S01
source_id: ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026
ea_id: QM5_41242
slug: wti-eia-negdrift-m1
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41242_wti-eia-negdrift-m1_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41242_wti_eia_negative_drift_m1_g0.md
source_approval: decisions/2026-08-31_wti_eia_negative_drift_m1_source_approval.md
source_author: "Will J. Armstrong; Laura Cardella; Nasim Sabah"
source_authors: "Will J. Armstrong; Laura Cardella; Nasim Sabah"
source_citation: "Armstrong, Cardella, and Sabah (2021), Information shocks, disagreement, and drift, Journal of Financial Economics 140(3), 916-940, DOI 10.1016/j.jfineco.2021.02.002."
source_citations:
  - type: peer_reviewed_event_study
    citation: "Armstrong, W. J., Cardella, L., and Sabah, N. (2021). Information shocks, disagreement, and drift. Journal of Financial Economics 140(3), 916-940."
    location: "https://doi.org/10.1016/j.jfineco.2021.02.002"
    quality_tier: A
    role: negative_only_five_minute_crude_futures_information_drift
  - type: official_government_schedule
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report Schedule."
    location: "https://www.eia.gov/petroleum/supply/weekly/schedule.php"
    quality_tier: A
    role: standard_wednesday_1030_eastern_release_clock_and_holiday_exceptions
  - type: governed_bounded_source
    citation: "QuantMechanica WTI EIA negative-drift bounded extraction."
    location: "strategy-seeds/sources/ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026/source.md"
    quality_tier: internal_governed_complete
    role: exact_price_proxy_risk_and_lifecycle_boundary
strategy_mechanic: xtiusd-standard-wednesday-eia-negative-first-minute-price-reaction-proxy-short-continuation-1031-to-1035-new-york
sources:
  - "[[sources/ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026]]"
concepts:
  - "[[concepts/public-information-drift]]"
  - "[[concepts/crude-oil-inventory-event]]"
  - "[[concepts/asymmetric-price-discovery]]"
indicators:
  - "[[indicators/completed-m1-price-reaction]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, scheduled-event, negative-news-proxy, short-only, same-session-exit, low-frequency, atr-hard-stop]
markets: [commodities, energy, crude_oil]
timeframes: [M1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412420000
period: M1
timeframe: M1
execution_timeframe: M1
signal_timeframe: M1
direction: short_only
expected_trade_frequency: "Approximately 15-30 completed WTI positions per full year from one standard-Wednesday attempt and a roughly half-sign prior; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 22
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_PRICE_PROXY_AND_ACCESS_BOUNDARY
r1_reasoning: "A complete bounded review of accessible publisher and abstract material for a named-author, DOI-bearing, peer-reviewed JFE study directly supports negative-only five-minute crude-futures drift. The full article was not retrieved, and the M1 CFD return sign is a disclosed QM proxy rather than the paper's inventory-surprise variable."
r2_mechanical: PASS
r2_reasoning: "Exact DST-aware standard-Wednesday clock, completed M1 labels, strict negative sign, consumed date, short direction, fixed risk, frozen stop, spread ceiling, and 10:35 exit are deterministic and locked."
r3_data_available: PASS
r3_qualification: CFD_MICROSTRUCTURE_HOLIDAY_AND_TIME_MAPPING_RISK
r3_reasoning: "Governed XTIUSD.DWX M1 history covers 2017-2025, and native MT5 time, OHLC, quote, position, deal, and persistent state provide every runtime input. Futures/CFD basis, M1 aggregation, DST, gaps, spreads, and holiday-shift false labels remain binding."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed OHLC, strict comparisons, ATR risk control, quotes, positions, deals, and terminal state; no trained signal, banned signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid."
parameters_to_test: "Locked Q02 baseline only: standard Wednesday; 10:30 release-proxy bar; 10:31 decision; strict close<open SELL; 30-second entry grace; ATR(20,M1)*3.0 frozen stop; 10:35 flat; ten-minute stale repair; 1500-point spread ceiling."
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
review_focus: "Falsify a negative-only WTI information-drift sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact New York M1 labels, strict first-minute sign proxy, short-only one-shot execution, fixed risk, frozen stop, and 10:35 flat. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, event_clock_dst, completed_release_proxy_bar, strict_negative_sign, short_only, restart_safe_attempt, risk_mode_dual, hard_stop_present, same_session_flat, holiday_shift_false_label, futures_cfd_microstructure_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41242_wti_eia_negative_drift_m1_g0.md: R1 passes with an explicit source-access and first-minute price-proxy boundary; R2 locks clock, bar labels, sign, attempt, direction, risk, stop, spread, and exit; R3 binds the rule to governed WTI M1 history; R4 uses deterministic native arithmetic only. Canonical dedup is clean and manual event-family review separates the first-minute negative-only window from every built WPSR neighbor."
---

# QM5_41242 WTI EIA Negative Drift M1

## Hypothesis

Peer-reviewed evidence reports that negative EIA information is incorporated
into crude-oil futures prices with a five-minute drift, while positive news is
reflected almost immediately. This card tests whether a native CFD price-only
proxy can capture the remaining four minutes: after a strictly negative
10:30-10:31 New York M1 reaction, enter short at 10:31 and flatten at 10:35.

This is a direct WTI event-microstructure candidate outside the certified
XAU/SP500/NDX/XNG carrier set. It is not evidence of profitability, low
correlation, or portfolio value. Only unchanged downstream gates may establish
those outcomes.

## Source Traceability And Claim Boundary

The source is Armstrong, Cardella, and Sabah (2021), "Information shocks,
disagreement, and drift," *Journal of Financial Economics* 140(3), 916-940,
DOI `10.1016/j.jfineco.2021.02.002`. The official standard release clock comes
from the U.S. EIA WPSR schedule.

Complete bounded source evidence is preserved in
`strategy-seeds/sources/ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026/source.md` and
`decisions/2026-08-31_wti_eia_negative_drift_m1_source_approval.md`.

The paper supports a negative-only five-minute drift after inventory news in
crude futures. It does not define first-minute CFD return as news, test a
10:31 order, test the remaining four minutes, or establish CFD profitability.
The proxy can misclassify ordinary price moves, especially on holiday-shifted
weeks. No source performance statistic is an expected card result.

## Rules

On the first executable tick of the standard-Wednesday 10:31 New York M1 bar,
consume the New York date. Require the immediately preceding completed M1 bar
to be same-date, labeled 10:30 New York, and exactly 60 broker-time seconds
older.

```text
signal = SELL when release_close < release_open
         FLAT otherwise
```

Enter only in seconds 0-29 of 10:31, with one frozen hard stop and no target.
Close at the first tick at or after 10:35 New York.

## Markets And Timeframe

- Exact host and traded symbol: `XTIUSD.DWX`.
- Host, signal, and execution timeframe: M1.
- Symbol slot: 0; intended magic: `412420000`.
- Decision cadence: once per standard Wednesday.
- Expected cadence: approximately 15-30 completed positions/year; Q02 must
  prove at least five in every full scored year.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX`, M1, slot 0, and every locked input.
2. Convert broker timestamps through V5 broker-to-UTC and U.S.-DST helpers to
   New York time.
3. Evaluate only on the first observed tick of a current Wednesday 10:31 New
   York M1 bar. Persist the New York `yyyymmdd` attempt before every fallible
   entry gate. No retry after rejection, restart, or stop-out.
4. Require the current tick's New York seconds to be 0-29 and the previous
   completed M1 bar to be same-date 10:30 with exactly 60 seconds between bar
   opens.
5. Require valid finite positive OHLC with high not below low and open/close
   inside the bar range.
6. Stay flat unless completed close is strictly below completed open. Equality
   and a positive bar are flat. Enter SELL only.
7. Reject an owned position, crossed/negative quote, or a genuinely positive
   spread above 1,500 points. A modeled zero spread is valid.
8. Compute ATR(20,M1) on the completed release-proxy bar and attach a frozen
   `3.0 * ATR` normalized broker hard stop. No take-profit.
9. Use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Signal magnitude never sizes risk.

## 5. Exit Rules

- Close on the first tick at or after 10:35 New York on the entry date.
- Close if the New York date differs from the entry date.
- Close after ten elapsed minutes as a survivor repair.
- Close duplicate, wrong-symbol, non-SELL, wrong-magic, or stopless owned
  exposure immediately.
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
| `strategy_decision_hhmm_ny` | 1031 | first post-proxy decision |
| `strategy_flat_hhmm_ny` | 1035 | end of source drift window |
| `strategy_entry_grace_seconds` | 30 | late-attach ceiling |
| `strategy_atr_period_m1` | 20 | completed M1 risk estimator |
| `strategy_atr_stop_multiple` | 3.0 | frozen hard-stop distance |
| `strategy_max_hold_minutes` | 10 | survivor repair only |
| `strategy_max_spread_points` | 1500 | entry ceiling |

Changing the clock, sign, direction, grace, risk, stop, hold, or spread
requires a new source decision and card. There is no after-result rescue
parameter.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_eia_negdrift_m1_preallocation_dedup_20260831.json`,
SHA-256
`0421E9B96BF80F46439170824993450BB335BAE6297DE933CEFADF416090133C`,
is clean across 4,741 registry rows, 1,379 cards, and 45 Strategy Wiki nodes.

No built WPSR system combines negative-only direction, the first completed M1
reaction, a 10:31 entry, and a 10:35 exit. The existing nearest systems decide
before the release, hours later, from D1 state, or after two completed M30
bars.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_STANDARD_WEDNESDAY_NEGATIVE_FIRST_MINUTE_REACTION_SHORT_DRIFT`.

## Risk And Falsification

This is a high-risk translation. Price-proxy misclassification, holiday
shifts, M1 aggregation, spreads, gaps, slippage, DST mapping, CFD/futures
basis, and a very short holding interval can eliminate the effect.
`expected_pf=1.01` and cadence are queue-ordering priors, not evidence.

Q02 must retire the unchanged baseline on zero positions, fewer than five in
any full scored year, nonpositive governed economics, invalid risk mode,
wrong bar/clock, wrong direction, repeated entry, missing stop, wrong exit, or
nondeterminism. Q09 alone may measure overlap with the certified book.

Only one `RISK_FIXED` backtest setfile is authorized. No live, demo, shadow,
stress, or optimization preset; AutoTrading action; `T_Live`; deploy or live
manifest; portfolio-gate edit; portfolio admission; decorrelation claim; or
correlation waiver is authorized.

## Framework Alignment

- no_trade: exact host, slot, parameters, framework kill switch, and
  fail-closed validation.
- trade_entry: DST-aware event labels, persistent attempt, exact completed M1
  proxy, strict negative sign, quote/spread/ATR gates, and fixed-risk request.
- trade_management: malformed-state repair plus every-tick 10:35, date-change,
  and stale closure before entry-only gates.
- trade_close: owned tickets close through the framework transaction manager;
  the broker hard stop is the intraminute backstop.

## Falsification And Pipeline Status

Passing Q02 would establish only executable baseline evidence. It would not
validate news classification, source-to-CFD equivalence, profitability,
robustness, low correlation, or portfolio admission.

| Phase | Date | Verdict | Evidence |
|---|---|---|---|
| Source Approval | 2026-08-31 | APPROVED_SOURCE | `decisions/2026-08-31_wti_eia_negative_drift_m1_source_approval.md` |
| G0 | 2026-08-31 | APPROVED | `decisions/2026-08-31_qm5_41242_wti_eia_negative_drift_m1_g0.md` |
| Q01 | 2026-08-31 | PENDING | build not yet recorded |
| Q02 | 2026-08-31 | NOT_ENQUEUED | requires strict Q01 PASS and clear CPU window |
