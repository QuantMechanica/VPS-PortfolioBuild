---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-WMID-OVERLAP-MOM-2026_S01
variant_id: MOP-WTI-WMID-OVERLAP-MOM-2026_S01
source_id: MOP-WTI-WMID-OVERLAP-MOM-2026
ea_id: QM5_41090
slug: wti-wmid-overlap-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41090_wti-wmid-overlap-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41090_wti_weekly_midpoint_overlap_momentum_g0.md
source_approval: decisions/2026-08-21_wti_weekly_midpoint_overlap_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-WMID-OVERLAP-MOM-2026/source.md"
    quality_tier: A
    role: own_price_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-week-boundary-wti-two-consecutive-completed-weekly-high-low-packages-strict-positive-range-overlap-strict-arithmetic-midpoint-drift-continuation-one-week-hold
sources:
  - "[[sources/MOP-WTI-WMID-OVERLAP-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-week-auction-midpoint-drift]]"
  - "[[concepts/wti-structural-trend]]"
indicators:
  - "[[indicators/completed-week-high-low-midpoint]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-week-midpoint-drift, overlapping-auction-ranges, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410900000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 20-40 completed WTI positions per full post-warm-up year after exact weekly history, strict positive range overlap, midpoint inequality, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 30
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_AUCTION_MIDPOINT_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a direct-WTI completed-week overlapping-auction midpoint trend outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact Monday anchors, two consecutive completed weekly high/low packages, three-to-five sessions each, strict positive overlap, strict midpoint direction, equality/non-overlap flat, one attempt, fixed risk, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, consecutive_monday_anchors, completed_weekly_high_low, bounded_week_session_counts, strict_positive_range_overlap, strict_midpoint_direction, equality_and_nonoverlap_flat, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized WTI sleeve; R1 complete-read peer-reviewed WTI source with weekly auction-midpoint translation risk disclosed; R2 exact labels, weeks, high/low overlap, midpoint side, attempt, risk, and lifecycle; R3 registered native WTI D1; R4 deterministic price arithmetic; canonical dedup CLEAN"
---

# QM5_41090 WTI Completed-Week Overlapping Auction-Midpoint Momentum

## Hypothesis

When the high/low center of WTI's completed weekly auction range shifts while
the new and old ranges still share a positive price interval, the market may
be accepting a gradual change in value rather than printing an isolated gap or
breakout. Following a strict upward or downward auction-midpoint shift for the
next broker week may capture a structural energy trend.

The direct WTI carrier is economically different from the certified
XAU/SP500/NDX/XNG book. That does not establish profitability, neutrality, or
decorrelation. Q02 owns frequency and baseline economics; unchanged Q09 alone
may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The sole source of record is
`strategy-seeds/sources/MOP-WTI-WMID-OVERLAP-MOM-2026/source.md`, authorized
before extraction by
`decisions/2026-08-21_wti_weekly_midpoint_overlap_momentum_source_approval.md`
at commit `1cd9eafe8`. The complete parent source hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons and include NYMEX WTI in their futures universe. They do not test a
weekly high/low midpoint, a range-overlap gate, a continuous CFD, fixed-dollar
ATR risk, or the QM book. Every weekly clock, auction-state, execution, and
risk choice below is a declared QM interpretation.

No source return, WTI-only alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, neutrality, or correlation statistic is
imported.

## Non-Duplicate Decision

The canonical pre-allocation checker included author and complete-mechanic
fields, scanned 4,579 registry identities and 625 root cards, and returned
`CLEAN` with no exact or fuzzy match. Manual semantic review fixes the
load-bearing boundaries:

- `QM5_41089_wti-wrange-migrate-mom` requires both weekly endpoints to move
  strictly in the same direction and can accept disjoint ranges. This card
  requires strict overlap and compares only the high/low midpoints; one
  endpoint may move against the other while the center still shifts.
- `QM5_41073_wti-woutside-settle` requires a strict higher high and lower low,
  settlement outside the parent range, own-week body direction, and an outer-
  quartile close. This card rejects non-overlap and reads no open or close.
- `QM5_41080_wti-wclose-location-mom` follows return sign when the newest close
  finishes in the matching edge of its own range. This card reads no close and
  has no location threshold.
- `QM5_41087_wti-wr4-close-mom` ranks four weekly widths and requires
  body/close-location agreement. This card ranks no width and reads exactly
  two completed weeks.
- `QM5_41061_wti-week-nr7-brk`, `QM5_13075_xti-inside-week-brk`, and
  `QM5_12965_wti-week-orb` wait for a current-week breakout. This card excludes
  all current-week signal price and enters only at the boundary.
- the WTI weekly return-path family classifies completed closes and return
  signs or magnitudes. This card classifies completed-week highs, lows,
  overlap, and arithmetic midpoints only.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG cumulative-RSI2
  pullback under a slow trend filter on a different carrier.

The exact WTI carrier, two immediate consecutive completed Monday-anchored
weekly packages, three-to-five sessions each, strict positive overlap, strict
arithmetic midpoint direction, equality/non-overlap-flat rule, first-new-week
entry, durable attempt, fixed risk, and next-week lifecycle are jointly
load-bearing. Verdict:
`CLEAN_WTI_COMPLETED_WEEK_OVERLAPPING_AUCTION_MIDPOINT_DRIFT_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target symbol: exact `XTIUSD.DWX`.
- Timeframe: exact D1; magic slot 0; planned magic `410900000`.
- Decision: first tradable normalized D1 bar of a new Monday-anchored broker
  week, within 180 elapsed raw-session minutes.
- Formation: the two immediately preceding consecutive completed broker-week
  high/low packages, with three to five completed sessions each.
- Normal exit: first tick whose broker Monday anchor is later than the open
  position's anchor.
- Expected trade frequency: approximately 20-40 completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `H0` and `L0` be the newest completed week's aggregate high and low, and
`H1` and `L1` its consecutive parent's aggregate high and low:

```text
M0 = L0 + 0.5 * (H0 - L0)
M1 = L1 + 0.5 * (H1 - L1)
Olow  = max(L0, L1)
Ohigh = min(H0, H1)

require Olow < Ohigh

M0 > M1  => BUY
M0 < M1  => SELL
otherwise => FLAT
```

All values complete before the decision week begins. The current D1 open,
high, low, close, volume, and tick price never enter the signal. Equal
midpoints, touch-only or disjoint ranges, invalid geometry, or incomplete
history stay flat. Midpoint distance and overlap width never change
eligibility or risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar under EA 41090 and
   magic slot zero.
2. Repair malformed, later-week, or stale owned exposure before entry-only
   gates.
3. Select label offset zero when the raw current D1 date equals broker date,
   or `+1` day only when it is exactly one calendar day behind. Apply the same
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
   days, strict reverse-time bar order, three to five unique sessions per week,
   positive finite highs/lows, and strict positive aggregate ranges.
8. Require `max(L0,L1) < min(H0,H1)`. Touch-only and disjoint ranges stay flat.
   Compute each midpoint as `low + 0.5*(high-low)`. Buy only when the newest
   midpoint is strictly higher and sell only when it is strictly lower.
   Equality stays flat.
9. Require a valid executable quote and no genuinely positive spread wider
   than 1,500 points. Modeled zero `.DWX` spread is valid.
10. Attach one frozen hard stop at `3.5 * ATR(20,D1)` from completed data and
    size one position to `RISK_FIXED=1000`. Use no take-profit.
11. Submit one slot-zero market order once. No pending order, retry, scale-in,
    grid, martingale, pyramid, hedge, or second entry exists.

## 5. Exit Rules

1. Broker hard stop and framework kill-switch closure remain authoritative.
2. Immediately flatten duplicate, wrong-symbol, wrong-magic, missing-stop,
   invalid-volume, or invalid-open-time exposure.
3. Close on the first tick whose broker Monday anchor is later than the
   position-open Monday anchor.
4. Close after ten elapsed calendar days as a stale safety repair.
5. No Friday close, target, signal flip, trail, break-even move, partial exit,
   discretionary close, or intentional hold beyond the next week.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41090, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Uniform label normalization, first-week-bar clock, 180-minute grace,
  consecutive anchors, session counts, high/low aggregation, strict overlap,
  strict midpoint direction, durable attempt, spread, quote, ATR, sizing, and
  stop geometry fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410900000`.
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
| `strategy_history_bars` | 30 | bounded D1 weekly high/low buffer |
| `strategy_required_weeks` | 2 | exact consecutive completed packages |
| `strategy_min_week_bars` | 3 | minimum sessions in each completed week |
| `strategy_max_week_bars` | 5 | maximum sessions in each completed week |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-price continuation lineage and WTI
membership. They do not supply the weekly horizon, high/low midpoint, or
overlap state.

## QM Interpretations

`MOP-WTI-WMID-OVERLAP-MOM-2026_S01` fixes the weekly horizon, completed weekly
high/low packages, strict positive overlap, arithmetic midpoint comparisons,
equality/non-overlap rejection, continuous-CFD Monday anchors and label
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

Exact `XTIUSD.DWX` native D1 high/low/timestamps, broker time, symbol metadata,
quotes, completed-bar ATR, framework position/deal state, and persistent
terminal-global attempt state. No finite external dataset or calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false weekly continuation, weekend gaps, continuous-CFD
  roll/basis, energy-session label ambiguity, financing, spread, density below
  the floor, weekly source translation, and realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, wrong or
mixed labels, nonconsecutive Monday anchors, invalid session counts or
high/low state, entry at midpoint equality or without strict overlap, wrong
side, current-week leakage, late or repeated attempt, missing hard stop, wrong
next-week close, nondeterminism, or invalid fixed-risk mode.

Changing the WTI carrier, weekly packages, overlap or midpoint comparisons,
direction, attempt clock, risk, stop, or lifecycle requires a new identity,
binary, complete stream reconciliation, and portfolio requalification. A
failed result may not be rescued by accepting equality or non-overlap, adding
an open/close or current-week gate, reversing the side, changing the hold, or
adding displacement, range-width, calendar, return, close-location,
volatility, volume, moving-average, inventory, event, or external state.

## Strategy Allowability Check

- [x] R1: one bounded source ID with named peer-reviewed authors, DOI,
  complete-paper evidence, durable retrieval hash, and explicit WTI membership;
  weekly auction-midpoint translation risk is disclosed.
- [x] R2: exact clock, labels, anchors, sessions, high/low aggregation, overlap,
  midpoint comparisons, side, attempt, hard stop, spread, and lifecycle are
  mechanical.
- [x] R3: registered `XTIUSD.DWX` D1 plus native V5 execution state supplies
  all runtime inputs; energy-label and continuous-CFD basis risk remain open.
- [x] R4: deterministic timestamp, high/low arithmetic, comparison, ATR, quote,
  position, deal-history, and terminal-state logic only; no prohibited
  mechanism.
- [x] Dedup: canonical checker clean; manual weekly WTI family review found no
  exact identity.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, week anchors, sessions, high/low aggregation, overlap, midpoint state, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-week and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; two consecutive
weekly packages; three/four/five-session acceptance and two/six-session
rejection; exact high/low aggregation; positive overlap and touch/disjoint
rejection; long, short, and equal-midpoint states; no current-bar leakage;
persistent weekly attempts; fixed-risk frozen-stop sizing; next-week and stale
repair; card lint; strict compile; setfile schema; resolver identity; and static
artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial WTI overlapping auction-midpoint card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41090_wti_weekly_midpoint_overlap_momentum_g0.md` |
| Q01 Build Validation | - | PENDING | approved build has not yet entered |
| Q02 Baseline Screening | - | NOT_QUEUED | requires Q01 PASS and fresh capacity check |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or `T_Live` manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
