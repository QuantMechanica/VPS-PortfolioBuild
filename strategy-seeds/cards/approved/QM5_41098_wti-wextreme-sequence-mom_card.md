---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-WEXTREME-SEQUENCE-MOM-2026_S01
variant_id: MOP-WTI-WEXTREME-SEQUENCE-MOM-2026_S01
source_id: MOP-WTI-WEXTREME-SEQUENCE-MOM-2026
ea_id: QM5_41098
slug: wti-wextreme-sequence-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41098_wti-wextreme-sequence-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41098_wti_weekly_extreme_sequence_momentum_g0.md
source_approval: decisions/2026-08-21_wti_weekly_extreme_sequence_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-WEXTREME-SEQUENCE-MOM-2026/source.md"
    quality_tier: A
    role: own_price_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-week-boundary-wti-one-immediately-completed-three-to-five-session-week-unique-low-before-high-plus-positive-settlement-buy-unique-high-before-low-plus-negative-settlement-sell-one-week-hold
sources:
  - "[[sources/MOP-WTI-WEXTREME-SEQUENCE-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-week-extreme-sequence]]"
  - "[[concepts/wti-structural-trend]]"
indicators:
  - "[[indicators/completed-week-extreme-sequence]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-week-extreme-sequence, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410980000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 15-30 completed WTI positions per full post-warm-up year after unique-extreme, settlement-agreement, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 22
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_EXTREME_SEQUENCE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED
review_focus: "Falsify a direct-WTI completed-week extreme-sequence momentum sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact Monday anchors, one immediately completed 3-5-session week, unique weekly high and low sessions, chronological low-before-high or high-before-low order, matching settlement sign, ambiguous/disagreement flat, one attempt, fixed risk, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, immediate_completed_monday_anchor, bounded_week_session_count, unique_weekly_high_session, unique_weekly_low_session, chronological_extreme_order, settlement_sign_agreement, ambiguity_and_disagreement_flat, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized WTI sleeve; R1 complete-read peer-reviewed WTI source with weekly extreme-sequence translation disclosed; R2 exact label, week, unique extremes, chronology, settlement, attempt, fixed risk and lifecycle; R3 registered native WTI D1; R4 deterministic OHLC/index arithmetic without ML"
---

# QM5_41098 WTI Completed-Week Extreme-Sequence Momentum

## Hypothesis

A completed WTI broker week in which the unique weekly low occurs before the
unique weekly high describes a different intrawEEK price-discovery path from
one in which the unique high occurs first. When the final weekly settlement
agrees with that path, the directional auction may continue through the next
broker week.

The direct WTI carrier is economically different from the certified
XAU/SP500/NDX/XNG book. This is a diversification hypothesis only: it does not
establish profitability or decorrelation. Q02 owns frequency and baseline
economics; unchanged Q09 alone may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-WEXTREME-SEQUENCE-MOM-2026/source.md`,
authorized before extraction by
`decisions/2026-08-21_wti_weekly_extreme_sequence_momentum_source_approval.md`
at commit `e45984a09`. The complete parent source hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons and include NYMEX WTI in their futures universe. They do not test
weekly extreme chronology, unique extreme occurrences, settlement agreement,
a Darwinex continuous CFD, fixed-dollar ATR risk, or the QM book. Every
weekly path, execution, and risk choice below is a declared QM interpretation.

No source return, WTI-only alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, or correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the canonical checker scanned 4,587 registry identities
and 1,266 repository cards and found no exact or fuzzy match. Its optional
Strategy-Wiki root was unavailable, so the honest verdict remained
`INPUT_ERROR_FAIL_CLOSED`. After deterministic allocation, the checker found
only the expected exact registry self-hit for `QM5_41098`. Manual family
review fixes the mechanical boundaries:

- `QM5_41095_wti-wexcursion-imbalance-mom` compares aggregate
  `high-open` and `open-low` distances at a strict two-to-one threshold. This
  card compares no price distances and requires unique chronological session
  order for the weekly extremes.
- `QM5_41096_wti-wexcursion-reject-rv` uses the same excursion distances with
  settlement rejection. This card ignores excursion magnitude and rejects
  every order/settlement disagreement.
- `QM5_41092_wti-wbody-dominance-mom` uses a full-range body-share threshold.
  This card has no body-magnitude threshold.
- `QM5_41084_wti-wdaybreadth-mom` counts positive and negative D1 bodies.
  This card counts no session-return signs; intermediate opens and closes do
  not enter the signal.
- `QM5_41029`, `QM5_41032`, `QM5_41033`, and monthly relatives decompose
  close-to-open and open-to-close flows. This card performs no flow
  decomposition.
- `QM5_41073`, `QM5_41080`, `QM5_41089`, and `QM5_41093` require a parent
  range, parent return, close location, or closing channel. This card is
  invariant to its parent week.
- `QM5_12965_wti-week-orb` and `QM5_13075_xti-inweek-brk` wait for a current-
  week breakout. This card enters only at the boundary and uses no current-
  week signal price.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback below a slow mean. This card is direct WTI, symmetric,
  weekly, oscillator-free, and based on completed extreme order.

The exact carrier, immediately completed Monday-anchored package, three-to-
five sessions, unique aggregate high and low sessions, chronological order,
matching settlement sign, ambiguity/disagreement-flat behavior, boundary
entry, durable attempt, fixed risk, and one-week hold are jointly load-
bearing. Verdict:
`NO_EXACT_WTI_WEEKLY_EXTREME_SEQUENCE_MOMENTUM_DUPLICATE_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host and traded symbol: exact `XTIUSD.DWX` only.
- Timeframe: exact D1 only.
- EA ID, slot, and planned magic: `41098`, `0`, and `410980000`.
- Decision: first executable tick of a new normalized Monday-anchored broker
  week, within 180 elapsed minutes of the raw D1 session open.
- Signal data: the exact immediately completed weekly package only; current-
  week OHLC is excluded.
- Position count: at most one owned position and at most one consumed attempt
  per normalized week anchor.
- Expected frequency: 22 positions/year as an ordering prior within a design
  range of approximately 15-30; Q02 must prove at least five in every scored
  full post-warm-up year.

## Energy-Label Normalization

Infer one label convention from the current D1 bar. Accept native same-day
labels or a uniform `+1` calendar-day energy convention when the raw bar label
is one date behind broker time. Apply that same choice to the current bar and
every historical bar used in aggregation. Never shift broker time, mix label
conventions, or infer a different offset per bar.

The normalized current bar must belong to a Monday-anchored week whose anchor
differs by exactly seven calendar days from the completed package anchor.
Holiday-shortened completed weeks remain valid only with three to five unique,
strictly ordered sessions. Two or six sessions, duplicate dates, mixed labels,
bad OHLC, nonadjacent anchors, or unclassifiable history stay flat.

## Formula

For the immediately completed chronological session sequence `i=0..n-1`:

```text
O = open[0]
H = max(high[i])
L = min(low[i])
C = close[n-1]

iH = unique session index whose high equals H
iL = unique session index whose low equals L

iL < iH and C > O  => BUY
iH < iL and C < O  => SELL
otherwise          => FLAT
```

If the high or low occurs on multiple sessions, or both unique extremes occur
on the same session, the state is ambiguous and flat. Close/open equality and
extreme-order/settlement disagreement are flat. The current week never enters
the formula. Price distance and time distance between extremes never change
eligibility or risk.

## Rules

The entry, exit, filter, and management contracts below are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

1. Repair malformed owned exposure before entry-only filters.
2. Require exact symbol, D1, EA ID, slot, risk mode, news modes, and Friday-
   close inputs.
3. Observe a new D1 bar and derive the normalized Monday anchor for the current
   decision week under one uniform energy-label convention.
4. Admit only within `strategy_entry_grace_minutes = 180` elapsed minutes of
   the raw current D1 bar open. Late attachment consumes the week flat.
5. Persist the normalized Monday-anchor attempt before history, aggregation,
   signal, news, spread, quote, ATR, sizing, or order gates. Never retry that
   week after a downstream failure.
6. Aggregate the exact immediately completed broker week. Require three to
   five unique valid sessions and exact seven-calendar-day anchor adjacency.
7. Define `O` from the chronological first session, `C` from the final session,
   `H` as maximum high, and `L` as minimum low. Require positive finite OHLC,
   valid geometry, and `H > L` with both `O` and `C` inside the range.
8. Require exactly one session carrying `H` and exactly one carrying `L`.
   Repeated extremes or both extremes on the same session remain flat.
9. BUY only when the unique low session precedes the unique high session and
   `C > O`. SELL only when the unique high session precedes the unique low
   session and `C < O`. Equality, disagreement, or invalid state remains flat.
10. Require spread no greater than 1,500 points and a valid completed-bar
    `ATR(20,D1)`.
11. Freeze one hard stop `3.5 * ATR` from entry and use no take-profit.
12. Open at most one fixed-risk position. Sequence distance and return
    magnitude never change the risk budget or volume.

Current-week open, high, low, and close never enter the signal. Current quotes
are execution-only after the completed-week decision.

### Attempt And Restart Contract

The attempt key is terminal-global, scoped by EA, symbol, and timeframe, and
stores the normalized current Monday-anchor date. It is written before every
fallible gate. Initialization after the 180-minute grace consumes the missed
week without creating a late trade. Owned deal history and open-position
checks provide additional fail-closed guards. A rejected order, stop-out,
news block, spread failure, restart, invalid ATR, or invalid history cannot
create a same-week retry.

## 5. Exit Rules

1. The broker hard stop and framework kill switch remain authoritative.
2. Duplicate, wrong-side, wrong-magic, missing-stop, or otherwise malformed
   owned exposure is flattened.
3. Close the position on the first tick whose normalized Monday anchor is
   later than the anchor stored for the position's entry week.
4. Ten elapsed calendar days is a stale repair only.

There is no take-profit, opposite-signal exit, trailing stop, break-even move,
partial close, Friday flattening, scale-in, pyramid, grid, martingale, hedge,
or discretionary close.

## 6. Filters (No-Trade Module)

- Require exact `XTIUSD.DWX`, D1, EA ID `41098`, and slot 0.
- Require `RISK_FIXED > 0`, `RISK_PERCENT = 0`, valid stop inputs, news
  temporal OFF, news compliance NONE, and Friday close disabled.
- Framework kill-switch, broker, and ownership controls remain authoritative.
- Apply the entry grace, durable attempt, exact label and calendar contract,
  weekly history and OHLC validity, unique-extreme/sequence/settlement
  conjunction, spread ceiling, valid quote, and completed ATR gate fail-
  closed.
- No parent-week comparison, excursion-size gate, body-share gate, wick
  threshold, close-location rule, return channel, range rank, moving average,
  oscillator, volume, open interest, inventory, event calendar, futures curve,
  external file, API, or manual runtime input is used.

## 7. Trade Management Rules

- Own at most one position on the registered magic and symbol.
- Flatten duplicate, wrong-side, missing-stop, or otherwise malformed owned
  exposure before considering a new entry.
- Leave the frozen server-side stop unchanged; do not trail, widen, partial-
  close, reverse, scale, or pyramid.
- Close a survivor at the first later normalized weekly boundary; use the
  ten-calendar-day guard only when that boundary repair was missed.
- Management remains reachable on every tick before any entry-only gate.

## Parameters To Test

No optimization surface is approved. The sole baseline uses:

| Parameter | Locked value | Role |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | exact first-week-bar execution window |
| `strategy_history_bars` | 16 | bounded D1 OHLC buffer |
| `strategy_min_week_bars` | 3 | minimum completed-week sessions |
| `strategy_max_week_bars` | 5 | maximum completed-week sessions |
| `strategy_require_unique_extremes` | true | repeated extremes fail closed |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

Every value is locked in the one baseline setfile and is not an optimization
surface.

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return sign continuation and WTI
membership. They do not supply the weekly horizon, extreme sequence,
uniqueness rule, or settlement-agreement condition.

## QM Interpretations

`MOP-WTI-WEXTREME-SEQUENCE-MOM-2026_S01` fixes the weekly horizon, one
completed session package, unique aggregate extreme sessions, chronological
order, settlement agreement, continuous-CFD Monday anchors and label
normalization, entry grace, persistent attempt, fixed-dollar ATR risk, spread
cap, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later normalized broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 OHLC and timestamps, broker time, symbol
metadata, quotes, completed-bar ATR, framework position/deal state, and
persistent terminal global-variable attempt state. No finite external dataset
or event calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false weekly continuation, noisy or repeated extremes,
  weekend gaps, continuous-CFD roll/basis, energy-session label ambiguity,
  financing, spread, density below the floor, weekly source translation, and
  realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS | Named authors, peer-reviewed JFE paper, DOI, complete-paper evidence, retrieval hash, and explicit WTI membership; weekly extreme-sequence translation risk disclosed. |
| R2 | PASS | Exact clock, label, anchor, sessions, unique extremes, chronology, settlement agreement, attempt, risk, stop, spread, and lifecycle. |
| R3 | PASS | Registered native `XTIUSD.DWX` D1 history and MT5 state supply every runtime field; energy-label and CFD-basis risks remain Q02 falsification items. |
| R4 | PASS | Deterministic timestamp, OHLC, and index arithmetic only; no trained or adaptive signal, external feed, grid, martingale, scale-in, or pyramid. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics, wrong
or mixed labels, a nonadjacent weekly anchor, invalid session count or OHLC,
accepting repeated or same-session extremes, entry without order/settlement
agreement, wrong side, current-week leakage, late or repeated attempt, missing
hard stop, wrong next-week close, nondeterminism, or invalid fixed-risk mode.

Changing the WTI carrier, weekly aggregation, unique-extreme contract,
extreme-order rule, settlement agreement, attempt clock, risk, stop, or
lifecycle requires a new identity and full Q00/Q01 cycle. A failed result may
not be rescued by accepting ambiguous extremes, dropping settlement agreement,
reversing the side, changing the hold, or adding an excursion, body, wick,
close-location, range-rank, return-channel, calendar, volatility, volume,
moving-average, inventory, event, or external-data filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, week anchor, sessions, unique extremes, chronology, settlement, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-week and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; exact immediately
completed weekly aggregation; first-session open and final-session close;
three/four/five-session acceptance and two/six-session rejection; unique low-
before-high long and high-before-low short; repeated high, repeated low, same-
session extremes, close/open equality, and both order/settlement disagreements
flat; malformed and current-week history rejection; persistent weekly attempts;
fixed-risk frozen-stop sizing; next-week and stale repair; card lint; strict
compile; setfile schema; resolver identity; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial WTI completed-week extreme-sequence momentum card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41098_wti_weekly_extreme_sequence_momentum_g0.md` |
| Q01 Build Validation | 2026-08-21 | PENDING_BUILD | G0 permits one source-faithful non-live build after governed magic allocation |
| Q02 Baseline Screening | 2026-08-21 | NOT_ENQUEUED | requires Q01 PASS and fresh CPU headroom |

## Safety Boundary

This card requests a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
