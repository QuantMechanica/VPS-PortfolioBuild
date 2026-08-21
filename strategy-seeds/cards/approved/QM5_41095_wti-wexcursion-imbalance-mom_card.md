---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026_S01
variant_id: MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026_S01
source_id: MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026
ea_id: QM5_41095
slug: wti-wexcursion-imbalance-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41095_wti-wexcursion-imbalance-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41095_wti_weekly_excursion_imbalance_momentum_g0.md
source_approval: decisions/2026-08-21_wti_weekly_excursion_imbalance_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026/source.md"
    quality_tier: A
    role: own_price_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-week-boundary-wti-one-immediately-completed-weekly-ohlc-package-strict-open-centred-directional-excursion-two-to-one-imbalance-with-settlement-sign-agreement-continuation-one-week-hold
sources:
  - "[[sources/MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-week-directional-excursion-imbalance]]"
  - "[[concepts/wti-structural-trend]]"
indicators:
  - "[[indicators/completed-week-open-centred-excursions]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-week-excursion-imbalance, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410950000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 8-20 completed WTI positions per full post-warm-up year after strict weekly excursion, settlement-agreement, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 14
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_EXCURSION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a direct-WTI completed-week excursion-imbalance momentum sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact Monday anchors, one immediately completed 3-5-session weekly OHLC package, strict high-open versus open-low 2:1 inequality, settlement-sign agreement, equality/disagreement flat, one attempt, fixed risk, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, immediate_completed_monday_anchor, completed_weekly_ohlc, bounded_week_session_count, strict_open_centred_excursion_inequality, settlement_sign_agreement, equality_and_disagreement_flat, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized WTI sleeve; R1 complete-read peer-reviewed WTI source with weekly excursion translation disclosed; R2 exact label, week, OHLC, strict 2:1 excursion and settlement rule, attempt, fixed risk and lifecycle; R3 registered native WTI D1; R4 deterministic price arithmetic without ML or ex"
---

# QM5_41095 WTI Completed-Week Excursion-Imbalance Momentum

## Hypothesis

A completed WTI broker week whose maximum excursion from its first-session
open is strictly more than twice the excursion on the other side may represent
one-sided price discovery. When the final weekly settlement agrees with that
dominant excursion, the directional auction may continue through the next
broker week.

The direct WTI carrier is economically different from the certified
XAU/SP500/NDX/XNG book. This is a diversification hypothesis only: it does not
establish profitability, neutrality, or decorrelation. Q02 owns frequency and
baseline economics; unchanged Q09 alone may establish realized portfolio
correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026/source.md`,
authorized before extraction by
`decisions/2026-08-21_wti_weekly_excursion_imbalance_momentum_source_approval.md`
at commit `0f68d9807`. The complete parent source hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons and include NYMEX WTI in their futures universe. They do not test a
weekly open-centred excursion imbalance, a two-to-one threshold, a Darwinex
continuous CFD, fixed-dollar ATR risk, or the QM book. Every weekly clock,
excursion state, execution, and risk choice below is a declared QM
interpretation.

No source return, WTI-only alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, neutrality, or correlation statistic is
imported.

## Non-Duplicate Decision

The canonical fail-closed pre-allocation checker scanned 4,584 registry
identities and 1,264 repository cards. Its configured optional Strategy-Wiki
root was unavailable, so it returned `FUZZY_MATCH`; the missing source is
retained as a limitation. After allocation it scanned 4,585 registry rows and
returned only the expected exact self-hit for `QM5_41095`. Repository-wide
exact and semantic review found no pre-existing WTI implementation of the
complete signal and lifecycle.

- `QM5_41092_wti-wbody-dominance-mom` compares absolute weekly close/open
  body with full range. This card compares `high-open` with `open-low`; close
  magnitude is irrelevant beyond sign agreement.
- `QM5_41089_wti-wrange-migrate-mom` compares high and low across two weeks.
  This card is invariant to all parent-week values.
- `QM5_41080_wti-wclose-location-mom` uses parent-to-newest close return plus
  an outer-fifth close. This card has no parent return or close-location gate.
- `QM5_41093_wti-wclose-breakout-mom` requires a close beyond a prior weekly
  closing channel. This card reads no prior closing channel.
- `QM5_41073_wti-woutside-settle` requires outside-parent geometry and a close
  beyond the parent. This card aggregates only one completed week.
- generic candlestick builds use different bar periods or add body, wick,
  trend, oscillator, target, or dynamic-exit rules.
- certified `QM5_12567` is a long-only two-day XNG cumulative-RSI2 pullback
  under a slow mean, not symmetric oscillator-free WTI weekly continuation.

The exact WTI carrier, immediately completed Monday-anchored weekly OHLC,
three-to-five-session package, strict two-to-one open-centred excursion rule,
settlement-sign agreement, equality/disagreement-flat behavior, boundary
entry, durable attempt, fixed risk, and one-week hold are jointly
load-bearing. Verdict:
`NO_EXACT_WTI_WEEKLY_EXCURSION_IMBALANCE_DUPLICATE_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host and traded symbol: exact `XTIUSD.DWX` only.
- Timeframe: exact D1 only.
- EA ID, slot, and planned magic: `41095`, `0`, and `410950000`.
- Decision: first executable tick of a new normalized Monday-anchored broker
  week, within 180 elapsed minutes of the raw D1 session open.
- Signal data: the exact immediately completed weekly package only; current-
  week OHLC is excluded.
- Position count: at most one owned position and at most one consumed attempt
  per normalized week anchor.
- Expected frequency: approximately 8-20 completed positions per full post-
  warm-up year; the binding Q02 minimum remains five in every scored year.

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

Let `O`, `H`, `L`, and `C` be the immediately completed week's chronological
first open, aggregate high, aggregate low, and chronological final close:

```text
U = H - O
D = O - L

U > 2*D and C > O  => BUY
D > 2*U and C < O  => SELL
otherwise          => FLAT
```

Equality at either two-to-one boundary is flat. A dominant excursion with an
opposing or equal settlement is flat. The current week never enters the
formula, and excess magnitude never changes size.

## Rules

The entry, exit, filter, and management contracts below are the complete
authorized baseline. Anything not stated here is out of scope.

### Entry Rules

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
   valid geometry, and `H > L` with `L <= O <= H`.
8. Define `U=H-O` and `D=O-L`. BUY only on strict `U > 2*D` and `C > O`.
   SELL only on strict `D > 2*U` and `C < O`.
9. Ratio equality, close/open equality, excursion/settlement disagreement,
   invalid arithmetic, and every other state stay flat.
10. Require spread no greater than 1,500 points and a valid completed-bar
    `ATR(20,D1)`.
11. Freeze one hard stop `3.5 * ATR` from entry and use no take-profit.
12. Open at most one fixed-risk position. Excursion magnitude beyond
    qualification never changes the risk budget or volume.

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

### Exit Rules

1. The broker hard stop and framework kill switch remain authoritative.
2. Duplicate, wrong-side, wrong-magic, missing-stop, or otherwise malformed
   owned exposure is flattened.
3. Close the position on the first tick whose normalized Monday anchor is
   later than the anchor stored for the position's entry week.
4. Ten elapsed calendar days is a stale repair only.

There is no take-profit, opposite-signal exit, trailing stop, break-even move,
partial close, Friday flattening, scale-in, pyramid, grid, martingale, hedge,
or discretionary close.

### Filters And No-Trade Contract

- Require exact `XTIUSD.DWX`, D1, EA ID `41095`, and slot 0.
- Require `RISK_FIXED > 0`, `RISK_PERCENT = 0`, valid stop inputs, news
  temporal OFF, news compliance NONE, and Friday close disabled.
- Framework kill-switch, broker, and ownership controls remain authoritative.
- Apply the entry grace, durable attempt, exact label and calendar contract,
  weekly history and OHLC validity, strict excursion/settlement conjunction,
  spread ceiling, valid quote, and completed ATR gate fail-closed.
- No parent-week comparison, body-share gate, wick threshold, close-location
  rule, return channel, range rank, moving average, oscillator, volume, open
  interest, inventory, event calendar, futures curve, external file, API, or
  manual runtime input is used.

### Trade Management Rules

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
| `strategy_excursion_multiplier` | 2 | exact strict dominant/opposing excursion multiple |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

The multiplier is locked and exists only to expose the exact `U > 2*D` or
`D > 2*U` contract in the setfile. It is not an optimization surface.

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return sign continuation and WTI
membership. They do not supply the weekly horizon, open-centred excursions,
two-to-one threshold, or settlement-agreement condition.

## QM Interpretations

`MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026_S01` fixes the weekly horizon, one
completed OHLC package, strict excursion inequality, settlement agreement,
continuous-CFD Monday anchors and label normalization, entry grace,
persistent attempt, fixed-dollar ATR risk, spread cap, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later normalized broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 OHLC, broker time, symbol metadata, quotes,
completed-bar ATR, framework position/deal state, and persistent terminal
global-variable attempt state. No finite external dataset or event calendar
exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false weekly continuation, extreme probes that reverse near
  the open, weekend gaps, continuous-CFD roll/basis, energy-session label
  ambiguity, financing, spread, density below the floor, weekly source
  translation, and realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS | Named authors, peer-reviewed JFE paper, DOI, complete-paper evidence, retrieval hash, and explicit WTI membership; weekly excursion translation risk disclosed. |
| R2 | PASS | Exact clock, label, anchor, OHLC aggregation, excursion inequality, settlement agreement, attempt, risk, stop, spread, and lifecycle. |
| R3 | PASS | Registered native `XTIUSD.DWX` D1 history and MT5 state supply every runtime field; energy-label and CFD-basis risks remain Q02 falsification items. |
| R4 | PASS | Deterministic timestamp/OHLC arithmetic only; no trained or adaptive signal, external feed, grid, martingale, scale-in, or pyramid. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics, wrong
or mixed labels, a nonadjacent weekly anchor, invalid session count or OHLC,
entry at ratio equality or without settlement agreement, wrong side, current-
week leakage, late or repeated attempt, missing hard stop, wrong next-week
close, nondeterminism, or invalid fixed-risk mode.

Changing the WTI carrier, weekly aggregation, two-to-one excursion condition,
settlement agreement, attempt clock, risk, stop, or lifecycle requires a new
identity and full Q00/Q01 cycle. A failed result may not be rescued by moving
the threshold, accepting equality, dropping settlement agreement, reversing
the side, changing the hold, or adding a body, wick, close-location, range-
rank, return-channel, calendar, volatility, volume, moving-average, inventory,
event, or external-data filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, week anchor, weekly OHLC, sessions, excursion rule, settlement, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-week and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; exact immediately
completed weekly OHLC aggregation; first-session open and final-session close;
three/four/five-session acceptance and two/six-session rejection; long and
short strict excursion imbalance; exact ratio equality, close/open equality,
and both excursion/settlement disagreements flat; malformed and current-week
history rejection; persistent weekly attempts; fixed-risk frozen-stop sizing;
next-week and stale repair; card lint; strict compile; setfile schema; resolver
identity; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial WTI completed-week excursion-imbalance card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41095_wti_weekly_excursion_imbalance_momentum_g0.md` |
| Q01 Build Validation | - | PENDING | approved build has not yet entered |
| Q02 Baseline Screening | - | NOT_QUEUED | requires Q01 PASS and fresh capacity check |

## Safety Boundary

This card requests a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
