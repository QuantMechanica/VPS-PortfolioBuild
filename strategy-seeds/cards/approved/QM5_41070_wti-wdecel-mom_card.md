---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-WDECEL-MOM-2026_S01
variant_id: MOP-WTI-WDECEL-MOM-2026_S01
source_id: MOP-WTI-WDECEL-MOM-2026
ea_id: QM5_41070
slug: wti-wdecel-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41070_wti-wdecel-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-20
created_by: Research+Development
last_updated: 2026-08-20
g0_status: APPROVED
g0_decision: decisions/2026-08-20_qm5_41070_wti_weekly_deceleration_momentum_g0.md
source_approval: decisions/2026-08-20_wti_weekly_deceleration_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; Sections 3.1-3.2; Appendix A; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-WDECEL-MOM-2026/source.md"
    quality_tier: A
    role: own_return_sign_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-week-boundary-wti-two-adjacent-nonoverlapping-week-returns-same-strict-sign-newest-absolute-return-strictly-smaller-shared-sign-continuation-one-week-hold
sources:
  - "[[sources/MOP-WTI-WDECEL-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/weekly-trend-deceleration]]"
  - "[[concepts/wti-structural-trend]]"
indicators:
  - "[[indicators/adjacent-completed-week-log-returns]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, time-series-momentum, weekly-return-deceleration, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410700000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 8-18 completed WTI positions per full post-warm-up year after strict same-sign weekly deceleration and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 13
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_DECELERATION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a direct-WTI weekly deceleration sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact Monday anchors, three completed week-end closes, two disjoint weekly returns, strict common sign, strict newest-magnitude deceleration, shared-sign direction, one attempt, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, consecutive_monday_anchors, completed_week_endpoints, strict_same_sign, strict_newest_magnitude_deceleration, shared_sign_direction, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized build; R1 named-author peer-reviewed source with complete-read evidence and weekly deceleration translation risk disclosed; R2 exact clock, anchors, endpoints, sign and magnitude state, side, attempt, risk, and lifecycle; R3 registered native WTI D1 only; R4 deterministic arithmetic without banned signal or trained logic; canonical dedup CLEAN and manual family review separated acceleration, pullback, sign-handoff, relative-basket, monthly, and volatility-ranked identities."
---

# QM5_41070 WTI Completed-Week Deceleration Momentum

## Hypothesis

Two consecutive completed WTI weekly returns with the same sign and a
strictly smaller newest absolute move may identify a persistent trend that is
slowing without reversing. On the first tradable bar of a broker week, the
strategy follows that shared sign for one week.

The source establishes broad own-return continuation and WTI membership, not
this weekly horizon, deceleration state, standalone CFD result, or portfolio
relationship. The rule is falsifiable and carries no ex-ante profitability or
decorrelation claim.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-WDECEL-MOM-2026/source.md`, approved before
card extraction in
`decisions/2026-08-20_wti_weekly_deceleration_momentum_source_approval.md` at
commit `82b48303d`.

Moskowitz, Ooi, and Pedersen document own-return sign continuation over
monthly horizons and include NYMEX WTI in their futures universe. They do not
test weekly WTI, two adjacent same-sign weeks, an absolute-return deceleration
condition, continuous-CFD week-end closes, fixed-dollar ATR risk, or the QM
book. All weekly clock, endpoint, magnitude, execution, and risk choices below
are declared QM interpretations.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,557 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review fixes
the load-bearing boundaries:

- `QM5_41068_wti-waccel-mom` requires the same strict sign but a strictly
  larger newest magnitude; this card requires a strictly smaller newest move.
- `QM5_41069_wti-wpull-trend` requires opposed signs and follows the older
  sign after a smaller counterweek; this card rejects every opposed-sign pair
  and follows the shared sign.
- `QM5_41065_wti-wflip-mom` requires opposed signs and follows the newest sign
  without comparing magnitudes.
- `QM5_41066_xauxag-wdecay-rv` applies a smaller-magnitude state to two
  synchronized gold-minus-silver relative returns and fades their cumulative
  direction as an equal-notional basket; this card uses one WTI own-return
  series and continues its shared sign.
- `QM5_13049_xti-1w-mom-vol` and `QM5_21503_xti-weekly-tsmom-lowvol` use one
  return plus a volatility state; this card uses two returns and no volatility
  estimate or rank.
- `QM5_20239_wti-pulltrend` combines a twelve-month state ending one month
  before an opposed one-month move; this card uses two adjacent same-sign full
  weeks and no annual state.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI2
  commodity pullback, not symmetric weekly WTI return continuation.

Verdict:
`CLEAN_WTI_TWO_WEEK_SAME_SIGN_DECELERATION_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: exact D1; magic slot 0; magic `410700000`.
- Decision: first tradable normalized D1 bar of a new Monday-anchored broker
  week, within 180 elapsed raw-session minutes.
- Formation: three consecutive completed broker-week-end closes and two
  adjacent non-overlapping weekly log returns.
- Signal: both returns share a strict sign and the newest absolute return is
  strictly smaller; direction equals that shared sign.
- Normal exit: first tick whose broker Monday anchor is later than the open
  position's anchor.
- Expected cadence: approximately 8-18 completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `C1` be the newest completed broker-week-end close, `C2` the immediately
preceding week-end close, and `C3` the next older consecutive week-end close:

```text
r_new = ln(C1 / C2)
r_old = ln(C2 / C3)

r_old > 0 and r_new > 0 and abs(r_new) < abs(r_old) => BUY
r_old < 0 and r_new < 0 and abs(r_new) < abs(r_old) => SELL
otherwise                                            => FLAT
```

All endpoints are completed before the decision week begins. The current D1
open, high, low, or close never enters either return. Strict magnitude
equality is flat.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar under EA 41070 and
   magic slot zero.
2. Repair malformed, later-week, or stale owned exposure before entry-only
   gates.
3. Select offset zero when the raw current D1 date equals the broker date or
   `+1` day only when it is exactly one calendar day behind. Apply the same
   convention to every endpoint and reject every other or mixed convention.
4. Derive the current Monday anchor by subtracting the normalized weekday
   offset. Require the immediately preceding completed bar to have an older
   anchor, proving the current bar is the first tradable bar of this week.
5. Require attachment within 180 elapsed minutes of raw D1 bar open. Persist
   the current Monday anchor attempt before endpoint validation, signal,
   spread, quote, ATR, sizing, news, or order gates. Never retry that week.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker week.
7. Within the fixed 30-bar buffer, scan completed bars newest to oldest and
   select only the newest close belonging to each distinct prior Monday
   anchor. Require exactly the latest three anchors to be current anchor minus
   7, 14, and 21 calendar days, in strict reverse-time bar order, with positive
   finite closes.
8. Compute the two log returns. BUY only when both are strictly positive and
   the newest absolute return is strictly smaller. SELL only when both are
   strictly negative and the newest absolute return is strictly smaller.
   Opposed signs, zero, equality, or non-deceleration stay flat.
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
5. No Friday close, target, signal exit, trail, break-even move, partial exit,
   discretionary close, or intentional hold beyond the next week.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41070, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Uniform label normalization, first-week-bar clock, 180-minute grace,
  endpoint chronology, strict sign and magnitude state, durable attempt,
  spread, quote, ATR, sizing, and stop geometry all fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410700000`.
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
| `strategy_history_bars` | 30 | bounded D1 endpoint buffer |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return sign continuation and WTI
membership. They do not supply the weekly horizon, same-sign deceleration
condition, or CFD execution choices.

## QM Interpretations

`MOP-WTI-WDECEL-MOM-2026_S01` fixes the weekly horizon, strict same-sign
deceleration gate, continuous-CFD Monday anchors and week-end closes, label
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

Exact `XTIUSD.DWX` native D1 closes, broker time, symbol metadata, quotes,
completed-bar ATR, framework position/deal state, and persistent terminal
global-variable attempt state. No finite external dataset or calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are exhaustion after decelerating WTI weeks, weekend gaps,
  continuous-CFD roll/basis, energy-session label ambiguity, financing,
  spread, density below the floor, weekly source translation, and realized
  book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, wrong or
mixed labels, nonconsecutive Monday anchors, overlapping return intervals,
opposed-sign or non-decelerating entry, wrong side, current-week leakage, late
or repeated attempt, missing hard stop, wrong next-week close,
nondeterminism, or invalid fixed-risk mode.

Changing the WTI carrier, endpoint count, weekly horizon, sign or magnitude
condition, direction, attempt clock, risk, stop, or lifecycle requires a new
identity, binary, complete stream reconciliation, and portfolio
requalification. A failed result may not be rescued by accepting opposed
signs, equality, or acceleration, reversing the side, adding a return
threshold, changing the hold, or adding a calendar, volatility, or volume
filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, week anchors, endpoints, returns, strict sign/magnitude state, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-week and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; three consecutive
completed week ends; adjacent non-overlapping returns; positive and negative
deceleration directions; opposed-sign, equality, zero, and non-deceleration
flat states; no current-bar leakage; persistent weekly attempts; fixed-risk
frozen-stop sizing; next-week and stale repair; card lint; strict compile;
setfile schema; resolver identity; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-20 | initial WTI completed-week deceleration-momentum card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-20 | APPROVED | `decisions/2026-08-20_qm5_41070_wti_weekly_deceleration_momentum_g0.md` |
| Q01 Build Validation | - | NOT_RUN | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.

