---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-WSTREAK3-MOM-2026_S01
variant_id: MOP-WTI-WSTREAK3-MOM-2026_S01
source_id: MOP-WTI-WSTREAK3-MOM-2026
ea_id: QM5_41074
slug: wti-wstreak3-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41074_wti-wstreak3-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-20
created_by: Research+Development
last_updated: 2026-08-20
g0_status: APPROVED
g0_decision: decisions/2026-08-20_qm5_41074_wti_three_week_sign_streak_momentum_g0.md
source_approval: decisions/2026-08-20_wti_three_week_sign_streak_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; Sections 3.1-3.2; Appendix A; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-WSTREAK3-MOM-2026/source.md"
    quality_tier: A
    role: own_return_sign_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-week-boundary-wti-five-consecutive-completed-week-ending-closes-four-adjacent-weekly-returns-newest-three-strict-same-sign-preceding-strict-opposite-sign-fresh-three-week-streak-continuation-one-week-hold
sources:
  - "[[sources/MOP-WTI-WSTREAK3-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/fresh-three-week-sign-streak]]"
  - "[[concepts/wti-structural-trend]]"
indicators:
  - "[[indicators/completed-week-ending-close]]"
  - "[[indicators/log-return-sign]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, time-series-momentum, fresh-three-week-streak, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410740000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 4-10 completed WTI positions per full post-warm-up year after strict fresh-streak, history, and execution gates; Q02 must prove at least three/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_PATH_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
q01_build_report: D:/QM/reports/framework/21/build_check_20260820_194801.json
q01_p1_evidence: D:/QM/reports/pipeline/QM5_41074/P1/P1_QM5_41074_result.json
review_focus: "Falsify a direct-WTI fresh three-week sign-streak sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact Monday anchors, five consecutive completed weekly endpoints, 3-5 sessions per week, four adjacent return formulas, strict -+++ / +--- state, one attempt, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, consecutive_monday_anchors, completed_week_endpoints, bounded_week_session_counts, strict_return_signs, fresh_three_week_transition, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized build; R1 named-author peer-reviewed source with complete-read evidence and weekly path translation risk disclosed; R2 exact clock, anchors, endpoints, return formulas, strict sign transition, side, attempt, risk, and lifecycle; R3 registered native WTI D1 only; R4 deterministic arithmetic without banned signal or trained logic; canonical dedup CLEAN and manual family review separated immediate handoff, acceleration/deceleration, pullback/resumption/countershock, split-week, monthly sign-path, range, and oscillator identities."
---

# QM5_41074 WTI Fresh Three-Week Sign-Streak Momentum

## Hypothesis

The first appearance of three consecutive same-direction completed WTI weeks
after an opposite-direction week may identify a newly persistent medium-short
price-discovery regime. On the first tradable bar of the next broker week, the
strategy follows that fresh three-week streak for one week.

The source establishes broad own-return continuation and WTI membership, not
this weekly streak condition, opposite predecessor, standalone CFD result, or
portfolio relationship. The rule is falsifiable and carries no ex-ante
profitability or decorrelation claim.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-WSTREAK3-MOM-2026/source.md`, approved before
card extraction in
`decisions/2026-08-20_wti_three_week_sign_streak_momentum_source_approval.md`
at commit `c0fe1591d`.

Moskowitz, Ooi, and Pedersen document own-return sign continuation over
monthly horizons and include NYMEX WTI in their futures universe. They do not
test weekly WTI, three consecutive weekly signs, a preceding opposite week,
continuous-CFD weekly endpoints, fixed-dollar ATR risk, or the QM book. All
weekly clock, path-state, execution, and risk choices below are declared QM
interpretations.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,561 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review fixes
the load-bearing boundaries:

- `QM5_41065_wti-wflip-mom` follows the newest of two opposed completed weeks
  immediately. This card waits until two more same-sign weeks complete, then
  trades only the first completed three-week streak.
- `QM5_41068_wti-waccel-mom` and `QM5_41070_wti-wdecel-mom` compare two
  same-sign weekly returns and require a strict magnitude ordering. This card
  requires three same-sign returns, one opposite predecessor, and ignores
  every magnitude.
- `QM5_41069_wti-wpull-trend`, `QM5_41071_wti-wresume-dom`, and
  `QM5_41072_wti-wcounter-dom` require an opposed week inside the newest path
  plus trend or magnitude dominance. This card rejects every path whose
  newest three weekly returns are not strictly same-sign.
- `QM5_41022_wti-wdual-mom` compares disjoint segments inside one completed
  week rather than signs across three complete weeks.
- `QM5_20273_wti-signrun-tr` scores a twelve-month D1 sign path and rebalances
  monthly rather than detecting a fresh exact three-week transition.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI2
  pullback, not symmetric weekly WTI continuation.

Verdict:
`CLEAN_WTI_FRESH_THREE_WEEK_SIGN_STREAK_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: exact D1; magic slot 0; magic `410740000`.
- Decision: first tradable normalized D1 bar of a new Monday-anchored broker
  week, within 180 elapsed raw-session minutes.
- Formation: five consecutive completed broker-week ending closes, with three
  to five completed D1 sessions in each contributing week.
- Signal: the newest three adjacent weekly returns have one strict common
  sign and the preceding weekly return has the strict opposite sign.
- Normal exit: first tick whose broker Monday anchor is later than the open
  position's anchor.
- Expected cadence: approximately 4-10 completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `C0` be the newest completed broker-week ending close and `C4` the oldest:

```text
r0 = ln(C0 / C1)
r1 = ln(C1 / C2)
r2 = ln(C2 / C3)
r3 = ln(C3 / C4)

r0 > 0 and r1 > 0 and r2 > 0 and r3 < 0  => BUY
r0 < 0 and r1 < 0 and r2 < 0 and r3 > 0  => SELL
otherwise                                  => FLAT
```

All values complete before the decision week begins. The current D1 open,
high, low, or close never enters the signal. Exact zero and invalid endpoints
are flat. The strict opposite `r3` prevents rolling re-entry after a fourth
same-sign week.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar under EA 41074 and
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
   the current Monday-anchor attempt before history, signal, spread, quote,
   ATR, sizing, news, or order gates. Never retry that week.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker week.
7. Within the fixed 50-bar buffer, reconstruct exactly five completed weekly
   packages. Require anchors at current minus 7, 14, 21, 28, and 35 calendar
   days, strict reverse-time bar order, three to five bars per week, and
   positive finite ending closes.
8. Select the chronologically last close from each week as `C0..C4`. Compute
   `r0..r3` exactly as above and require every return to be finite.
9. Buy only on strict `r0>0`, `r1>0`, `r2>0`, `r3<0`. Sell only on strict
   `r0<0`, `r1<0`, `r2<0`, `r3>0`. Every zero or other path stays flat.
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

- Exact host, D1, EA 41074, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Uniform label normalization, first-week-bar clock, 180-minute grace,
  consecutive anchors, weekly session counts, endpoint validity, strict sign
  transition, durable attempt, spread, quote, ATR, sizing, and stop geometry
  all fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410740000`.
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
| `strategy_history_bars` | 50 | bounded D1 weekly-endpoint buffer |
| `strategy_required_weeks` | 5 | exact completed weekly packages |
| `strategy_min_week_bars` | 3 | minimum sessions in each completed week |
| `strategy_max_week_bars` | 5 | maximum sessions in each completed week |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return sign continuation and WTI
membership. They do not supply the weekly horizon, three-week streak, or
opposite-sign predecessor gate.

## QM Interpretations

`MOP-WTI-WSTREAK3-MOM-2026_S01` fixes the weekly horizon, five completed week
endpoints, four adjacent returns, strict fresh-streak path, continuous-CFD
Monday anchors and label normalization, entry grace, persistent attempt,
fixed-dollar ATR risk, spread cap, and lifecycle.

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
- Major risks are false streak persistence, weekend gaps, continuous-CFD
  roll/basis, energy-session label ambiguity, financing, spread, density below
  the floor, weekly source translation, and realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than three completed
positions per full post-warm-up year, nonpositive governed economics, wrong or
mixed labels, nonconsecutive Monday anchors, invalid session counts or
endpoints, any entry outside strict `-+++` / `+---`, wrong side, current-week
leakage, late or repeated attempt, rolling fourth-week re-entry, missing hard
stop, wrong next-week close, nondeterminism, or invalid fixed-risk mode.

Changing the WTI carrier, weekly endpoints, streak length, predecessor state,
direction, attempt clock, risk, stop, or lifecycle requires a new identity,
binary, complete stream reconciliation, and portfolio requalification. A
failed result may not be rescued by accepting zero, removing the predecessor,
adding a magnitude threshold, reversing the side, changing the hold, or
adding a calendar, volatility, volume, moving-average, or external filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, week anchors, session counts, weekly endpoints, return signs, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-week and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; five consecutive
weekly packages; chronologically last close selection; three/four/five-session
acceptance and two/six-session rejection; both strict streak directions;
zero-return and every nearby non-streak state; no current-bar leakage;
persistent weekly attempts; fixed-risk frozen-stop sizing; next-week and stale
repair; card lint; strict compile; setfile schema; resolver identity; and
static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-20 | initial WTI fresh three-week sign-streak card | G0 | APPROVED |
| v1-build | 2026-08-20 | deterministic implementation, 11-test reference suite, strict compile/build checks, and static artifact validation | Q01 | PASS |
| v1-q02-capacity | 2026-08-20 | target-only Q02 preflight found one eligible baseline, but the paced CPU ceiling bound before enqueue | Q02 | NOT_ENQUEUED_CPU_CEILING |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-20 | APPROVED | `decisions/2026-08-20_qm5_41074_wti_three_week_sign_streak_momentum_g0.md` |
| Q01 Build Validation | 2026-08-20 | PASS | `D:/QM/reports/framework/21/build_check_20260820_194801.json`; `D:/QM/reports/pipeline/QM5_41074/P1/P1_QM5_41074_result.json` |
| Q02 Baseline Screening | 2026-08-20 | NOT_ENQUEUED_CPU_CEILING | `docs/ops/evidence/2026-08-20_qm5_41074_wti_three_week_streak_q01_q02_cpu_ceiling_stop.md` |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
