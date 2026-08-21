---
card_schema_version: 2
type: strategy
strategy_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026_S01
variant_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026_S01
source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
ea_id: QM5_41087
slug: wti-wr4-close-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41087_wti-wr4-close-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41087_wti_weekly_wr4_close_momentum_g0.md
source_approval: decisions/2026-08-21_wti_weekly_wr4_close_momentum_source_approval.md
source_author: "Toby Crabel; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Toby Crabel; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Crabel, T. (1990), Day Trading with Short-Term Price Patterns and Opening Range Breakout, Traders Press; Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded composite strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md"
    quality_tier: A
    role: own_return_continuation_and_wti_carrier_lineage
  - type: trading_book
    citation: "Crabel, Toby (1990), Day Trading with Short-Term Price Patterns and Opening Range Breakout, Traders Press."
    location: "Governed range-framework packets strategy-seeds/sources/CRABEL-WTI-NR7-BRK-2026/source.md and strategy-seeds/sources/CRABEL-WTI-WEEK-ORB-2026/source.md"
    quality_tier: B
    role: range_expansion_lineage
strategy_mechanic: normalized-week-boundary-wti-four-consecutive-completed-weekly-packages-newest-strict-widest-range-of-four-own-week-body-strict-outer-quartile-close-location-continuation-one-week-hold
sources:
  - "[[sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-week-range-expansion]]"
  - "[[concepts/wti-structural-trend]]"
indicators:
  - "[[indicators/completed-week-widest-range-of-four]]"
  - "[[indicators/completed-week-close-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, time-series-momentum, completed-week-range-expansion, completed-week-close-location, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410870000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately five to eight completed WTI positions per full post-warm-up year after strict WR4, body, close-location, history, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_WR4_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED_PENDING
q02_work_item: e928a598-a8f3-4283-820b-4e6461fe0f52
q01_build_report: D:/QM/reports/framework/21/build_check_20260821_085956.json
q01_p1_evidence: D:/QM/reports/pipeline/QM5_41087/P1/P1_QM5_41087_result.json
review_focus: "Falsify a direct-WTI completed-week range-expansion continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact Monday anchors, four consecutive completed weekly packages, three-to-five sessions each, newest-week strict widest range without ties, earliest open/latest close, strict own-body and 0.75/0.25 close-location agreement, durable weekly attempt, fixed-risk frozen stop, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, four_consecutive_monday_anchors, completed_weekly_ohlc, bounded_week_session_counts, newest_strict_widest_range_of_four, earliest_open_latest_close, strict_own_body_direction, strict_outer_quartile_close_location, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized build; R1 combines complete-read peer-reviewed WTI time-series-momentum lineage and reputable Crabel range-expansion lineage while disclosing the exact weekly WR4/body/CLV conjunction as untested; R2 locks clock, four anchors, OHLC endpoints, strict range rank and ties, own-body sign, close-location thresholds, side, attempt, risk, and lifecycle; R3 uses registered native WTI D1 only with label and CFD-basis risk explicit; R4 is deterministic timestamp, OHLC, logarithm, comparison, ATR, quote, position, deal, and terminal-state arithmetic without a banned signal, trained output, external feed, grid, or martingale; canonical dedup and manual family review separated two-week close location, outside-week settlement, narrow-range breakout, inside-week breakout, current-week opening range, and XNG oscillator logic."
---

# QM5_41087 WTI Weekly WR4 Close Momentum

## Hypothesis

An unusually expansive completed WTI week may carry information about a
structural repricing rather than a transient intraday move. At the first
tradable bar of the next broker week, follow the expansive week's own
open-to-close direction only when it was the strict widest of four completed
weeks and settled in the matching outer quartile of its own range.

The sources establish broad own-return continuation, WTI membership, and a
range-expansion lineage. They do not establish this weekly widest-of-four
condition, outer-quartile gate, continuous-CFD result, or portfolio
relationship. The rule is a falsifiable QM translation with no ex-ante
profitability or decorrelation claim.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, approved
before card extraction in
`decisions/2026-08-21_wti_weekly_wr4_close_momentum_source_approval.md` at
commit `40d5669ac`.

Moskowitz, Ooi, and Pedersen document own-return continuation and explicitly
include NYMEX WTI in their futures universe. Crabel supplies the range-state
lineage. Neither tests a D1-aggregated weekly WR4 state, the own-week body,
`0.75` / `0.25` close-location thresholds, DarwinexZero CFD labels,
fixed-dollar ATR risk, or the one-week hold. Every such choice below is a
declared QM interpretation.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,574 registry rows, 625 root
cards, and zero external vault nodes and returned `CLEAN` with no exact or
fuzzy match. Manual review fixes the load-bearing boundaries:

- `QM5_41080_wti-wclose-location-mom` uses two completed weeks,
  parent-close-to-new-close sign, and 0.80/0.20 CLV; it has no range rank.
- `QM5_41073_wti-woutside-settle` requires outside-parent geometry and a close
  beyond the parent extreme; this card ignores parent containment and ranks
  four full ranges.
- `QM5_41061_wti-week-nr7-brk` uses the opposite narrowest-of-seven state and
  waits for a current-week breakout; this card enters only at the boundary.
- `QM5_13075_xti-inweek-brk` requires inside-week containment and a later
  breakout; this card requires neither.
- `QM5_12965_wti-week-orb` defines a current-week first-D1 opening range; this
  card excludes current-week price from its signal.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG oscillator
  pullback, not symmetric weekly WTI continuation.

Verdict:
`CLEAN_WTI_COMPLETED_WEEK_WR4_OWN_BODY_OUTER_QUARTILE_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: exact D1; magic slot 0; magic `410870000`.
- Decision: first tradable normalized D1 bar of a new Monday-anchored broker
  week, within 180 elapsed raw-session minutes.
- Formation: four immediately preceding consecutive completed broker weeks,
  with three to five completed D1 sessions in every package.
- Normal exit: first tick whose broker Monday anchor is later than the open
  position's anchor.
- Expected cadence: approximately 5-8 completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `O0`, `H0`, `L0`, and `C0` be the earliest open, high, low, and final
close of the newest completed week. Let `Ri = Hi - Li` be the full range of
completed week `i`, where zero is newest and three is oldest:

```text
body = ln(C0 / O0)
clv  = (C0 - L0) / R0
wr4  = R0 > R1 and R0 > R2 and R0 > R3

wr4 and body > 0 and clv > 0.75  => BUY
wr4 and body < 0 and clv < 0.25  => SELL
otherwise                         => FLAT
```

All values complete before the decision week begins. Exact zero, any range
tie, equality at either threshold, invalid OHLC, zero range, or disagreement
is flat. Return or range magnitude never changes size.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar under EA 41087 and
   magic slot zero.
2. Repair malformed, later-week, or stale owned exposure before entry-only
   gates.
3. Select label offset zero when the raw current D1 date equals broker date or
   `+1` day only when it is exactly one calendar day behind. Apply one uniform
   convention to every historical bar and reject every other or mixed state.
4. Derive the current Monday anchor from normalized time. Require the newest
   completed bar to have an older anchor, proving the current bar is the first
   tradable bar of this week.
5. Require attachment within 180 elapsed minutes of raw D1 bar open. Persist
   the current Monday-anchor attempt before history, signal, spread, quote,
   ATR, sizing, news, or order gates. Never retry that week.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker week.
7. Within a fixed 50-bar buffer, reconstruct exactly the four immediately
   completed weeks at anchors current minus 7, 14, 21, and 28 calendar days.
   Require strict reverse-time bar order and three to five bars per week.
   Do not skip a missing or malformed week.
8. Aggregate each weekly high and low. For the newest week select its
   chronologically earliest open and final close. Require positive finite
   OHLC, `high >= max(open,close)`, `low <= min(open,close)`, and positive
   range.
9. Require the newest range to be strictly greater than all three older
   ranges. Any equality or older larger range is flat.
10. Compute body and CLV exactly as above. Buy only on strict
    `body>0 && clv>0.75`. Sell only on strict `body<0 && clv<0.25`.
11. Require a valid executable quote and no genuinely positive spread wider
    than 1,500 points. Modeled zero `.DWX` spread is valid.
12. Attach one frozen hard stop at `3.5 * ATR(20,D1)` from completed data and
    size one position to `RISK_FIXED=1000`. Use no take profit.
13. Submit one slot-zero market order once. No pending order, retry, scale-in,
    grid, martingale, pyramid, hedge, reversal, or second entry exists.

## 5. Exit Rules

1. Broker hard stop and framework kill-switch closure remain authoritative.
2. Immediately flatten duplicate, wrong-symbol, wrong-magic, missing-stop,
   invalid-volume, or invalid-open-time exposure.
3. Close on the first tick whose broker Monday anchor is later than the
   position-open Monday anchor.
4. Close after ten elapsed calendar days as a stale safety repair.
5. No Friday close, target, signal exit, trail, break-even move, partial exit,
   discretionary close, or intentional hold beyond the next week.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41087, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Uniform label normalization, first-week-bar clock, 180-minute grace, four
  consecutive anchors, weekly session counts, OHLC/endpoints, strict WR4
  rank, own-body/CLV conjunction, durable attempt, spread, quote, ATR, sizing,
  and stop geometry all fail closed.
- No futures chain, inventory, seasonality table, volume, open interest, event
  feed, API, CSV, optimizer artifact, trained output, oscillator, moving
  average, or manual signal is read.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410870000`.
- Persist the last attempted Monday anchor across restart.
- Manage malformed, later-week, stale, and kill-switch exits before entry.
- Freeze the original hard stop; never widen, trail, or remove it.
- Do not retry, add, pyramid, grid, martingale, partially close, hedge,
  reverse, or re-enter inside the week.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | exact first-week-bar execution window |
| `strategy_history_bars` | 50 | bounded D1 weekly-OHLC buffer |
| `strategy_required_weeks` | 4 | exact completed weekly packages |
| `strategy_min_week_bars` | 3 | minimum sessions in each completed week |
| `strategy_max_week_bars` | 5 | maximum sessions in each completed week |
| `strategy_clv_upper` | 0.75 | strict long confirmation boundary |
| `strategy_clv_lower` | 0.25 | strict short confirmation boundary |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return continuation and WTI membership.
Crabel supplies a systematic range-expansion lineage. They do not supply this
weekly WR4/body/CLV conjunction.

## QM Interpretations

`CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026_S01` fixes the weekly horizon, completed
weekly aggregation, four-week strict range rank, own-week body, close-location
quartiles, continuous-CFD Monday anchors and label normalization, entry grace,
persistent attempt, fixed-dollar ATR risk, spread cap, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 OHLC/timestamps, broker time, symbol metadata,
quotes, completed-bar ATR, framework position/deal state, and persistent
terminal-global attempt state. No finite external dataset or calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false continuation after exhaustion, weekend gaps,
  continuous-CFD roll/basis, energy-session label ambiguity, financing,
  spread, density below the floor, weekly WR4 source translation, and
  realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, wrong or
mixed labels, nonconsecutive anchors, invalid session counts or OHLC,
incorrect earliest-open/final-close selection, accepting a range tie, wrong
body or CLV direction, equality entry, current-week leakage, late or repeated
attempt, missing hard stop, wrong next-week close, nondeterminism, or invalid
fixed-risk mode.

Changing the WTI carrier, four-week rank window, strict widest-state, body
orientation, either CLV threshold, direction, attempt clock, risk, stop, or
lifecycle requires a new identity, binary, complete stream reconciliation,
and portfolio requalification. A failed result may not be rescued by accepting
ties or equality, reducing the lookback, moving a threshold, dropping body/CLV
agreement, reversing the side, changing the hold, or adding calendar,
volatility, volume, moving-average, inventory, or external state.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, four week anchors, session counts, weekly OHLC, WR4, body, CLV, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-week and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; four exact
consecutive completed weeks; chronologically earliest open/final close;
three/four/five-session acceptance and two/six-session rejection; weekly
high/low aggregation; strict WR4 and all tie/older-wider flat states; both
strict body/CLV directions; equality and disagreement flat; no current-week
leakage; persistent weekly attempts; fixed-risk frozen-stop sizing; next-week
and stale repair; card lint; strict compile; setfile schema; resolver identity;
reference tests; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial WTI weekly WR4 close-momentum card | Q00 | APPROVED |
| v1-build | 2026-08-21 | deterministic implementation, 10-test reference suite, strict compile/build checks, and static artifact validation | Q01 | PASS |
| v1-q02 | 2026-08-21 | paced target-only baseline enqueue after five sub-ceiling CPU samples | Q02 | ENQUEUED_PENDING |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| Q00 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41087_wti_weekly_wr4_close_momentum_g0.md` |
| Q01 Build Validation | 2026-08-21 | PASS | `D:/QM/reports/framework/21/build_check_20260821_085956.json`; `D:/QM/reports/pipeline/QM5_41087/P1/P1_QM5_41087_result.json` |
| Q02 Baseline Screening | 2026-08-21 | ENQUEUED_PENDING | work item `e928a598-a8f3-4283-820b-4e6461fe0f52`; `docs/ops/evidence/2026-08-21_qm5_41087_wti_weekly_wr4_q01_q02_enqueue.md` |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and whole-host CPU ceilings. It does not authorize a manual backtest,
terminal control, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio-gate change, portfolio
admission, decorrelation claim, or correlation waiver.
