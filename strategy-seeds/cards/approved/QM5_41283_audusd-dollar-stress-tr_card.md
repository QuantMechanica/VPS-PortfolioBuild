---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902_S01
variant_id: AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902_S01
source_id: AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902
ea_id: QM5_41283
slug: audusd-dollar-stress-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41283_audusd-dollar-stress-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41283_audusd_dollar_stress_trend_g0.md
source_approval: decisions/2026-09-02_audusd_dollar_stress_trend_source_approval.md
source_author: "Stefan Avdjiev; Wenxin Du; Catherine Koch; Hyun Song Shin; Matteo Maggiori; QuantMechanica OWNER; OpenAI Codex"
source_authors: "Stefan Avdjiev; Wenxin Du; Catherine Koch; Hyun Song Shin; Matteo Maggiori; QuantMechanica OWNER; OpenAI Codex"
source_citation: "Avdjiev, Du, Koch, and Shin (2019), The Dollar, Bank Leverage, and Deviations from Covered Interest Parity, AER: Insights 1(2), 193-208, DOI 10.1257/aeri.20180322; Maggiori (2017), Financial Intermediation, International Risk Sharing, and Reserve Currencies, AER 107(10), 3038-3071, DOI 10.1257/aer.20130479; QuantMechanica OWNER Orthogonal Return Sources Program candidate 14; bounded AUDUSD translation by OpenAI Codex."
source_citations:
  - type: peer_reviewed_official_abstract
    citation: "Avdjiev, S., Du, W., Koch, C., and Shin, H. S. (2019). The Dollar, Bank Leverage, and Deviations from Covered Interest Parity. American Economic Review: Insights 1(2), 193-208."
    location: "Official AEA metadata and abstract; DOI 10.1257/aeri.20180322; bounded receipt in strategy-seeds/sources/AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902/retrieval_route_aea_20260902.json"
    quality_tier: A_abstract_scope
    role: global_dollar_funding_and_risk_capacity_carrier_only
  - type: peer_reviewed_official_abstract
    citation: "Maggiori, M. (2017). Financial Intermediation, International Risk Sharing, and Reserve Currencies. American Economic Review 107(10), 3038-3071."
    location: "Official AEA metadata and abstract; DOI 10.1257/aer.20130479; bounded receipt in strategy-seeds/sources/AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902/retrieval_route_aea_20260902.json"
    quality_tier: A_abstract_scope
    role: reserve_currency_global_crisis_appreciation_carrier_only
  - type: owner_research_program
    citation: "QuantMechanica OWNER (2026). Orthogonal Return Sources Program, candidate 14."
    location: "docs/research/ORTHOGONAL_RETURN_SOURCES_PROGRAM_2026-08-13.md"
    quality_tier: internal_governed_research
    role: exact_research_ticket_and_mechanization_brief
  - type: governed_composite_source
    citation: "QuantMechanica bounded AUDUSD dollar-stress trend-continuation packet."
    location: "strategy-seeds/sources/AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902/source.md"
    quality_tier: internal_governed
    role: exact_carrier_samples_thresholds_risk_and_lifecycle
strategy_mechanic: audusd-d1-short-only-synchronized-sp500-below-excurrent-50close-mean-negative-20day-return-three-fx-five-day-broad-usd-minus-one-percent-prior-20low-break-atr-trail
sources:
  - "[[sources/AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902]]"
concepts:
  - "[[concepts/global-dollar-funding-stress]]"
  - "[[concepts/risk-off-continuation]]"
  - "[[concepts/commodity-currency-downside]]"
indicators:
  - "[[indicators/excurrent-simple-moving-average]]"
  - "[[indicators/excurrent-channel-low]]"
  - "[[indicators/cross-symbol-return-breadth]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [forex, audusd, structural-trend, short-only, cross-market-regime, dollar-strength-breadth, d1, low-frequency, atr-hard-stop, monotone-atr-trail, time-stop, fixed-risk]
markets: [forex]
timeframes: [D1]
target_symbols: [AUDUSD.DWX]
primary_target_symbols: [AUDUSD.DWX]
signal_dependency_symbols: [EURUSD.DWX, GBPUSD.DWX, SP500.DWX]
single_symbol_only: true
logical_symbol: AUDUSD.DWX
symbol: AUDUSD.DWX
host_symbol: AUDUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412830000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: short_only
intraday: false
closed_bar_cache_required: true
smoke_year: 2020
expected_trade_frequency: "Approximately 10-15 completed AUDUSD positions per full post-warm-up year as an ordering prior only; retire below ten distinct entry days in any full year."
expected_trades_per_year_per_symbol: 12
expected_hold_time: "one to ten D1 bar shifts; earlier composite-gate clear, hard stop, or monotone ATR trail"
expected_regime: "episodic global risk-off dollar shortage with broad USD appreciation and AUDUSD downside continuation"
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_UNTESTED_MECHANIZATION
r1_reasoning: "A complete OWNER ticket and official peer-reviewed-journal abstracts establish the exact research lane and global-dollar-stress carrier; the AUDUSD daily trading conjunction remains explicitly untested."
r2_mechanical: PASS
r2_reasoning: "Synchronized completed-bar endpoints, ex-current samples, strict/equality boundaries, side, consumed attempt, ATR stop/trail, gate/time exits, fixed risk, and activity floor are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered exact AUDUSD.DWX, EURUSD.DWX, GBPUSD.DWX, and SP500.DWX native D1 data supply all runtime observations; only AUDUSD is traded."
r4_ml_forbidden: PASS
r4_reasoning: "Only completed native OHLC, fixed-window arithmetic, ATR, quotes, positions, time, and V5 framework state; no trained/adaptive signal, external runtime feed, or prohibited strategy family."
parameters_to_test: "Locked Q02 baseline only: exact AUDUSD.DWX D1; SP500 completed close below ex-current 50-close arithmetic mean; strict negative SP500 20-session simple return; mean EURUSD/GBPUSD/AUDUSD five-session simple return <= -0.010; AUDUSD completed close below prior 20 completed lows; ATR(14,D1)*2.0 hard stop and monotone completed-bar trail; ten-D1-shift time stop; 50-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED_PENDING
force_build: true
review_focus: "Falsify a short-only AUDUSD global-dollar-stress sleeve outside the certified index/metal/energy book. Verify exact cross-symbol D1 alignment, ex-current SP500 mean, return endpoints, broad-USD equality, prior-low exclusion, consumed daily attempt, short-only side, hard stop, monotone trail, gate/time exits, and fixed risk. Q09 alone may establish portfolio overlap."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, synchronized_completed_d1_bars, current_bar_excluded, sp500_excurrent_50close_mean, sp500_20session_return, broad_usd_three_cross_mean, broad_usd_inclusive_boundary, audusd_prior_20low_break, short_only, daily_attempt_state, fixed_risk, hard_stop_present, monotone_atr_trail, ten_bar_time_stop, composite_gate_clear_exit, news_off, friday_close_off, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 plus durable source approval: higher-priority diverse build and infrastructure lanes were exhausted; R1 preserves untested-mechanization and adverse lead-lag evidence, R2 locks all samples and lifecycle details, R3 uses registered native D1 data, and R4 uses deterministic native arithmetic only. Canonical dedup is CLEAN and manual review separates generic breakouts, JPY/CHF carry unwind, broad-USD exhaustion reversal, and dead next-day SP500 lead-lag forms."
---

# QM5_41283 AUDUSD Dollar-Stress Trend Continuation

## Hypothesis

During severe global risk reduction, constrained intermediaries and borrowers
can become price-insensitive buyers of US-dollar funding. When completed
SP500 bars confirm a weak risk regime, several liquid USD crosses confirm
broad dollar strength, and AUDUSD independently breaks its prior daily low,
AUDUSD downside continuation may persist long enough to harvest with bounded
fixed risk.

This is a falsifiable structural hypothesis, not evidence of profitability,
independence, or portfolio diversification. Q02 owns activity and economics;
Q04 owns temporal robustness; Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The governed source packet is
`strategy-seeds/sources/AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902/source.md`,
approved by
`decisions/2026-09-02_audusd_dollar_stress_trend_source_approval.md`.

The official AEA abstracts support only a global-dollar funding/risk-sharing
carrier. The OWNER program supplies the pre-ranked candidate and brief. None
of those sources tests AUDUSD, these exact daily gates, a channel break, ATR
management, CFD costs, or the QM portfolio. The repository's own simple
SP500-to-AUDUSD next-day lead-lag and beta-RV tests were null; this card
preserves that result and makes no next-day cross-asset forecast.

No source return, alpha, probability, profit factor, drawdown, trade count,
cost, carry, CFD equivalence, correlation, or portfolio statistic transfers.

## Non-Duplicate Decision

The corrected-root receipt
`artifacts/qm5_audusd_dollar_stress_preallocation_dedup_20260902.json`,
SHA-256
`5EA79E6A5AC8FE6F4187C8F0F6118F9BE550804E297B8D1CB43975D222377F2E`,
returned `CLEAN` across 4,782 registry rows, 1,418 cards, and all 45 Strategy
Wiki nodes.

- `QM5_1013_lien-20day-breakout` lacks the synchronized SP500 and broad-USD
  regime conjunction.
- `QM5_20292` and related carry-unwind cards trade JPY/CHF baskets under a
  volatility stress rule, not AUDUSD under a dollar-funding gate.
- `QM5_12580` fades broad-USD exhaustion; this card follows continued dollar
  strength, so its directional thesis is opposite.
- Existing generic AUDUSD D1 trend cards do not require both SP500 gates and
  the same three-cross five-day USD breadth state.
- The killed SP500 lead-lag/RV forms forecast a later AUDUSD return or trade a
  beta spread. This rule uses same-timestamp completed regime state and
  AUDUSD's own strict breakout.

Verdict:
`DISTINCT_AUDUSD_D1_SHORT_ONLY_SYNCHRONIZED_SP500_STRESS_BROAD_USD_CHANNEL_BREAK`.

## Rules

### Market, Clock, And Data

- Host and trade exact `AUDUSD.DWX`, D1, slot 0, magic `412830000`.
- Auxiliary signal-only symbols are exact `EURUSD.DWX`, `GBPUSD.DWX`, and
  `SP500.DWX`; they never receive orders or magic slots.
- Evaluate once per new host D1 bar. Use the latest completed host D1 time as
  the alignment anchor; require every auxiliary latest completed D1 bar to
  have that exact timestamp.
- Exclude the forming bar and the just-completed signal bar from historical
  reference windows. Require positive finite prices and chronological bars.
- Persist the framework current-D1 decision key as the consumed daily attempt
  before history, signal, spread, quote, ATR, sizing, margin, or send gates.

### Exact Signal

For latest completed SP500 close `S0`, prior closes `S1..S50`, and the close
twenty completed intervals earlier `S20`:

```text
sp_mean50 = sum(S1..S50) / 50
sp_below  = S0 < sp_mean50
sp_ret20  = S0 / S20 - 1
sp_weak   = sp_ret20 < 0
```

For each `X` in EURUSD, GBPUSD, and AUDUSD, using synchronized completed
closes:

```text
r5_X      = X0 / X5 - 1
usd_mean5 = (r5_EURUSD + r5_GBPUSD + r5_AUDUSD) / 3
usd_broad = usd_mean5 <= -0.010
```

For AUDUSD's latest completed close `A0` and prior completed daily lows:

```text
prior_low20 = min(AUDUSD low1..low20)
breakout    = A0 < prior_low20
SELL        = sp_below and sp_weak and usd_broad and breakout
```

The SP500 comparisons are strict, the broad-USD boundary is inclusive, and
the target breakout is strict. No condition uses the forming bar. Signal
magnitude never changes risk.

## 4. Entry Rules

1. Require exact EA ID, magic slot, symbol, D1 period, fixed-risk mode, news
   modes, Friday mode, and locked strategy inputs.
2. Run owned-position integrity and exit management before entry-only gates.
3. On a new D1 edge, persist the framework current-D1 decision key before every
   fallible gate. A restart or later tick cannot retry that signal day.
4. Reject owned exposure or a same-magic entry deal attributable to the
   consumed day.
5. Load one bounded synchronized completed-bar snapshot. Reject missing,
   duplicate, nonchronological, nonpositive, nonfinite, or misaligned data.
6. Compute exactly the formulas above. Invalid or false state consumes the day
   flat.
7. Require a noncrossed executable quote and a nonnegative spread no more than
   50 points. Zero modeled `.DWX` spread is valid.
8. Freeze completed signal-bar `ATR(14,D1)`. Attach a normalized broker hard
   stop at entry plus `2.0*ATR` before opening one market SELL.
9. Size only through the V5 fixed-risk helper under `RISK_FIXED=1000`. There
   is no target, retry, long, partial entry, scale-in, averaging, pyramid,
   grid, or martingale.

## 5. Exit Rules

1. Framework kill switch and the broker hard stop are authoritative.
2. At each later completed aligned D1 edge, exit when any of `sp_below`,
   `sp_weak`, or `usd_broad` is false. If aligned gate state cannot be proved,
   close fail-safe rather than infer it.
3. Exit after `iBarShift(AUDUSD.DWX,D1,position_open_time,false) >= 10`.
4. On a valid completed host bar, calculate `close0 + 2.0*ATR(14,D1)` and move
   the stop only when the normalized candidate is below the existing stop and
   remains a valid protective stop above the market. Never loosen or remove
   the stop.
5. Friday close is OFF because the source hold may cross weekends. Both news
   axes are OFF because no external calendar is a signal.
6. There is no take-profit, break-even step, discretionary reversal, partial
   close, long flip, or same-bar re-entry.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact identity, symbol, period, risk/news/Friday,
  locked-input, registry, or magic contract.
- Reject a consumed day, owned exposure, same-day entry history, malformed or
  unsynchronized D1 series, false signal, excessive spread, invalid quote,
  unavailable ATR, invalid stop/volume metadata, or insufficient margin.
- Entry-only history, spread, quote, news, and margin checks never suppress
  kill, integrity, hard-stop, gate-clear, trail, or time management.
- Runtime may not read files, APIs, rates, forecasts, positioning, trained
  outputs, optimizer results, or portfolio state.

## 7. Trade Management Rules

- Maintain zero or one valid short AUDUSD position and one consumed attempt
  per framework D1 decision key.
- Close duplicate, wrong-symbol, wrong-side, invalid-volume, or stopless owned
  exposure; never repair it by adding risk.
- On completed bars, perform gate-clear and ten-shift exits before considering
  a new entry; then tighten the ATR stop monotonically.
- Terminal-global attempt state survives restart and is reconciled with owned
  positions and entry-deal history.
- No randomness, adaptation, external signal, retry loop, partial close,
  scale-in, averaging, grid, martingale, or pyramid is allowed.

## 8. Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Value | Contract |
|---|---:|---|
| `strategy_sp_sma_days` | 50 | locked |
| `strategy_sp_return_days` | 20 | locked |
| `strategy_usd_return_days` | 5 | locked |
| `strategy_usd_threshold` | -0.010 | locked |
| `strategy_breakout_days` | 20 | locked |
| `strategy_atr_period` | 14 | locked |
| `strategy_stop_atr` | 2.0 | locked |
| `strategy_trail_atr` | 2.0 | locked |
| `strategy_max_hold_bars` | 10 | locked |
| `strategy_max_spread_points` | 50 | locked |
| `strategy_deviation_points` | 20 | locked |

Changing a carrier, symbol set, endpoint, sample membership, threshold,
direction, stop, trail, time exit, or gate-clear definition after Q02 is
forbidden.

## Source-Defined Rules

The OWNER research ticket defines the global-stress, broad-USD, channel-break,
short direction, two-ATR risk, and ATR/time/gate lifecycle family. The AEA
abstracts define only the structural global-dollar carrier.

## QM Interpretations

Variant `AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902_S01` fixes AUDUSD as the
sole traded carrier; exact simple-return endpoints; an ex-current 50-close
mean; prior daily lows; ATR period 14; the exact inclusive broad-USD boundary;
monotone close-plus-ATR trail; and fail-safe invalid-gate exit. These are
pre-result translations and cannot change after Q02.

## Framework Execution Overrides

- Friday close: disabled.
- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy framework news mode: OFF.
- Backtest risk: fixed 1,000 account-currency units; percentage risk zero.
- Stress rejection probability: zero in the canonical set.

## Exit Precedence

1. Framework kill switch and broker hard stop.
2. Owned-position integrity repair.
3. Completed-bar invalid/composite-gate clear exit.
4. Ten-D1-shift time exit.
5. Monotone completed-bar ATR stop tightening.
6. Entry-only gates and at most one new position.

## Runtime Data Dependencies

Exact AUDUSD/EURUSD/GBPUSD/SP500 native D1 timestamps and OHLC, broker time,
symbol metadata, quotes, completed-bar ATR, position/deal state, and one
terminal-persistent daily attempt marker. Auxiliary data are signal-only. No
external runtime dataset exists.

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- One short position receives a normalized `2.0*ATR(14,D1)` hard stop and no
  target. The trail may only reduce requested risk.
- Entry spread is capped at 50 points; weekend and crisis gaps can fill beyond
  the requested stop.
- Principal risks are episodic scarcity, false channel breaks, simultaneous
  cross-market gaps, financing, auxiliary-history mismatch, crowded risk-off
  exposure, and sparse-sample overstatement.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_UNTESTED_MECHANIZATION | Complete OWNER ticket and official peer-reviewed-journal abstracts establish the research lane and global-dollar carrier; no trading result transfers. |
| R2 | PASS | Aligned completed bars, exact samples, boundaries, side, attempt, risk, trail, and exits are fixed. |
| R3 | PASS | Registered native AUDUSD/EURUSD/GBPUSD/SP500 D1 data supply all runtime observations. |
| R4 | PASS | Deterministic native arithmetic and framework state only; no trained signal, external feed, grid, or martingale. |

## 9. Failure Modes And Kill Criteria

Retire or fail on any of the following:

- zero trades or fewer than ten distinct entry days in any full post-warm-up
  Q02 year;
- nonpositive governed economics or any downstream gate failure;
- forming-bar leakage, signal-bar inclusion in a reference sample, timestamp
  mismatch accepted as aligned, or wrong simple-return endpoints;
- non-strict SP500/breakout boundary, non-inclusive broad-USD boundary, wrong
  three-cross divisor, wrong side, same-day retry, or auxiliary execution;
- missing/loosening stop, wrong risk mode, missed gate/time exit, or exposure
  after invalid state without the broker hard stop; or
- nondeterministic output for identical history and inputs.

No post-result threshold, stop, exit, symbol, or activity rescue is authorized.

## Falsification And Requalification

Any change to the carrier, D1 alignment, four-symbol set, sample endpoints,
windows, threshold, prior-low definition, short-only side, attempt clock, risk
mode, stop/trail, gate-clear exit, or ten-shift limit creates a new execution
contract and requires a new binary, Q02 restart, and full requalification.

## 10. Execution And State Contract

- `ea_id=41283`, exact `AUDUSD.DWX`, D1, slot 0, magic `412830000`.
- Persist `QM5_41283_D1_ATTEMPT_<magic>` before all fallible entry gates.
- Recover the marker across restarts and reconcile it with entry deals.
- Exactly one active registry/magic row and resolver mapping are mandatory
  before compile.
- Logs expose aligned times, SP500 mean/return, all three five-day returns,
  broad mean, prior low, gate booleans, side, ATR, and lifecycle action.

## 11. Portfolio Interaction

AUDUSD direct short exposure adds a forex carrier absent from the stated
certified index/metal/energy survivor set. The structural risk-off state can
still overlap index shorts and carry-unwind sleeves; this is not a measured
decorrelation result. Q09 alone may establish overlap. This card changes no
portfolio gate, manifest, allocation, or waiver.

## 12. Validation Plan

1. Card schema lint and prohibited-token scan.
2. Canonical dedup receipt plus semantic-neighbor and adverse-evidence review.
3. Pure fixtures for sample exclusion, endpoints, alignment, thresholds,
   breakout, side, time exit, and monotone trail.
4. Governed slot-0 magic allocation, V5 spec validation, scoped build check,
   and strict MQL5 compile.
5. One canonical `RISK_FIXED` AUDUSD D1 backtest set only.
6. At most one paced Q02 enqueue after fresh CPU admission; no manual tester.

## 13. Framework Alignment

| Card rule | V5 location |
|---|---|
| Exact identity/symbol/period/risk/news/Friday/input locks | `OnInit` and no-trade filter |
| Durable completed-D1 attempt | terminal-global helper before fallible entry gates |
| Bounded synchronized D1 snapshot | entry/exit cache loader on the new-bar edge |
| Exact stress, breadth, and breakout formulas | cached strategy-state helper |
| Fixed-risk short with hard stop | `Strategy_EntrySignal` plus transaction manager |
| Integrity, gate/time exits, monotone trail | `Strategy_ManageOpenPosition` and `Strategy_ExitSignal` |

## 14. Safety Boundary

Authorized: one approved source/card, one registered V5 identity, one
branch-only non-live build, pure reference tests, strict Q01, and at most one
paced Q02 enqueue.

Forbidden: manual tester dispatch, optimization, live/demo/shadow/stress sets,
`T_Live`, AutoTrading, deploy/live manifests, portfolio-gate edits, portfolio
admission, correlation waivers, external runtime data, or terminal control.

## Revision History

| Date | Change |
|---|---|
| 2026-09-02 | Initial AUDUSD global-dollar-stress card approved under the OWNER diversity/funnel mission; canonical dedup CLEAN; R1-R4 bounded PASS. |
| 2026-09-02 | Governed compile passed and one paced RISK_FIXED AUDUSD.DWX D1 Q02 row was enqueued; Q09 alone owns portfolio correlation. |

## Pipeline Phase Status

| Phase | Status | Evidence |
|---|---|---|
| G0 Source Approval | APPROVED | `decisions/2026-09-02_audusd_dollar_stress_trend_source_approval.md` |
| G0 Card Decision | APPROVED | `decisions/2026-09-02_qm5_41283_audusd_dollar_stress_trend_g0.md` |
| EA Identity | ACTIVE | registry row `QM5_41283` |
| Magic | ACTIVE | slot 0 `AUDUSD.DWX`, magic `412830000` |
| Q01 | PASS | `artifacts/qm5_41283_build_result_20260902.json` |
| Q02 | ENQUEUED_PENDING | work item `077d392b-8596-4d25-a183-1c83aef949bd`; `artifacts/qm5_41283_audusd_dollar_stress_tr_q01_q02_handoff_20260902.json` |
