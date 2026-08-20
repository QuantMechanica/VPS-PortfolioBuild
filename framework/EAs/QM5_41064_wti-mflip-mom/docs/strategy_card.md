---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MFLIP-MOM-2026_S01
variant_id: MOP-WTI-MFLIP-MOM-2026_S01
source_id: MOP-WTI-MFLIP-MOM-2026
ea_id: QM5_41064
slug: wti-mflip-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41064_wti-mflip-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-20
created_by: Research+Development
last_updated: 2026-08-20
g0_status: APPROVED
g0_decision: decisions/2026-08-20_qm5_41064_wti_month_flip_momentum_g0.md
source_approval: decisions/2026-08-20_wti_month_flip_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; Sections 3.1-3.2; Table 2 Panel B; Appendix A; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-MFLIP-MOM-2026/source.md"
    quality_tier: A
    role: one_month_own_return_continuation_lineage
strategy_mechanic: normalized-month-boundary-wti-two-adjacent-nonoverlapping-month-return-sign-change-newest-sign-continuation-one-month-hold
sources:
  - "[[sources/MOP-WTI-MFLIP-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/monthly-trend-transition]]"
  - "[[concepts/wti-structural-trend]]"
indicators:
  - "[[indicators/adjacent-completed-month-log-returns]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, time-series-momentum, monthly-sign-transition, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410640000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately five to eight completed WTI positions per full post-warm-up year after the strict adjacent-month return-sign-change gate; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CONDITIONAL_STATE_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED_PENDING_CPU_CEILING
q01_build_report: D:/QM/reports/framework/21/build_check_20260820_084922.json
q01_p1_evidence: D:/QM/reports/pipeline/QM5_41064/P1/P1_QM5_41064_result.json
review_focus: "Falsify a low-frequency WTI trend-transition stream for the index/metal/XNG book. Verify uniform energy-label normalization, three consecutive completed month ends, two non-overlapping returns, strict sign transition, newest-sign direction, durable monthly attempt, fixed-risk hard stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, uniform_energy_label_normalization, completed_month_endpoints, nonoverlapping_month_returns, strict_sign_change, newest_sign_direction, monthly_attempt_state, entry_grace, risk_mode_dual, hard_stop_present, full_month_hold, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses a named-author peer-reviewed JFE paper with DOI, complete-paper evidence, durable retrieval identity, explicit WTI membership, and disclosure that the adjacent-month sign-change gate is an untested QM condition; R2 locks normalization, three endpoints, two non-overlapping returns, strict transition, newest-sign side, durable attempt, fixed risk, hard stop, spread, and lifecycle; R3 uses registered native XTI D1 with energy-label and CFD-basis risks explicit; R4 is deterministic timestamp, completed-price, logarithm, ATR, quote, position, deal, and terminal-state arithmetic without a banned signal, trained output, external feed, grid, or martingale; canonical dedup found no exact/fuzzy identity and manual family review separated unconditional monthly trend, older-trend pullback, nested-horizon agreement, current-month reversal, and cumulative-RSI2 systems."
---

# QM5_41064 WTI Fresh Monthly Return-Sign Handoff Momentum

## Hypothesis

A change in sign between two adjacent completed WTI monthly returns can mark a
fresh directional handoff. Following the newest completed-month sign for the
next broker month may isolate the early part of a new crude-oil trend while
remaining flat during persistent same-sign states.

This is a structural WTI return stream for a certified book currently driven
by index, metal, and natural-gas sleeves. Different physical exposure does not
prove diversification. Q02 must establish density and economics, and unchanged
Q09 alone may establish realized book correlation.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/MOP-WTI-MFLIP-MOM-2026/source.md`, authorized before
card extraction at
`decisions/2026-08-20_wti_month_flip_momentum_source_approval.md` and durably
committed as `3eb52da3e`.

Moskowitz, Ooi, and Pedersen (2012) supply peer-reviewed own-return
continuation lineage, the sign-to-direction mapping, an explicit commodity
portfolio at `k=1`, `h=1`, and NYMEX WTI membership. They do not test a
WTI-only adjacent-month sign transition, Darwinex continuous CFD, fixed-dollar
ATR risk, or this restart-safe lifecycle. The strict old-to-new sign-change
gate is a predeclared QM timing hypothesis.

No source or sibling return, profit factor, Sharpe ratio, drawdown, trade
count, transaction cost, CFD equivalence, threshold, stop, or portfolio-
correlation statistic transfers. Every implementation choice below is a
pre-result falsification choice.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,551 registry rows and 625 root
cards and returned no exact or fuzzy match. Manual review fixes these
boundaries:

- `QM5_20187_wti-tsmom1m` follows every nonzero completed monthly WTI return;
  this card enters only after a strict sign change versus a separate preceding
  full month and is flat during same-sign persistence.
- `QM5_20239_wti-pulltrend` follows an older twelve-month trend when the newest
  month opposes it, deliberately trading opposite the newest monthly return;
  this card has no twelve-month state and follows the newest return.
- `QM5_41021_wti-mdual-mom` requires agreement between a full completed month
  and its nested final five sessions, then holds five sessions; this card
  requires disagreement between two full non-overlapping months and owns the
  next full month.
- `QM5_41027_wti-mopen-rev1` observes and fades current-month opening sessions;
  this card decides before any current-month close and uses continuation.
- `QM5_12567_cum-rsi2-commodity` is a two-day cumulative-RSI2 pullback across
  commodity carriers, not monthly WTI return-sign continuation.

The exact WTI carrier, uniform session-label convention, three consecutive
month-end closes, two adjacent non-overlapping returns, strict old-to-new sign
transition, newest-sign direction, one monthly attempt, and next-month
lifecycle are jointly load-bearing. Verdict:
`CLEAN_WTI_ADJACENT_MONTH_SIGN_HANDOFF_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Exact period: D1; EA `41064`; slot `0`; magic `410640000`.
- Formation: three consecutive completed normalized broker-month-end closes.
- Decision: first executable D1 tick of the next broker month, within five
  minutes of the raw session open.
- Signal: strict sign change between the two adjacent completed-month returns.
- Ordinary exit: first tick of the following broker month.
- Expected cadence: five to eight completed positions/year; retire below five.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `C1` be the newest completed broker-month-end close, `C2` the immediately
preceding month-end close, and `C3` the next older consecutive month-end close:

```text
r_new = ln(C1 / C2)
r_old = ln(C2 / C3)

r_old < 0 and r_new > 0 => BUY
r_old > 0 and r_new < 0 => SELL
otherwise                => FLAT
```

All three endpoints are completed before the decision month begins. The
current D1 open, high, low, or close never enters either return.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar under EA 41064 and
   magic slot zero.
2. Repair malformed, later-month, or stale owned exposure before entry-only
   gates.
3. Select offset zero when the raw current D1 date equals the broker date or
   `+1` calendar day only when it is exactly one day behind. Apply that one
   convention to every endpoint and reject every other or mixed convention.
4. Require the normalized current date to equal the broker date, the current
   D1 bar to be the first completed-label member of the broker month, and
   attachment within five elapsed session minutes of raw bar open.
5. Persist the normalized current `yyyymm` before endpoint validation, signal,
   spread, quote, ATR, sizing, news, or order gates. Never retry that month.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker month.
7. Within the fixed 90-bar buffer, select exactly the latest close in each of
   the three most-recent completed broker months. Require consecutive month
   keys, strict reverse-time bar order, and positive finite closes.
8. Compute the two log returns. BUY only on negative-to-positive and SELL only
   on positive-to-negative. Same-sign, zero, or invalid values stay flat.
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
3. Close on the first tick whose normalized current D1 label belongs to a
   broker month later than the position-open month.
4. Close after forty elapsed calendar days as a stale safety repair.
5. No Friday close, target, reversal exit, trail, break-even move, partial
   exit, discretionary close, or intentional hold beyond the next month.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41064, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Uniform label normalization, first-month-bar clock, five-minute grace,
  endpoint chronology, strict sign transition, durable attempt, spread, quote,
  ATR, sizing, and stop geometry all fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410640000`.
- Persist the last attempted broker-month key across restart.
- Manage malformed, later-month, stale, and kill-switch exits before entry.
- Freeze the original hard stop; never widen, trail, or remove it.
- Do not retry, add, pyramid, grid, martingale, partially close, hedge, or
  reverse inside the month.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_entry_grace_minutes` | 5 | exact new-month execution window |
| `strategy_history_bars` | 90 | bounded D1 endpoint buffer |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | full-month identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return sign continuation, monthly
formation/hold lineage, commodity evidence, and WTI membership. They do not
supply the adjacent-month sign-change condition or CFD execution choices.

## QM Interpretations

`MOP-WTI-MFLIP-MOM-2026_S01` fixes the strict fresh sign-transition gate,
continuous-CFD month endpoints, label normalization, entry grace, persistent
attempt, fixed-dollar ATR risk, spread cap, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later normalized broker-month closure.
4. Forty-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 closes, broker time, symbol metadata, quotes,
completed-bar ATR, framework position/deal state, and persistent terminal
global-variable attempt state. No finite external dataset or calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are WTI reversal after a sign handoff, monthly gaps, continuous-
  CFD roll/basis, energy-session label ambiguity, financing, spread, density
  below the floor, source translation, and realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, wrong or
mixed labels, nonconsecutive month ends, overlapping return intervals,
same-sign entry, wrong side, current-month leakage, late or repeated attempt,
missing hard stop, wrong next-month close, nondeterminism, or invalid fixed-
risk mode.

Changing the WTI carrier, endpoint count, sign condition, direction, attempt
clock, risk, stop, or lifecycle requires a new identity, binary, complete
stream reconciliation, and portfolio requalification. A failed result may not
be rescued by accepting same-sign months, reversing the side, adding a return
threshold, changing the hold, or adding a calendar or volatility filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, month ends, returns, sign transition, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-month and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-month-bar
and five-minute clock; three consecutive completed month ends; adjacent non-
overlapping returns; both strict transition directions; same-sign and zero
flat states; no current-bar leakage; persistent monthly attempts; fixed-risk
frozen-stop sizing; next-month and stale repair; card lint; strict compile;
setfile schema; resolver identity; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-20 | initial WTI adjacent-month sign-handoff card | G0 | APPROVED |
| v1-build | 2026-08-20 | deterministic WTI implementation, reference suite, strict compile/build checks, and static artifact validation | Q01 | PASS |
| v1-q02-capacity | 2026-08-20 | target-only dry run selected one row; this lane withheld apply above terminal and host-CPU ceilings; concurrent fleet state subsequently showed one pending Q02 row | Q02 | ENQUEUED_PENDING_CPU_CEILING |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-20 | APPROVED | `decisions/2026-08-20_qm5_41064_wti_month_flip_momentum_g0.md` |
| Q01 Build Validation | 2026-08-20 | PASS | `D:/QM/reports/framework/21/build_check_20260820_084922.json`; `D:/QM/reports/pipeline/QM5_41064/P1/P1_QM5_41064_result.json` |
| Q02 Baseline Screening | 2026-08-20 | ENQUEUED_PENDING_CPU_CEILING | pending work item `e5d1dfa2-a198-4769-9a41-f9c99e7d191a`; `docs/ops/evidence/2026-08-20_qm5_41064_wti_month_sign_handoff_q01_q02_cpu_ceiling_stop.md` |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
