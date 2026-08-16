---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MENDS-MOM-2026_S01
variant_id: MOP-WTI-MENDS-MOM-2026_S01
source_id: MOP-WTI-MENDS-MOM-2026
ea_id: QM5_41023
slug: wti-mends-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41023_wti-mends-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_wti_month_ends_momentum_g0.md
source_approval: decisions/2026-08-16_wti_month_ends_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_return_sign_continuation_family_and_explicit_wti_membership
strategy_mechanic: first-new-month-wti-entry-only-when-prior-month-first-five-session-and-final-five-session-return-signs-agree-with-sixth-current-month-bar-exit
sources:
  - "[[sources/MOP-WTI-MENDS-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/disjoint-boundary-segment-agreement]]"
  - "[[concepts/month-boundary-information-segment]]"
indicators:
  - "[[indicators/closed-price-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, disjoint-segment-agreement, month-boundary-segment, monthly-entry, five-session-hold, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410230000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-8 completed WTI positions per full post-warm-up year after strict boundary-segment sign agreement; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_HORIZON_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_STARTED
review_focus: "Falsify a direct-WTI month-boundary continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify the two non-overlapping prior-month boundary segments, strict agreement, no late/repeated entry, and exact first-five-session ownership; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [consecutive_prior_month_endpoints, exact_first_five_prior_month_sessions, exact_final_five_prior_month_intervals, non_overlapping_return_intervals, strict_dual_sign_agreement, exact_first_new_month_entry, five_completed_bar_hold, monthly_attempt_state, no_late_restart_entry, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 peer-reviewed complete-read WTI momentum lineage with disclosed boundary-segment translation; R2 exact prior-month opening and closing endpoints, minimum bar count, strict agreement, first-bar clock, no-late-entry, fixed five-bar hold, and lifecycle; R3 native XTI D1; R4 deterministic arithmetic without banned signal or trained logic; canonical dedup found only expected monthly family neighbors and manual review fixed their material boundaries."
---

# WTI Prior-Month Boundary-Segment Momentum

## Hypothesis

WTI continuation across the first sessions of a new broker month may be more
reliable when both the opening and closing five-session segments of the
immediately completed month moved in the same direction. The candidate enters
once at the first executable tick of the next month in that shared direction
and exits after five current-month D1 bars complete.

This is a falsifiable short-horizon and calendar translation. The source does
not test this two-segment agreement state, fixed boundary entry, five-session
hold, WTI-only continuous CFD, or the QM portfolio.

## Source Traceability And Claim Boundary

The sole governed source packet is
`strategy-seeds/sources/MOP-WTI-MENDS-MOM-2026/source.md`, approved before
extraction in
`decisions/2026-08-16_wti_month_ends_momentum_source_approval.md` at commit
`75f0881c0`.

Moskowitz, Ooi, and Pedersen supply the own-return-sign continuation family
and explicit WTI membership in their commodity-futures universe. The paper
uses rolled futures excess returns, volatility scaling, monthly horizons, and
diversified portfolios. It does not establish a WTI-only result for two
within-month boundary segments.

The exact completed-return segments, strict agreement gate, minimum month
length, broker calendar, label normalization, opening grace, five-bar hold,
continuous-CFD carrier, hard stop, fixed-dollar risk, spread cap, and restart
ledger are disclosed QM choices. No source return, alpha, coefficient,
significance, trade density, drawdown, cost, CFD equivalence, decorrelation,
or portfolio result transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,510 EA-registry rows and
606 root cards. It found no exact identity and raised the expected fuzzy
matches `wti-mdual-mom` and `wti-mclose-mom`. Manual review fixes the material
boundaries:

- `QM5_41021_wti-mdual-mom` combines the full completed prior-month return
  with its nested final-five return. This card uses only the first-five and
  final-five segments, which share no return interval, and discards the
  intervening middle path.
- `QM5_41016_wti-mclose-mom` follows the final-five sign alone. This card also
  requires the independent opening segment to agree; disagreement is a load-
  bearing flat state.
- `QM5_41013_wti-mopen-mom` forms from the first five bars of the current
  month, enters on bar six, and holds the residual month. This card forms only
  from the completed prior month, enters at the next boundary, and exits on
  current-month bar six.
- `QM5_20187_wti-tsmom1m` follows a complete prior-month return and owns the
  full next month. This card reads neither the full-month return nor owns a
  full-month package.
- `QM5_13049_xti-1w-mom-vol` is a rolling five-D1 magnitude/volatility rule
  with an any-new-day clock. This card is once per month, sign-only, and has
  no magnitude or volatility filter.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers. This card is fixed-clock WTI continuation without an
  oscillator or cross-carrier allocator.

Verdict:
`CLEAN_WTI_DISJOINT_PRIOR_MONTH_BOUNDARY_SEGMENT_AGREEMENT_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; planned magic `410230000`.
- Decision: first executable tick within 180 minutes of the first D1 bar in a
  new broker month.
- Signal: same strict sign for the prior month's first-five-session and final-
  five-session returns.
- Normal exit: first tick of the sixth D1 bar in the entry broker month.
- Expected cadence: approximately 5-8 completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The rules below are the complete authorized baseline. No magnitude,
volatility-state, weekday, event, curve, volume, oscillator, or external-data
filter is authorized.

## 4. Entry Rules

1. Evaluate the entry path only on a new `XTIUSD.DWX` D1 bar.
2. Require the broker clock and normalized D1 labels to identify the current
   bar as the first D1 bar of a new broker month. Native same-day labels use
   zero offset. If the current energy label is 24-48 hours behind broker time,
   normalize the current and all historical labels by one uniform +1 calendar
   day. Apply no other offset or substitution.
3. Require the first observed tick within 180 minutes of the executable
   session open. Compute elapsed time from broker time and the raw D1 label
   modulo one day so both governed label conventions have the same grace. A
   late attachment consumes the month and remains flat.
4. Persist the exact current broker `yyyymm` attempt before history, signal,
   news, spread, quote, ATR, sizing, or order gates. Never retry the month.
5. Reconstruct all positive, finite completed D1 closes in the immediately
   prior normalized broker month and the immediately preceding broker-month-
   end close. Require consecutive broker months, at least fifteen prior-month
   bars, and identity between the newest prior-month close and the immediately
   preceding completed bar.
6. Let `prior_month_fifth_close` be the fifth chronological close of the prior
   month, `prior_month_sixth_from_end_close` the sixth newest close in that
   month, `prior_month_end` its newest close, and `prior_prior_month_end` the
   final close of the preceding month.
7. Compute
   `opening_return = log(prior_month_fifth_close /
   prior_prior_month_end)` and
   `closing_return = log(prior_month_end /
   prior_month_sixth_from_end_close)`. The intervals share no return and the
   intervening middle path plus current bar enter neither calculation.
8. BUY only when both returns are strictly positive. SELL only when both are
   strictly negative. Exact zero, invalid arithmetic, or sign disagreement
   consumes the month flat.
9. Require a valid `ATR(20,D1)` from completed bars and place one frozen hard
   stop at `3.5 * ATR`. Use no take-profit.
10. Require no owned position, a valid positive quote, and no genuinely
    positive spread wider than 1,500 points. A zero modeled `.DWX` spread is
    valid.
11. Use magic slot 0 only. Signal magnitude never scales risk. No pending
    order, second entry, scale-in, grid, martingale, or pyramid exists.

## 5. Exit Rules

1. On the first D1 bar for which five normalized bars in the position's
   broker entry month have completed, close before any entry-only gate.
   Normally this is the first tick of the sixth D1 bar of that month.
2. Close immediately if the normalized current broker month differs from the
   position's entry month; this is stale repair, not the ordinary exit.
3. Close after twelve elapsed calendar days as a final stale guard.
4. Close owned exposure with invalid open time, volume, price, or direction.
5. The frozen broker hard stop and framework kill switch remain authoritative.
6. No target, opposite-signal exit, trailing stop, break-even move, partial
   exit, or discretionary close is authorized.
7. Friday close is disabled because the fixed five-session hold is load-
   bearing and may span a weekend.

## 6. Filters (No-Trade Module)

- Exact host contract: `XTIUSD.DWX`, D1, EA ID 41023, magic slot 0.
- Exact locked risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The month transition, label normalization, opening grace, consecutive month
  ends, minimum prior-month bar count, endpoint identity, segment separation,
  price, arithmetic, agreement, ATR, quote, spread, attempt, and one-position
  checks fail closed.
- Both news axes are OFF because the signal uses only native completed prices;
  management and exit remain reachable regardless of entry clearance.
- Friday close is OFF to preserve the fixed five-session carrier.
- No external futures, curve, inventory, volume, open interest, event
  calendar, analyst forecast, file, API, or manual input is read at runtime.

## 7. Trade Management Rules

- One position per magic and at most one consumed attempt per broker month.
- Persist the current-month attempt before every fallible entry condition.
- On restart after the first-bar grace, consume the month flat if no attempt
  exists; never backfill a late entry.
- Corroborate the attempt ledger against owned entry-deal history so a stop,
  rejection, restart, or framework gate cannot create same-month re-entry.
- Count completed bars from uniformly normalized broker labels, not elapsed
  wall-clock days.
- Close stale or malformed exposure before news and entry-only gates, retrying
  on later ticks until flat.
- No scale-in, pyramid, grid, martingale, partial close, adaptive parameter,
  PnL-dependent state, or trained output.

## Parameters To Test

| parameter | default | declared range | role |
|---|---:|---|---|
| `strategy_opening_sessions` | 5 | [5] | locked prior-month opening segment |
| `strategy_closing_intervals` | 5 | [5] | locked prior-month closing segment |
| `strategy_min_prior_month_bars` | 15 | [15] | enforces non-overlapping boundary segments |
| `strategy_hold_bars` | 5 | [5] | locked first-five current-month sessions |
| `strategy_entry_grace_minutes` | 180 | [180] | first-bar restart boundary |
| `strategy_history_bars` | 90 | [90] | bounded two-month endpoint reconstruction |
| `strategy_atr_period` | 20 | [20] | frozen hard-stop estimate |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 12 | [12] | stale guard only |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Every value is locked. A failed baseline may not be rescued by removing the
agreement gate, moving an endpoint or clock, reducing the minimum bar count,
adding a magnitude/regime filter, changing direction, widening risk,
extending the hold, or retrying a consumed month.

## Author Claims

The paper is used only for the own-return-sign continuation family and WTI
membership. The two prior-month boundary segments and first-five-session hold
are a QM hypothesis. No verbatim performance claim or paper statistic is
imported.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering estimate, not evidence.
- `expected_dd_pct: 30.0` reflects crude-oil gap and false-continuation risk.
- Expected cadence is approximately 5-8 positions per full year.
- `risk_class: high`.
- `ml_required: false`.

## Risk

Backtests use one fixed budget: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is sized only from the frozen server-side stop.
Neither return magnitude changes lots or the risk budget.

Q02 must retire on zero trades, fewer than five completed positions per full
year, nondeterministic month or segment reconstruction, overlapping return
intervals, current-bar leakage, late/repeated entries, disagreement-side
entry, wrong hold length, risk-mode mismatch, or nonpositive governed
economics. Q09 alone may establish realized correlation with the certified
book.

## Strategy Allowability Check

- [x] R1: one source ID with peer-reviewed JFE lineage, DOI, complete-paper
  review evidence, durable retrieval hash, WTI membership, and disclosed
  translation distance.
- [x] R2: exact endpoints, minimum month length, strict agreement, clock,
  attempt, risk, stop, spread, and exit are deterministic.
- [x] R3: registered `XTIUSD.DWX` D1 history supplies every runtime input.
- [x] R4: deterministic native arithmetic, one position per magic, and no
  prohibited trained or adaptive logic.
- [x] No banned signal indicator: entry uses completed closes, exact calendar
  positions, and logarithmic return signs. ATR is risk plumbing.
- [x] Exact dedup is clean; fuzzy monthly WTI families were manually
  separated by information object and lifecycle.

## Framework Alignment

- no_trade: exact WTI/D1/ID/slot, locked risk/news/Friday inputs, month
  transition, label offset, grace, history, quote, spread, attempt, and one-
  position guards.
- trade_entry: bounded prior-month scan, chronological opening and newest-
  first closing endpoints, non-overlap check, strict sign agreement, frozen
  ATR stop, and consumed monthly attempt.
- trade_management: exact completed-current-month-bar count, month-change,
  stale, malformed, and wrong-direction exits before entry-only gates.
- trade_close: `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)` plus frozen broker
  hard stop and framework kill switch.
- news hook: both axes OFF and never suspends management.

## Implementation Notes

- Build only `XTIUSD.DWX` D1, slot 0. Do not expand the carrier universe.
- Use the framework new-bar gate exactly once in the entry path. Management
  and the sixth-bar close remain reachable on every tick.
- A bounded `CopyRates` scan is allowed only behind that new-bar gate for the
  bespoke two-month endpoint reconstruction.
- Normalize only the known prior-date energy label by one uniform +1 calendar
  day. Broker time remains authoritative for the decision and attempt key.
- Persist the consumed `yyyymm` state with terminal global-variable storage
  and corroborate it with owned entry deal history.
- Create exactly one D1 `backtest` setfile. Do not create demo, shadow, live,
  stress, or optimization setfiles.
- Estimated complexity: medium. Data requirement: standard native D1 history.

## Deterministic Verification Plan

Before Q02 enqueue, a pure reference suite must demonstrate that:

1. the prior-month first-five and final-five endpoints are selected exactly;
2. a short or malformed month, overlapping segments, equality, disagreement,
   and invalid prices remain flat;
3. signal arithmetic excludes the middle path and current-month bar;
4. the persistent attempt prevents same-month retry after downstream failure
   and restart;
5. sizing uses fixed-dollar risk and the frozen completed-bar ATR stop;
6. sixth-bar and stale repair remain reachable independently of entry gates;
7. strict compile, card lint, build checks, setfile schema, magic resolver, and
   static P1 validation pass.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial prior-month boundary-segment WTI extraction | G0 | APPROVED |
| v1-build | 2026-08-16 | deterministic V5 implementation and strict validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED | `decisions/2026-08-16_wti_month_ends_momentum_g0.md` |
| Q01 Build Validation | 2026-08-16 | PASS | `D:/QM/reports/framework/21/build_check_20260816_124841.json` |
| Q02 Baseline Screening | pending | NOT STARTED | enqueue only after strict Q01 PASS |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one D1 backtest setfile,
and one paced Q02 enqueue. It does not authorize a manual backtest, tester
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`, a
deploy or T_Live manifest, portfolio-gate change, portfolio admission, or
correlation waiver.
