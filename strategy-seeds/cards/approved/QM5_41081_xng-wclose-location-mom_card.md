---
card_schema_version: 2
type: strategy
strategy_id: MOP-XNG-WCLOSE-LOCATION-MOM-2026_S01
variant_id: MOP-XNG-WCLOSE-LOCATION-MOM-2026_S01
source_id: MOP-XNG-WCLOSE-LOCATION-MOM-2026
ea_id: QM5_41081
slug: xng-wclose-location-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41081_xng-wclose-location-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41081_xng_completed_week_close_location_momentum_g0.md
source_approval: decisions/2026-08-21_xng_completed_week_close_location_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-XNG-WCLOSE-LOCATION-MOM-2026/source.md"
    quality_tier: A
    role: own_return_sign_continuation_and_natural_gas_carrier_lineage
strategy_mechanic: normalized-week-boundary-xng-two-consecutive-completed-weekly-packages-parent-close-to-new-close-strict-return-sign-confirmed-by-newest-week-own-high-low-strict-close-location-outer-fifth-continuation-one-week-hold
sources:
  - "[[sources/MOP-XNG-WCLOSE-LOCATION-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-week-close-location]]"
  - "[[concepts/natural-gas-structural-trend]]"
indicators:
  - "[[indicators/completed-week-return-sign]]"
  - "[[indicators/completed-week-close-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, natural-gas, time-series-momentum, completed-week-close-location, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 410810000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-25 completed XNG positions per full post-warm-up year after strict history, close-location, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 16
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_CLOSE_LOCATION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a second-XNG completed-week close-location momentum sleeve whose information clock, symmetric direction, and one-week lifecycle differ from certified QM5_12567. Verify uniform energy labels, exact Monday anchors, two consecutive completed weekly packages, 3-5 sessions per week, newest-week high-low and final close, parent final close, strict return sign, strict 0.80/0.20 close-location agreement, one attempt, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, consecutive_monday_anchors, completed_weekly_ohlc, bounded_week_session_counts, parent_and_new_final_closes, strict_return_sign, strict_own_range_close_location, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized build; R1 named-author peer-reviewed source with complete-read evidence and weekly close-location translation risk disclosed; R2 exact clock, anchors, OHLC aggregation, endpoints, return sign, close-location thresholds, side, attempt, risk, and lifecycle; R3 registered native XNG D1 only; R4 deterministic arithmetic without banned signal or trained logic; canonical dedup CLEAN and manual family review separated the certified two-day oscillator pullback, monthly return sign, adjacent-week sign flip, ranked volatility/volume gates, and current-week breakout identities."
---

# QM5_41081 XNG Completed-Week Close-Location Momentum

## Hypothesis

The sign of natural gas's immediately completed broker-week return may
persist into the next week when that week also settles near the matching edge
of its own realized high-low range. At the first tradable bar of the next
week, the strategy follows a positive return only after a strict upper-fifth
close and follows a negative return only after a strict lower-fifth close.

The source establishes broad own-return continuation and natural-gas
membership, not this weekly close-location condition, a standalone
continuous-CFD result, or a portfolio relationship. The rule is falsifiable
and carries no ex-ante profitability or decorrelation claim.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-XNG-WCLOSE-LOCATION-MOM-2026/source.md`, approved
before card extraction in
`decisions/2026-08-21_xng_completed_week_close_location_momentum_source_approval.md`
at commit `2f2604d49`.

Moskowitz, Ooi, and Pedersen document own-return sign continuation over
monthly horizons and include natural gas in their futures universe. They do
not test weekly XNG, a completed-week close location, `0.80` / `0.20`
thresholds, continuous-CFD weekly packages, fixed-dollar ATR risk, or the QM
book. Every weekly clock, range-state, execution, and risk choice below is a
declared QM interpretation.

## Non-Duplicate Decision

The canonical pre-allocation checker included author and mechanic fields,
scanned 4,568 registry rows and 625 root cards, and returned `CLEAN`, with no
exact or fuzzy match. Manual review fixes the load-bearing boundaries:

- `QM5_12567_cum-rsi2-commodity` uses a long-only two-day cumulative-RSI2
  pullback, slow mean, and five-bar maximum hold. This card has no oscillator
  or mean, is symmetric, evaluates completed weeks, and owns one full week.
- `QM5_20204_xng-tsmom1m` follows one completed calendar-month return for a
  month without a weekly range-position condition.
- `QM5_41067_xng-wflip-mom` requires two adjacent non-overlapping weekly
  return signs to oppose and never aggregates a completed weekly high-low
  range. This card needs no older return or sign transition.
- `QM5_13101_xng-1w-mom-vol` and `QM5_21520_xng-flow-mom` gate rolling five-
  D1 returns with realized-volatility or native tick-volume ranks. This card
  uses neither rank nor volume.
- `QM5_41063_xng-week-nr7-brk` ranks seven completed weekly ranges and waits
  for a current-week price break. This card excludes current-week price from
  the signal and enters only at the boundary.
- `QM5_41080_wti-wclose-location-mom` is the exact WTI carrier sibling. This
  card is the separately predeclared natural-gas carrier falsification and
  inherits no WTI result.

Verdict:
`CLEAN_XNG_COMPLETED_WEEK_RETURN_SIGN_WITH_OWN_RANGE_CLOSE_LOCATION_CONFIRMATION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XNGUSD.DWX`.
- Timeframe: exact D1; magic slot 0; magic `410810000`.
- Decision: first tradable normalized D1 bar of a new Monday-anchored broker
  week, within 180 elapsed raw-session minutes.
- Formation: two consecutive completed broker-week packages, with three to
  five completed D1 sessions in each package.
- Normal exit: first tick whose broker Monday anchor is later than the open
  position's anchor.
- Expected cadence: approximately 10-25 completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `C0`, `H0`, and `L0` be the newest completed week's final close, high, and
low. Let `C1` be the parent completed week's final close:

```text
r   = ln(C0 / C1)
clv = (C0 - L0) / (H0 - L0)

r > 0 and clv > 0.80  => BUY
r < 0 and clv < 0.20  => SELL
otherwise              => FLAT
```

All values complete before the decision week begins. The current D1 open,
high, low, close, volume, and tick price never enter the signal. Exact zero,
equality at either threshold, invalid endpoints, or zero range is flat.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XNGUSD.DWX` D1 bar under EA 41081 and
   magic slot zero.
2. Repair malformed, later-week, or stale owned exposure before entry-only
   gates.
3. Select label offset zero when the raw current D1 date equals broker date
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
   days, strict reverse-time bar order, three to five bars per week, positive
   finite values, and a valid newest range.
8. Aggregate newest-week `H0=max(high)`, `L0=min(low)`, and
   `C0=chronologically final close`; select parent `C1=chronologically final
   close`. Compute `r` and `clv` exactly as above and require both finite.
9. Buy only on strict `r>0 && clv>0.80`. Sell only on strict
   `r<0 && clv<0.20`. Equality, zero, an interior close, or disagreement stays
   flat. Magnitude never changes size.
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

- Exact host, D1, EA 41081, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Uniform label normalization, first-week-bar clock, 180-minute grace,
  consecutive anchors, weekly session counts, OHLC/endpoints, strict return
  and close-location conjunction, durable attempt, spread, quote, ATR, sizing,
  and stop geometry all fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own at most one `XNGUSD.DWX` position under magic `410810000`.
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
| `strategy_history_bars` | 30 | bounded D1 weekly-OHLC buffer |
| `strategy_required_weeks` | 2 | exact completed weekly packages |
| `strategy_min_week_bars` | 3 | minimum sessions in each completed week |
| `strategy_max_week_bars` | 5 | maximum sessions in each completed week |
| `strategy_clv_upper` | 0.80 | strict long confirmation boundary |
| `strategy_clv_lower` | 0.20 | strict short confirmation boundary |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | XNG entry cost guard |
| `qm_friday_close_enabled` | false | full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return sign continuation and natural-
gas membership. They do not supply the weekly horizon or range-position gate.

## QM Interpretations

`MOP-XNG-WCLOSE-LOCATION-MOM-2026_S01` fixes the weekly horizon, completed
weekly packages, close-location thresholds, continuous-CFD Monday anchors and
label normalization, entry grace, persistent attempt, fixed-dollar ATR risk,
spread cap, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XNGUSD.DWX` native D1 OHLC/timestamps, broker time, symbol metadata,
quotes, completed-bar ATR, framework position/deal state, and persistent
terminal-global attempt state. No finite external dataset or calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false weekly continuation, natural-gas gaps, continuous-CFD
  roll/basis, energy-session label ambiguity, financing, spread, density below
  the floor, weekly source translation, and realized correlation with the
  incumbent XNG sleeve.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, wrong or
mixed labels, nonconsecutive Monday anchors, invalid session counts, OHLC, or
endpoints, entry at equality or outside the exact conjunction, wrong side,
current-week leakage, late or repeated attempt, missing hard stop, wrong next-
week close, nondeterminism, or invalid fixed-risk mode.

Changing the XNG carrier, weekly packages, return interval, either close-
location threshold, direction, attempt clock, risk, stop, or lifecycle
requires a new identity, binary, complete stream reconciliation, and portfolio
requalification. A failed result may not be rescued by accepting equality,
moving a threshold, dropping return-sign agreement, reversing the side,
changing the hold, or adding calendar, volatility, volume, moving-average,
inventory, or external state.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, week anchors, session counts, weekly OHLC/endpoints, return, close location, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-week and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; two consecutive
weekly packages; chronologically final close selection; three/four/five-
session acceptance and two/six-session rejection; newest-week high/low
aggregation; both strict direction/location conjunctions; equality and every
nearby disagreement flat; no current-bar leakage; persistent weekly attempts;
fixed-risk frozen-stop sizing; next-week and stale repair; card lint; strict
compile; setfile schema; resolver identity; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial XNG completed-week close-location momentum card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41081_xng_completed_week_close_location_momentum_g0.md` |
| Q01 Build Validation | pending | NOT_RUN | build required |
| Q02 Baseline Screening | pending | NOT_ENQUEUED | Q01 required |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.

