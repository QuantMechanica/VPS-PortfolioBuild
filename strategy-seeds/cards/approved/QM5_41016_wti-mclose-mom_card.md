---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MCLOSE-MOM-2026_S01
variant_id: MOP-WTI-MCLOSE-MOM-2026_S01
source_id: MOP-WTI-MCLOSE-MOM-2026
ea_id: QM5_41016
slug: wti-mclose-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41016_wti-mclose-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-15
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-15_wti_mclose_momentum_g0.md
source_approval: decisions/2026-08-15_wti_mclose_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_return_sign_continuation_and_explicit_wti_membership
strategy_mechanic: first-new-month-wti-d1-entry-following-final-five-prior-month-close-to-close-return-sign-with-sixth-current-month-bar-exit
sources:
  - "[[sources/MOP-WTI-MCLOSE-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/month-closing-information-segment]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/closed-price-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, month-boundary-segment, monthly-entry, five-session-hold, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410160000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately twelve completed WTI positions per full post-warm-up year; exact-zero or invalid formation months remain flat, and Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
review_focus: "Falsify whether WTI's final five completed sessions of one broker month continue through the first five sessions of the next. Verify exact endpoints, first-bar attachment, and fifth-bar exit; Q09 alone may establish realized decorrelation from XAU, SP500, NDX, and XNG."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_final_five_prior_month_intervals, exact_first_new_month_entry, five_completed_bar_hold, monthly_attempt_state, no_late_restart_entry, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 peer-reviewed complete-read WTI momentum lineage with disclosed five-session translation; R2 exact six-close endpoints, month membership, first-bar clock, no-late-entry, fixed five-bar hold, and lifecycle; R3 native XTI D1; R4 deterministic arithmetic with no banned signal or trained logic; pre-card exact dedup clean and the one fuzzy month-opening sibling manually separated."
---

# WTI Final-Five To First-Five Month-Boundary Momentum

## Hypothesis

The sign of WTI's return across the final five completed close-to-close
intervals of a broker month may persist through the first five sessions of the
next month because physical-commodity information and positioning can adjust
gradually. The candidate enters once at the first executable tick of the new
month, follows that sign, and exits after five current-month D1 bars complete.

This is a falsifiable horizon and calendar translation. The source does not
test this exact five-session formation, fixed boundary entry, five-session
hold, WTI-only CFD, or QM portfolio.

## Source Traceability And Claim Boundary

The sole governed source packet is
`strategy-seeds/sources/MOP-WTI-MCLOSE-MOM-2026/source.md`, approved before
extraction in
`decisions/2026-08-15_wti_mclose_momentum_source_approval.md`.

Moskowitz, Ooi, and Pedersen supply the own-return-sign continuation family
and explicit WTI membership in their commodity-futures universe. The paper
uses rolled futures excess returns, volatility scaling, broader monthly
formations, and diversified portfolios. It does not establish a WTI-only
five-session result.

The six completed closes, prior-month membership, exact broker calendar,
opening grace, fixed first-bar clock, five-bar hold, continuous-CFD carrier,
hard stop, fixed-dollar risk, spread cap, and restart ledger are disclosed QM
choices. No source return, alpha, coefficient, significance, trade density,
drawdown, cost, CFD equivalence, decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,503 EA-registry rows and
599 root cards. It found no exact identity and one expected fuzzy sibling,
`wti-mopen-mom`. Manual review fixes the material boundaries:

- `QM5_41013_wti-mopen-mom` forms on the first five current-month sessions,
  enters on the sixth, and holds the residual month. This card forms on the
  final five prior-month return intervals, enters on the first current-month
  session, and exits at the sixth; their signal endpoints and owned return
  streams are disjoint.
- `QM5_12983_wti-tom-mom` uses a 63-D1 return magnitude and may enter anywhere
  inside a multi-day turn window, with a target and window exit. This card uses
  only a final-five sign, one exact entry clock, no target, and one exact hold.
- `QM5_13049_xti-1w-mom-vol` evaluates rolling five-D1 moves, requires a
  magnitude threshold and realized-volatility rank, and may decide weekly.
  This card evaluates once per broker month without those gates.
- `QM5_20187_wti-tsmom1m` forms on a complete prior broker month and holds a
  complete next month. This card owns only the first five sessions after a
  non-monthly five-interval formation.
- WTI calendar, breakout, reversal, event, roll, cross-asset, and medium-term
  trend builds do not own this exact segment-to-segment clock.

Verdict:
`CLEAN_WTI_FINAL_FIVE_TO_FIRST_FIVE_SEGMENT_MOMENTUM_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; magic `410160000`.
- Decision: first executable tick within five minutes of the first D1 bar in a
  new broker month.
- Signal: `log(Close[1] / Close[6])`, with all six completed bars in the
  immediately prior broker month.
- Normal exit: first tick of the sixth D1 bar in the entry broker month.
- Expected cadence: approximately twelve completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The rules below are the complete authorized baseline. No magnitude,
volatility, weekday, event, curve, volume, oscillator, or external-data filter
is authorized.

## 4. Entry Rules

1. Evaluate the entry path only on a new `XTIUSD.DWX` D1 bar.
2. Require the current bar to be the first D1 bar whose broker year-month is
   different from the immediately prior completed bar.
3. Require the first observed tick to be within five minutes of the current D1
   bar open. A late attachment consumes the month and remains flat.
4. Persist the current `yyyymm` attempt before history, signal, news, spread,
   quote, sizing, or order gates. Never retry the month.
5. Require six positive, finite immediately preceding completed D1 closes and
   require every corresponding bar-open timestamp to belong to the same,
   immediately prior broker year-month.
6. Require the newest completed bar to be the final D1 bar immediately before
   the current month boundary. Compute
   `formation_return = log(Close[1] / Close[6])`.
7. BUY at market when `formation_return > 0`; SELL at market when it is below
   zero; stay flat on exact zero or invalid arithmetic.
8. Require a valid `ATR(20,D1)` from completed bars and place one frozen hard
   stop at `3.5 * ATR`. Use no take-profit.
9. Require no owned position, a valid positive quote, and no genuinely
   positive spread wider than 1,500 points. A zero modeled `.DWX` spread is
   valid.
10. Use magic slot 0 only. Signal magnitude never scales risk. No pending
    order, second entry, scale-in, grid, martingale, or pyramid exists.

## 5. Exit Rules

1. On the first D1 bar for which five bars in the position's broker entry
   month have completed, close the owned position before any entry-only gate.
   Normally this is the first tick of the sixth D1 bar of that month.
2. Close immediately if the current broker month differs from the position's
   entry month; this is a stale repair, not the normal exit.
3. Close after twelve elapsed calendar days as a final stale guard.
4. Close owned exposure with an invalid open time or unexpected direction.
5. The frozen broker hard stop and framework kill switch remain authoritative.
6. No target, opposite-signal exit, trailing stop, break-even move, partial
   exit, or discretionary close is authorized.
7. Friday close is disabled because the fixed five-session hold is
   load-bearing and may span a weekend.

## 6. Filters (No-Trade Module)

- Exact host contract: `XTIUSD.DWX`, D1, magic slot 0.
- Core parameters are locked to the card values.
- The month transition, opening grace, prior-month membership, six-close
  endpoint, price, arithmetic, ATR, quote, spread, attempt, and one-position
  checks fail closed.
- The framework kill switch remains authoritative.
- Both news axes are OFF because the signal uses only native completed prices;
  management and exit remain reachable regardless of entry clearance.
- No external futures, curve, inventory, volume, open interest, event
  calendar, analyst forecast, file, API, or manual input is read at runtime.

## 7. Trade Management Rules

- One position per magic and at most one consumed attempt per broker month.
- Persist the current-month attempt before every fallible entry condition.
- On restart after the first-bar grace, consume the current month flat if no
  attempt record exists; never backfill a late entry.
- A stop-out, rejected order, or framework gate never permits same-month
  re-entry.
- Count completed bars from broker timestamps, not elapsed wall-clock days.
- Management runs every tick before entry-only news and spread gates.
- No scale-in, pyramid, grid, martingale, partial close, adaptive parameter,
  PnL-dependent state, or trained output.

## Parameters To Test

| parameter | default | declared range | role |
|---|---:|---|---|
| `strategy_formation_intervals` | 5 | [5] | locked final-five prior-month intervals |
| `strategy_hold_bars` | 5 | [5] | locked first-five current-month sessions |
| `strategy_session_offset_min` | 61.6 | [61.6] | XTIUSD.DWX tick-measured maximum |
| `strategy_entry_grace_minutes` | 10 | [10] | tight window around the session-tick anchor |
| `strategy_min_stub_ticks` | 20 | [20] | reject thin weekend/holiday D1 stubs |
| `strategy_min_attach_ticks` | 20 | [20] | minimum ticks within 5 minutes of the qualifying tick |
| `strategy_history_bars` | 40 | [40] | bounded endpoint reconstruction |
| `strategy_atr_period` | 20 | [20] | frozen hard-stop estimate |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 12 | [12] | stale guard only |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Every value is locked. A later phase may test only a separately approved,
predeclared variant; a failed Q02 baseline may not be rescued by widening this
card.

## Author Claims

The paper is used only for the own-return-sign continuation family and WTI
membership. The final-five-to-first-five realization is a QM hypothesis. No
verbatim performance claim or paper statistic is imported.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering estimate, not evidence.
- `expected_dd_pct: 30.0` reflects crude-oil gap and false-continuation risk.
- Expected cadence is approximately twelve positions per full year.
- `risk_class: high`.
- `ml_required: false`.

## Risk

Backtests use one fixed budget: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is sized only from the frozen server-side stop.
The absolute formation return never changes lots or the risk budget.

Q02 must retire on zero trades, fewer than five completed positions per full
year, nondeterministic endpoint or bar-count reconstruction, late/repeated
entries, wrong hold length, risk-mode mismatch, or nonpositive governed
economics. Q09 alone may establish realized correlation with the certified
book.

## Strategy Allowability Check

- [x] R1: one source ID with peer-reviewed JFE lineage, DOI, complete-paper
  review evidence, and durable retrieval hash; translation distance disclosed.
- [x] R2: exact endpoints, month membership, decision clock, direction,
  attempt, risk, stop, spread, and exit are deterministic.
- [x] R3: registered `XTIUSD.DWX` D1 history supplies every runtime input.
- [x] R4: deterministic native arithmetic, one position per magic, and no
  prohibited trained or adaptive logic.
- [x] No signal indicator: entry uses only six completed closes, their exact
  calendar positions, and a logarithmic return sign. ATR is risk plumbing.
- [x] Exact dedup is clean; the single fuzzy sibling is manually separated.

## Framework Alignment

- no_trade: exact WTI/D1/slot, locked parameters, month transition, grace,
  history, quote, spread, attempt, and one-position guards.
- trade_entry: bounded six-close prior-month scan, exact log-return sign,
  fixed first-bar clock, frozen ATR stop, and consumed monthly attempt.
- trade_management: exact completed-current-month-bar count, month-change,
  stale, malformed, and wrong-direction exits before entry-only gates.
- trade_close: `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)` plus broker hard
  stop.
- news hook: returns source-only metadata and never suspends management.

## Implementation Notes

- Build only `XTIUSD.DWX` D1, slot 0.
- Use the framework new-bar gate only in the entry path. Management and the
  sixth-bar close must remain reachable on every tick.
- Persist the consumed `yyyymm` state with terminal global-variable storage
  and corroborate it with entry deal history.
- Create exactly one D1 `backtest` setfile. Do not create demo, shadow, live,
  stress, or optimization setfiles.
- Estimated complexity: medium. Data requirements: native D1 history only.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-15 | initial final-five-to-first-five WTI card | G0 | APPROVED |
| v1-build | 2026-08-15 | deterministic V5 implementation and strict validation | Q01 | PASS |
| v1-queue | 2026-08-15 | first canonical fixed-risk baseline work item | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-15 | APPROVED | `decisions/2026-08-15_wti_mclose_momentum_g0.md` |
| Q01 Build Validation | 2026-08-15 | PASS | `D:/QM/reports/framework/21/build_check_20260815_202228.json` |
| Q02 Baseline Screening | 2026-08-15 | ENQUEUED; pending | `docs/ops/evidence/2026-08-15_qm5_41016_wti_mclose_mom_build_q02_enqueue.md` |

## Safety Boundary

Research/backtest only. This card does not authorize a manual tester, live,
demo, shadow, stress, or optimization setfile; AutoTrading; `T_Live`; a
deploy or T_Live manifest; portfolio admission; a portfolio-gate edit; or a
correlation waiver.

## OWNER-approved session-tick entry-clock amendment (2026-08-16)

This amendment supersedes every earlier raw-D1-label/five-minute entry-clock
description in this card. No formation, signal, direction, exit, sizing,
risk, consumed-attempt, or original advance/never-shift mechanic changes.

- Anchor the qualifying window at
  `D1_bar_open + strategy_session_offset_min`, not the raw D1 label.
- `strategy_session_offset_min = 61.6` minutes: conservative tick-measured maximum for `XTIUSD.DWX`.
- `strategy_entry_grace_minutes = 10`, measured tightly around that anchor.
- `strategy_min_stub_ticks = 20`; a thin weekend/holiday D1 stub consumes
  the card's original attempt/date/window flat.
- `strategy_min_attach_ticks = 20` within five minutes after the qualifying
  tick; failure consumes the original attempt/date/window flat.
- Preserve this card's existing advance-versus-never-shift semantics exactly.
