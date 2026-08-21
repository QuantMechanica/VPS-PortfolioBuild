---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-WDAYBREADTH4-MOM-2026_S01
variant_id: MOP-WTI-WDAYBREADTH4-MOM-2026_S01
source_id: MOP-WTI-WDAYBREADTH4-MOM-2026
ea_id: QM5_41084
slug: wti-wdaybreadth-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41084_wti-wdaybreadth-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41084_wti_weekly_daily_sign_breadth_momentum_g0.md
source_approval: decisions/2026-08-21_wti_weekly_daily_sign_breadth_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; Sections 3.1-3.2; Appendix A; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-WDAYBREADTH4-MOM-2026/source.md"
    quality_tier: A
    role: own_return_sign_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-week-boundary-wti-parent-final-close-plus-exact-five-newest-week-session-closes-five-adjacent-daily-log-return-signs-four-of-five-breadth-and-weekly-net-sign-agreement-continuation-one-week-hold
sources:
  - "[[sources/MOP-WTI-WDAYBREADTH4-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/within-week-directional-breadth]]"
  - "[[concepts/wti-structural-trend]]"
indicators:
  - "[[indicators/adjacent-daily-return-sign-count]]"
  - "[[indicators/completed-week-net-return]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, time-series-momentum, daily-sign-breadth, weekly-net-confirmation, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410840000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-20 completed WTI positions per full post-warm-up year after the exact five-session, four-of-five daily-sign breadth, weekly-net agreement, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 14
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_DAILY_BREADTH_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01_PASS
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify a direct-WTI weekly directional-breadth sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact Monday anchors, parent final close, exactly five newest-week session closes, five adjacent daily return signs, strict four-of-five breadth, same-sign weekly net, one attempt, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, consecutive_monday_anchors, exact_five_session_newest_week, parent_final_close, five_adjacent_daily_returns, strict_four_of_five_sign_breadth, strict_weekly_net_agreement, zero_counts_neither, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized build; R1 named-author peer-reviewed source with complete-read evidence and weekly daily-breadth translation risk disclosed; R2 exact clock, anchors, endpoints, session count, return orientation, zero handling, breadth/net conjunction, side, attempt, risk, and lifecycle; R3 registered native WTI D1 only; R4 deterministic arithmetic without banned signal or trained logic; canonical dedup CLEAN and manual family review separated weekly close-location, fixed-weekday endpoints, multi-week paths, flow decomposition, monthly sign breadth, and volatility-ranked five-D1 return identities."
---

# WTI Completed-Week Daily-Sign Breadth Momentum

## Hypothesis

WTI's immediately completed broker week may carry more persistent directional
information when the weekly move is broadly shared across its component daily
close-to-close intervals. At the first tradable bar of the next week, the
strategy follows the weekly direction only when at least four of exactly five
daily returns share that strict sign and the complete weekly net return agrees.

The source establishes broad own-return continuation and WTI membership, not
this weekly daily-sign breadth condition, standalone continuous-CFD result, or
portfolio relationship. The rule is falsifiable and carries no ex-ante
profitability or decorrelation claim.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-WDAYBREADTH4-MOM-2026/source.md`, approved
before card extraction in
`decisions/2026-08-21_wti_weekly_daily_sign_breadth_momentum_source_approval.md`
at commit `8ca5ed7fa`.

Moskowitz, Ooi, and Pedersen document own-return sign continuation over
monthly horizons and include NYMEX WTI in their futures universe. They do not
test weekly WTI, five daily component signs, a four-of-five threshold,
weekly-net confirmation, continuous-CFD week packages, fixed-dollar ATR risk,
or the QM book. All weekly clock, endpoint, breadth, execution, and risk
choices below are declared QM interpretations.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,571 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review fixes
the load-bearing boundaries:

- `QM5_41080_wti-wclose-location-mom` combines one completed weekly return
  sign with the newest week's own high-low close location. It never counts the
  five daily component signs.
- `QM5_41020_wti-wclose-mom` uses fixed Tuesday and Friday endpoints, enters
  Monday, and exits Wednesday. This card uses every daily interval of one
  exact five-session week and owns the complete next week.
- `QM5_41065` through `QM5_41074` and `QM5_41082` classify multi-week return
  signs, magnitudes, ranges, or settlement states. This card measures
  directional participation within one completed week.
- `QM5_41029` through `QM5_41036` classify session versus overnight flows.
  This card uses adjacent close-to-close returns and no flow decomposition.
- `QM5_13150_wti-signmom`, `QM5_20244_wti-trend-sign`, and
  `QM5_20273_wti-signrun-tr` operate on twelve completed monthly returns and a
  monthly renewal clock, not five daily returns under a weekly clock.
- `QM5_13049_xti-1w-mom-vol` gates one five-D1 magnitude return with a rolling
  volatility rank. It does not count the component return signs.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI2
  commodity pullback, not symmetric weekly WTI continuation.

Verdict:
`CLEAN_WTI_EXACT_FIVE_SESSION_DAILY_SIGN_BREADTH_WITH_WEEKLY_NET_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: exact D1; magic slot 0; magic `410840000`.
- Decision: first tradable normalized D1 bar of a new Monday-anchored broker
  week, within 180 elapsed raw-session minutes.
- Formation: the parent completed week's final close plus exactly five
  chronological closes in the immediately completed broker week.
- Signal: at least four of the five adjacent daily log returns share one
  strict sign and the parent-final-to-newest-final weekly net shares it.
- Normal exit: first tick whose broker Monday anchor is later than the open
  position's anchor.
- Expected cadence: approximately 10-20 completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `C0` be the parent completed week's chronologically final close and `C1`
through `C5` the immediately completed week's five chronological D1 closes:

```text
r1 = ln(C1 / C0)
r2 = ln(C2 / C1)
r3 = ln(C3 / C2)
r4 = ln(C4 / C3)
r5 = ln(C5 / C4)
weekly_net = ln(C5 / C0)

positive_count >= 4 and weekly_net > 0  => BUY
negative_count >= 4 and weekly_net < 0  => SELL
otherwise                               => FLAT
```

Each `ri > 0` increments `positive_count`; each `ri < 0` increments
`negative_count`; exact zero increments neither. All endpoints complete before
the decision week begins. Current-week OHLC never enters the signal. Equality,
an opposed net sign, fewer or more than five newest-week sessions, or an
invalid endpoint is flat.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar under EA 41084 and
   magic slot zero.
2. Repair malformed, later-week, or stale owned exposure before entry-only
   gates.
3. Select label offset zero when the raw current D1 date equals broker date or
   `+1` day only when it is exactly one calendar day behind. Apply the same
   convention to every historical bar and reject every other or mixed state.
4. Derive the current Monday anchor from normalized time. Require the newest
   completed bar to have an older anchor, proving the current bar is the first
   tradable bar of this week.
5. Require attachment within 180 elapsed minutes of raw D1 bar open. Persist
   the current Monday-anchor attempt before history, signal, spread, quote,
   ATR, sizing, news, or order gates. Never retry that week.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker week.
7. Within a fixed 30-bar buffer, reconstruct exactly the immediately completed
   week and its parent. Require anchors at current minus 7 and 14 calendar
   days, strict reverse-time bar order, exactly five newest-week sessions,
   three to five parent-week sessions, positive finite closes, and a unique
   chronologically final parent close.
8. Order the newest week's five closes chronologically as `C1..C5` and pair
   them with parent final close `C0`. Compute exactly the five adjacent log
   returns and `weekly_net` shown above. Require all values finite.
9. Count strict positive and strict negative component returns; zero counts
   toward neither. Buy only on `positive_count>=4 && weekly_net>0`. Sell only
   on `negative_count>=4 && weekly_net<0`. Equality, insufficient breadth,
   net disagreement, or any other state stays flat. Magnitude never changes
   size.
10. Require a valid executable quote and no genuinely positive spread wider
    than 1,500 points. Modeled zero `.DWX` spread is valid.
11. Attach one frozen hard stop at `3.5 * ATR(20,D1)` from completed data and
    size one position to `RISK_FIXED=1000`. Use no take-profit.
12. Submit one slot-zero market order once. No pending order, retry, scale-in,
    grid, martingale, pyramid, hedge, or second entry exists.

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

- Exact host, D1, EA 41084, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Uniform label normalization, first-week-bar clock, 180-minute grace,
  consecutive anchors, newest and parent session counts, endpoints, return
  orientation, strict breadth/net conjunction, durable attempt, spread,
  quote, ATR, sizing, and stop geometry all fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410840000`.
- Persist the last attempted Monday anchor across restart.
- Manage malformed, later-week, stale, and kill-switch exits before entry.
- Freeze the original hard stop; never widen, trail, or remove it.
- Do not retry, add, pyramid, grid, martingale, partially close, hedge, or
  reverse inside the week.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | exact first-week-bar execution window |
| `strategy_history_bars` | 30 | bounded D1 weekly-session buffer |
| `strategy_required_sessions` | 5 | exact newest-week session count |
| `strategy_min_same_sign` | 4 | daily-sign breadth threshold |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return sign continuation and WTI
membership. They do not supply the weekly horizon, five daily component
returns, breadth threshold, or weekly-net conjunction.

## QM Interpretations

`MOP-WTI-WDAYBREADTH4-MOM-2026_S01` fixes the weekly horizon, exact
five-session requirement, parent endpoint, daily close-to-close orientation,
four-of-five breadth threshold, weekly-net agreement, continuous-CFD label
normalization, entry grace, persistent attempt, fixed-dollar ATR risk, spread
cap, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 OHLC, broker time, symbol metadata, quotes,
completed-bar ATR, framework position/deal state, and persistent terminal
global-variable attempt state. No finite external dataset or calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are short-horizon reversal, weekend gaps, holiday-week
  attrition, continuous-CFD roll/basis, energy-session label ambiguity,
  financing, spread, density below the floor, weekly source translation, and
  realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, wrong or
mixed labels, nonconsecutive Monday anchors, a newest week with other than
five sessions, wrong parent endpoint, overlapping or reversed return
intervals, wrong sign counts, absent strict weekly-net agreement, wrong side,
current-week leakage, late or repeated attempt, missing hard stop, wrong next-
week close, nondeterminism, or invalid fixed-risk mode.

Changing the WTI carrier, session count, breadth threshold, weekly-net
conjunction, return orientation, weekly horizon, direction, attempt clock,
risk, stop, or lifecycle requires a new identity, binary, complete stream
reconciliation, and portfolio requalification. A failed result may not be
rescued by accepting a four-session week, lowering the breadth threshold,
removing the net check, accepting equality, reversing the side, changing the
hold, or adding a return-magnitude, calendar, volatility, or volume filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, week anchors, sessions, endpoints, returns, breadth/net state, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-week and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; exact parent and
newest anchors; exactly five newest-week sessions; chronological `C0..C5`;
five adjacent returns; both four-positive and four-negative directions;
five-of-five eligibility; three-of-five, zero, equality, opposed-weekly-net,
holiday-week, missing-parent, and mixed-label flat states; no current-bar
leakage; persistent weekly attempts; fixed-risk frozen-stop sizing; next-week
and stale repair; card lint; strict compile; setfile schema; resolver identity;
and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial WTI completed-week daily-sign breadth momentum card | Q00 | APPROVED |
| v1-build | 2026-08-21 | deterministic implementation, 10-test reference suite, strict compile/build checks, and static artifact validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| Q00 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41084_wti_weekly_daily_sign_breadth_momentum_g0.md` |
| Q01 Build Validation | 2026-08-21 | PASS | `D:/QM/reports/framework/21/build_check_20260821_050727.json`; `D:/QM/reports/pipeline/QM5_41084/P1/P1_QM5_41084_result.json` |
| Q02 Baseline Screening | 2026-08-21 | NOT_ENQUEUED | paced enqueue only after Q01 PASS and capacity checks |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
