---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-WOUTSIDE-SETTLE-2026_S01
variant_id: MOP-WTI-WOUTSIDE-SETTLE-2026_S01
source_id: MOP-WTI-WOUTSIDE-SETTLE-2026
ea_id: QM5_41073
slug: wti-woutside-settle
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41073_wti-woutside-settle_card.md
execution_contract_status: APPROVED
created: 2026-08-20
created_by: Research+Development
last_updated: 2026-08-20
g0_status: APPROVED
g0_decision: decisions/2026-08-20_qm5_41073_wti_weekly_outside_settlement_momentum_g0.md
source_approval: decisions/2026-08-20_wti_weekly_outside_settlement_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; Sections 3.1-3.2; Appendix A; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-WOUTSIDE-SETTLE-2026/source.md"
    quality_tier: A
    role: own_return_sign_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-week-boundary-wti-two-consecutive-completed-weekly-ohlc-packages-strict-higher-high-and-lower-low-own-week-direction-parent-extreme-settlement-strict-outer-quartile-continuation-one-week-hold
sources:
  - "[[sources/MOP-WTI-WOUTSIDE-SETTLE-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-outside-week-settlement]]"
  - "[[concepts/wti-structural-trend]]"
indicators:
  - "[[indicators/completed-week-ohlc]]"
  - "[[indicators/close-location-arithmetic]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, time-series-momentum, completed-outside-week, parent-extreme-settlement, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410730000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 3-10 completed WTI positions per full post-warm-up year after strict outside-range, settlement, close-location, and execution gates; Q02 must prove at least three/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_RANGE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a direct-WTI weekly outside-settlement sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact Monday anchors, two consecutive completed weekly OHLC packages, 3-5 sessions each, strict outside range, own-week direction, settlement beyond the parent extreme, strict outer-quartile close, one attempt, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, consecutive_monday_anchors, completed_weekly_ohlc, bounded_week_session_counts, strict_outside_range, own_week_direction, parent_extreme_settlement, strict_outer_quartile, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized build; R1 named-author peer-reviewed source with complete-read evidence and weekly range translation risk disclosed; R2 exact clock, anchors, OHLC aggregation, outside geometry, settlement, close location, side, attempt, risk, and lifecycle; R3 registered native WTI D1 only; R4 deterministic arithmetic without banned signal or trained logic; canonical dedup CLEAN and manual family review separated the existing outside-week reversal, NR7/current-week breakout, opening-range, weekly return-path, and oscillator identities."
---

# QM5_41073 WTI Completed-Week Outside-Settlement Momentum

## Hypothesis

A completed WTI week that expands beyond both sides of its parent week, then
survives to settle beyond one parent extreme and in its own matching outer
quartile, may identify unusually persistent weekly price discovery. On the
first tradable bar of the next broker week, the strategy follows the completed
week's open-to-close direction for one week.

The source establishes broad own-return continuation and WTI membership, not
this weekly outside-range condition, parent-extreme settlement, outer-quartile
gate, standalone CFD result, or portfolio relationship. The rule is
falsifiable and carries no ex-ante profitability or decorrelation claim.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-WOUTSIDE-SETTLE-2026/source.md`, approved
before card extraction in
`decisions/2026-08-20_wti_weekly_outside_settlement_momentum_source_approval.md`
at commit `c276afbdd`.

Moskowitz, Ooi, and Pedersen document own-return sign continuation over
monthly horizons and include NYMEX WTI in their futures universe. They do not
test weekly WTI, completed-week high/low containment, settlement beyond a
parent range, close-location thresholds, continuous-CFD weekly aggregation,
fixed-dollar ATR risk, or the QM book. All weekly clock, OHLC, state,
execution, and risk choices below are declared QM interpretations.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,560 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review fixes
the load-bearing boundaries:

- `QM5_13095_xti-outweek-fade` waits for a separate current-week D1
  reversal/reclaim, uses SMA and ATR-range context, then trades against the
  completed outside-week extreme. This card enters only at the next week
  boundary, requires the completed outside week to settle beyond its parent
  range in the matching outer quartile, and follows that direction without a
  separate reversal bar or SMA signal.
- `QM5_41061_wti-week-nr7-brk` requires seven-week compression and then a
  current-week breakout. This card requires a two-week outside expansion that
  is already complete before entry.
- `QM5_12965_wti-week-orb` constructs an opening range from the current
  week's first D1 bar and waits for its later break. This card excludes all
  current-week OHLC from the signal.
- `QM5_41068_wti-waccel-mom` and `QM5_41070_wti-wdecel-mom` compare two
  adjacent completed-week close-to-close returns without weekly high/low
  containment or parent-extreme settlement.
- `QM5_41065_wti-wflip-mom`, `QM5_41069_wti-wpull-trend`,
  `QM5_41071_wti-wresume-dom`, and `QM5_41072_wti-wcounter-dom` use return
  paths rather than a strict outside range and settlement geometry.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI2
  commodity pullback, not symmetric weekly WTI continuation.

Verdict:
`CLEAN_WTI_COMPLETED_OUTSIDE_WEEK_SETTLEMENT_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: exact D1; magic slot 0; magic `410730000`.
- Decision: first tradable normalized D1 bar of a new Monday-anchored broker
  week, within 180 elapsed raw-session minutes.
- Formation: two consecutive completed broker-week OHLC packages, each with
  three to five completed D1 sessions.
- Signal: strict higher high and lower low, completed-week open-to-close sign,
  close beyond the matching parent extreme, and strict matching outer quartile.
- Normal exit: first tick whose broker Monday anchor is later than the open
  position's anchor.
- Expected cadence: approximately 3-10 completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `O1`, `H1`, `L1`, and `C1` be the immediately completed broker week's
first-session open, maximum high, minimum low, and last-session close. Let
`H2` and `L2` be the consecutive parent week's extrema:

```text
outside = H1 > H2 and L1 < L2
clv     = (C1 - L1) / (H1 - L1)

outside and C1 > O1 and C1 > H2 and clv > 0.75    => BUY
outside and C1 < O1 and C1 < L2 and clv < 0.25    => SELL
otherwise                                          => FLAT
```

All values are completed before the decision week begins. The current D1
open, high, low, or close never enters the signal. Equality at either parent
extreme or close-location boundary is flat. Zero or invalid range is flat.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar under EA 41073 and
   magic slot zero.
2. Repair malformed, later-week, or stale owned exposure before entry-only
   gates.
3. Select offset zero when the raw current D1 date equals the broker date or
   `+1` day only when it is exactly one calendar day behind. Apply the same
   convention to every historical bar and reject every other or mixed state.
4. Derive the current Monday anchor from normalized time. Require the newest
   completed bar to have an older anchor, proving the current bar is the first
   tradable bar of this week.
5. Require attachment within 180 elapsed minutes of raw D1 bar open. Persist
   the current Monday-anchor attempt before aggregation, signal, spread,
   quote, ATR, sizing, news, or order gates. Never retry that week.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker week.
7. Within the fixed 30-bar buffer, aggregate exactly the immediately completed
   week and its parent. Require anchors at current minus 7 and 14 calendar
   days, strict reverse-time bar order, three to five bars per week, and
   positive finite OHLC with `high >= max(open,close)` and
   `low <= min(open,close)` for every bar.
8. For each week take the chronologically first bar's open, maximum high,
   minimum low, and chronologically last bar's close. Require the newer week
   to have a strict higher high and lower low than the parent.
9. Require positive finite newer-week range. Buy only when its close is
   strictly above its open and parent high and its close location is strictly
   greater than `0.75`. Sell only when its close is strictly below its open
   and parent low and its close location is strictly less than `0.25`.
   Every equality or other state stays flat.
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

- Exact host, D1, EA 41073, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Uniform label normalization, first-week-bar clock, 180-minute grace,
  consecutive anchors, weekly session counts, OHLC validity, strict outside
  state, own-week direction, parent settlement, strict close location,
  durable attempt, spread, quote, ATR, sizing, and stop geometry all fail
  closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410730000`.
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
| `strategy_history_bars` | 30 | bounded D1 OHLC buffer |
| `strategy_min_week_bars` | 3 | minimum sessions in each completed week |
| `strategy_max_week_bars` | 5 | maximum sessions in each completed week |
| `strategy_close_quartile` | 0.75 | strict close-location threshold |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return sign continuation and WTI
membership. They do not supply the weekly horizon, outside geometry,
parent-extreme settlement, or close-location gate.

## QM Interpretations

`MOP-WTI-WOUTSIDE-SETTLE-2026_S01` fixes the weekly horizon, two completed
OHLC packages, strict outside state, own-week direction, settlement and
quartile gates, continuous-CFD Monday anchors and label normalization, entry
grace, persistent attempt, fixed-dollar ATR risk, spread cap, and lifecycle.

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
- Major risks are false weekly range expansion, weekend gaps, continuous-CFD
  roll/basis, energy-session label ambiguity, financing, spread, density below
  the floor, weekly source translation, and realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than three completed
positions per full post-warm-up year, nonpositive governed economics, wrong or
mixed labels, nonconsecutive Monday anchors, invalid session counts or OHLC,
non-outside entry, inside-parent settlement, wrong own-week sign, non-extreme
close, threshold equality entry, wrong side, current-week leakage, late or
repeated attempt, missing hard stop, wrong next-week close, nondeterminism, or
invalid fixed-risk mode.

Changing the WTI carrier, weekly aggregation, outside state, own-direction
requirement, parent settlement, quartile boundary, direction, attempt clock,
risk, stop, or lifecycle requires a new identity, binary, complete stream
reconciliation, and portfolio requalification. A failed result may not be
rescued by accepting equality, moving the quartile boundary, dropping parent
settlement, reversing the side, adding a return threshold, changing the hold,
or adding a calendar, volatility, volume, moving-average, or external filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, week anchors, weekly OHLC, session counts, outside/settlement/close-location state, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-week and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; two consecutive
completed weekly OHLC aggregates; first-session open and last-session close;
three/four/five-session acceptance and two/six-session rejection; both strict
outside directions; parent-extreme settlement; close-location arithmetic;
equality, inside, non-outside, wrong-own-direction, and zero-range flat states;
no current-bar leakage; persistent weekly attempts; fixed-risk frozen-stop
sizing; next-week and stale repair; card lint; strict compile; setfile schema;
resolver identity; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-20 | initial WTI completed-week outside-settlement card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-20 | APPROVED | `decisions/2026-08-20_qm5_41073_wti_weekly_outside_settlement_momentum_g0.md` |
| Q01 Build Validation | - | NOT_RUN | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.

