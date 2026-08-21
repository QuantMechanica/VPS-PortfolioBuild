---
card_schema_version: 2
type: strategy
strategy_id: BIANCHI-YANG-WTI-WEXCURSION-REJECT-RV-2026_S01
variant_id: BIANCHI-YANG-WTI-WEXCURSION-REJECT-RV-2026_S01
source_id: BIANCHI-YANG-WTI-WEXCURSION-REJECT-RV-2026
ea_id: QM5_41096
slug: wti-wexcursion-reject-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41096_wti-wexcursion-reject-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41096_wti_weekly_excursion_rejection_reversal_g0.md
source_approval: decisions/2026-08-21_wti_weekly_excursion_rejection_reversal_source_approval.md
source_author: "Robert J. Bianchi; Michael E. Drew; John Hua Fan; Liu Yang; Bige Kahraman Goncu; Athanasios A. Pantelous"
source_authors: "Robert J. Bianchi; Michael E. Drew; John Hua Fan; Liu Yang; Bige Kahraman Goncu; Athanasios A. Pantelous"
source_citation: "Bianchi, R. J., Drew, M. E., and Fan, J. H. (2015), Combining Momentum with Reversal in Commodity Futures, Journal of Banking & Finance 59, 423-444; Yang, L., Goncu, B. K., and Pantelous, A. A., Momentum and Reversal in Commodity Futures, SSRN 3069253."
source_citations:
  - type: academic_paper
    citation: "Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua (2015), Combining Momentum with Reversal in Commodity Futures, Journal of Banking & Finance 59, 423-444."
    location: "DOI 10.1016/j.jbankfin.2015.07.006; complete-read packet strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md; bounded translation strategy-seeds/sources/BIANCHI-YANG-WTI-WEXCURSION-REJECT-RV-2026/source.md"
    quality_tier: A
    role: peer_reviewed_commodity_reversal_and_wti_carrier_lineage
  - type: academic_working_paper
    citation: "Yang, Liu; Goncu, Bige Kahraman; and Pantelous, Athanasios A., Momentum and Reversal in Commodity Futures."
    location: "SSRN 3069253; governed packet strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md"
    quality_tier: B
    role: supplemental_fixed_horizon_commodity_reversal_lineage
strategy_mechanic: normalized-week-boundary-wti-one-immediately-completed-weekly-ohlc-package-strict-open-centred-directional-excursion-two-to-one-imbalance-with-settlement-sign-rejection-fade-one-week-hold
sources:
  - "[[sources/BIANCHI-YANG-WTI-WEXCURSION-REJECT-RV-2026]]"
concepts:
  - "[[concepts/commodity-reversal]]"
  - "[[concepts/completed-week-failed-auction]]"
  - "[[concepts/wti-structural-reversal]]"
indicators:
  - "[[indicators/completed-week-open-centred-excursions]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-reversal, completed-week-failed-auction, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410960000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-15 completed WTI positions per full post-warm-up year after strict weekly excursion, settlement-rejection, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_FAILED_AUCTION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED
review_focus: "Falsify a direct-WTI completed-week failed-auction reversal sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact Monday anchors, one immediately completed 3-5-session weekly OHLC package, strict high-open versus open-low 2:1 inequality, opposing settlement sign, agreement/equality flat, one attempt, fixed risk, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, immediate_completed_monday_anchor, completed_weekly_ohlc, bounded_week_session_count, strict_open_centred_excursion_inequality, settlement_sign_rejection, agreement_and_equality_flat, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized WTI sleeve; R1 peer-reviewed commodity reversal source plus disclosed weekly failed-auction translation; R2 exact weekly OHLC, strict 2:1 rejection, attempt, fixed risk and lifecycle; R3 registered WTI D1; R4 deterministic native arithmetic only."
---

# QM5_41096 WTI Completed-Week Excursion-Rejection Reversal

## Hypothesis

A WTI broker week may probe strongly in one direction but reject that auction
before its final settlement. When one open-centred excursion is strictly more
than twice the other while the final close finishes on the opposite side of
the weekly open, the failed directional auction may reverse through the next
broker week.

The direct WTI carrier is economically different from the certified
XAU/SP500/NDX/XNG book. This is a diversification hypothesis only: it does not
establish profitability, neutrality, or decorrelation. Q02 owns frequency and
baseline economics; unchanged Q09 alone may establish realized portfolio
correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/BIANCHI-YANG-WTI-WEXCURSION-REJECT-RV-2026/source.md`,
authorized before extraction by
`decisions/2026-08-21_wti_weekly_excursion_rejection_reversal_source_approval.md`
at commit `adedf0130`. The parent byte hashes are
`F2EA59689B0FA0AE21A0BE5689A8F965062C65055516737C5210C65F6B072752`
and `52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7`.

Bianchi, Drew, and Fan provide peer-reviewed commodity momentum/reversal
lineage and include crude oil in the source universe. Yang, Goncu, and
Pantelous provide supplemental fixed-horizon commodity-reversal lineage. They
do not test a weekly open-centred excursion imbalance, settlement rejection,
a two-to-one threshold, a Darwinex continuous CFD, fixed-dollar ATR risk, or
the QM book. Every weekly clock, excursion state, execution, and risk choice
below is a declared QM interpretation.

No source return, WTI-only alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, neutrality, or correlation statistic is
imported.

## Non-Duplicate Decision

The canonical fail-closed pre-allocation checker scanned 4,585 registry
identities and 1,265 repository cards. Its configured optional Strategy-Wiki
root was unavailable, so it returned `FUZZY_MATCH`; the missing source remains
an explicit limitation. After allocation it scanned 4,586 registry rows and
returned the expected exact registry self-hit for `QM5_41096`.

- `QM5_41095_wti-wexcursion-imbalance-mom` follows a dominant excursion only
  when the final close agrees. This card trades only the exact mutually
  exclusive settlement-rejection states and keeps agreement flat. No week can
  qualify both strategies.
- `QM5_41092_wti-wbody-dominance-mom` compares absolute weekly close/open body
  with full range. This card compares `high-open` with `open-low`; body
  magnitude is irrelevant after the opposing close sign is established.
- `QM5_41089_wti-wrange-migrate-mom` compares high and low across two weeks.
  This card is invariant to all parent-week values.
- `QM5_41080_wti-wclose-location-mom` uses parent-to-newest close return plus
  an outer-fifth close. This card has no parent return or close-location gate.
- `QM5_41093_wti-wclose-breakout-mom` requires a close beyond a prior weekly
  closing channel. This card reads no prior closing channel.
- `QM5_41073_wti-woutside-settle` requires outside-parent geometry and a close
  beyond the parent. This card aggregates only one completed week.
- certified `QM5_12567` is a long-only two-day XNG cumulative-RSI2 pullback
  under a slow mean, not symmetric oscillator-free WTI weekly reversal.

The exact WTI carrier, immediately completed Monday-anchored weekly OHLC,
three-to-five-session package, strict two-to-one open-centred excursion rule,
opposing settlement sign, agreement/equality-flat behavior, boundary entry,
durable attempt, fixed risk, and one-week hold are jointly load-bearing.
Verdict:
`NO_EXACT_WTI_WEEKLY_EXCURSION_REJECTION_REVERSAL_DUPLICATE_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host and traded symbol: exact `XTIUSD.DWX` only.
- Timeframe: exact D1 only.
- EA ID, slot, and planned magic: `41096`, `0`, and `410960000`.
- Decision: first executable tick of a new normalized Monday-anchored broker
  week, within 180 elapsed minutes of the raw D1 session open.
- Signal data: the exact immediately completed weekly package only; current-
  week OHLC is excluded.
- Position count: at most one owned position and at most one consumed attempt
  per normalized week anchor.
- Expected frequency: approximately 5-15 completed positions per full post-
  warm-up year; the binding Q02 minimum remains five in every scored year.

## Energy-Label Normalization

Use one configured label convention for the entire run. Accept native
same-day labels or a uniform `+1` calendar-day energy convention. Apply the
same choice to the current bar and every historical bar used in aggregation.
Never shift broker time, mix label conventions, or infer a different offset
per bar.

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

U > 2*D and C < O  => SELL
D > 2*U and C > O  => BUY
otherwise          => FLAT
```

Equality at either two-to-one boundary is flat. A dominant excursion with an
agreeing or equal settlement is flat. The current week never enters the
formula, and excess magnitude never changes size.

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
   valid geometry, and `H > L` with `L <= O <= H`.
8. Define `U=H-O` and `D=O-L`. SELL only on strict `U > 2*D` and `C < O`.
   BUY only on strict `D > 2*U` and `C > O`.
9. Ratio equality, close/open equality, excursion/settlement agreement,
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

- Require exact `XTIUSD.DWX`, D1, EA ID `41096`, and slot 0.
- Require `RISK_FIXED > 0`, `RISK_PERCENT = 0`, valid stop inputs, news
  temporal OFF, news compliance NONE, and Friday close disabled.
- Framework kill-switch, broker, and ownership controls remain authoritative.
- Apply entry grace, durable attempt, exact label/calendar contract, weekly
  history and OHLC validity, strict excursion/rejection conjunction, spread
  ceiling, valid quote, and completed ATR gate fail-closed.
- No parent-week comparison, body-share gate, wick threshold, close-location
  rule, return channel, range rank, moving average, oscillator, volume, open
  interest, inventory, event calendar, futures curve, external file, API, or
  manual runtime input is used.

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
| `strategy_label_offset_seconds` | 86400 | uniform energy-label normalization |
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

The offset and multiplier are locked contract fields, not an optimization
surface.

## Source-Defined Rules

Bianchi, Drew, and Fan supply peer-reviewed commodity reversal lineage and
WTI membership. Yang, Goncu, and Pantelous supply supplemental fixed-horizon
commodity-reversal lineage. They do not supply this weekly failed-auction
state, threshold, direction, or lifecycle.

## QM Interpretations

`BIANCHI-YANG-WTI-WEXCURSION-REJECT-RV-2026_S01` fixes the weekly horizon,
one completed OHLC package, strict excursion inequality, opposing settlement,
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
- Major risks are false weekly reversal, probe/settlement state instability,
  weekend gaps, continuous-CFD roll/basis, energy-session label ambiguity,
  financing, spread, density below the floor, weekly source translation, and
  realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS_WITH_WEEKLY_FAILED_AUCTION_TRANSLATION_RISK | Named authors, peer-reviewed JBF paper, DOI, complete-manuscript evidence, explicit crude membership, and separately disclosed supplemental working paper; weekly failed-auction translation risk retained. |
| R2 | PASS | Exact clock, label, anchor, OHLC aggregation, excursion inequality, settlement rejection, attempt, risk, stop, spread, and lifecycle. |
| R3 | PASS | Registered native `XTIUSD.DWX` D1 history and MT5 state supply every runtime field; energy-label and CFD-basis risks remain Q02 falsification items. |
| R4 | PASS | Deterministic timestamp/OHLC arithmetic only; no trained or adaptive signal, external feed, grid, martingale, scale-in, or pyramid. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics, wrong
or mixed labels, a nonadjacent weekly anchor, invalid session count or OHLC,
entry at ratio equality or without settlement rejection, wrong side, current-
week leakage, late or repeated attempt, missing hard stop, wrong next-week
close, nondeterminism, or invalid fixed-risk mode.

Changing the WTI carrier, weekly aggregation, two-to-one excursion condition,
settlement rejection, attempt clock, risk, stop, or lifecycle requires a new
identity and full Q00/Q01 cycle. A failed result may not be rescued by moving
the threshold, accepting equality or settlement agreement, reversing the
side, changing the hold, or adding a body, wick, close-location, range-rank,
return-channel, calendar, volatility, volume, moving-average, inventory,
event, or external-data filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, week anchor, weekly OHLC, sessions, excursion rule, opposing settlement, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-week and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; exact immediately
completed weekly OHLC aggregation; first-session open and final-session close;
three/four/five-session acceptance and two/six-session rejection; strict upper
and lower excursion rejection; exact ratio equality, close/open equality, and
both excursion/settlement agreement states flat; malformed and current-week
history rejection; persistent weekly attempts; fixed-risk frozen-stop sizing;
next-week and stale repair; card lint; strict compile; setfile schema; resolver
identity; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial WTI completed-week excursion-rejection reversal card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41096_wti_weekly_excursion_rejection_reversal_g0.md` |
| Q01 Build Validation | 2026-08-21 | NOT_STARTED | none |
| Q02 Baseline Screening | 2026-08-21 | NOT_ENQUEUED | Q01 prerequisite absent |

## Safety Boundary

This card requests a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
