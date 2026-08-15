---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MOPEN-MOM-2026_S01
variant_id: MOP-WTI-MOPEN-MOM-2026_S01
source_id: MOP-WTI-MOPEN-MOM-2026
ea_id: QM5_41013
slug: wti-mopen-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41013_wti-mopen-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-15
created_by: Research+Development
last_updated: 2026-08-15
g0_status: APPROVED
g0_decision: decisions/2026-08-15_wti_mopen_momentum_g0.md
source_approval: decisions/2026-08-15_wti_mopen_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_return_sign_continuation_monthly_cadence_and_wti_membership
strategy_mechanic: fixed-sixth-wti-d1-bar-entry-following-prior-month-end-to-fifth-current-month-close-sign-with-next-month-exit
sources:
  - "[[sources/MOP-WTI-MOPEN-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/month-opening-information-segment]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/closed-price-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, month-opening-segment, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410130000
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
pipeline_phase: Q01
q01_status: NOT_STARTED
q02_status: NOT_STARTED
review_focus: "Falsify a fixed-clock WTI month-opening return-sign continuation package. Verify exact first-five segmentation and no late restart entries; Q09 alone may establish realized decorrelation from XAU, SP500, NDX, and XNG."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_first_five_current_month_d1_bars, prior_month_end_anchor, sixth_bar_decision_clock, monthly_attempt_state, no_late_restart_entry, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 peer-reviewed complete-read WTI momentum lineage with disclosed horizon translation; R2 exact first-five endpoints, sixth-bar clock, no-late-entry and lifecycle; R3 native XTI D1; R4 deterministic, no banned signal or trained logic; pre-card dedup CLEAN and nearby families manually separated."
---

# WTI Fixed Month-Opening Segment Momentum

## Hypothesis

The sign of WTI's return during the first five tradable D1 sessions of a
broker month may persist through the remaining sessions because physical-
commodity information and positioning can adjust gradually. The candidate
enters once, at the first tick of the sixth D1 bar, in the direction of the
return from the prior completed month-end close through the fifth current-
month close, then exits at the next broker-month boundary.

This is a falsifiable horizon and calendar translation. The source does not
test this exact five-session formation, fixed entry clock, residual-month
hold, WTI-only CFD, or QM portfolio.

## Source Traceability And Claim Boundary

The sole governed source packet is
`strategy-seeds/sources/MOP-WTI-MOPEN-MOM-2026/source.md`, approved before
extraction in
`decisions/2026-08-15_wti_mopen_momentum_source_approval.md`.

Moskowitz, Ooi, and Pedersen supply the own-return-sign continuation family,
monthly cadence, and WTI membership in their commodity-futures universe. The
paper uses rolled futures excess returns, volatility scaling, broader monthly
formations, and diversified portfolios. It does not establish a WTI-only
five-session result.

The five current-month bars, prior-month anchor, exact broker calendar,
fixed sixth-bar clock, residual-month hold, continuous-CFD carrier, hard stop,
fixed-dollar risk, spread cap, and restart ledger are disclosed QM choices.
No source return, alpha, coefficient, significance, trade density, drawdown,
cost, CFD equivalence, decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker returned `CLEAN` across 4,500 EA-
registry rows and 596 root-card files for the slug, strategy ID, author set,
and complete mechanic. Manual review separates the closest families:

- `QM5_12810_wti-month-orb` constructs a first-five-bar high/low box and waits
  for a later buffered breakout with range, moving-average, and close-location
  gates. This card has no range breakout or signal indicator and decides only
  at the sixth bar from the opening segment's net return sign.
- `QM5_13049_xti-1w-mom-vol` evaluates rolling five-D1 moves, requires a move-
  magnitude threshold and realized-volatility state, and holds five days.
  This card evaluates once per broker month, uses sign only, and holds to the
  next month.
- `QM5_20187_wti-tsmom1m` forms on one complete prior broker month and holds
  the following complete month. This card forms inside the current month and
  holds only the residual segment.
- `QM5_20008_wti-month-ch3` compares a completed monthly close with the prior
  three monthly extrema. This card has no channel or multi-month state.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback across
  commodity carriers. This card is a fixed-clock WTI return-sign continuation
  with no oscillator or cross-carrier allocation.

Verdict:
`CLEAN_WTI_FIXED_MONTH_OPENING_SEGMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Evaluate the entry path only on a new `XTIUSD.DWX` D1 bar.
- Derive the current broker-month key as `yyyymm` from the new bar.
- From a bounded newest-first D1 history scan, count positive, finite completed
  closes whose bar-open year and month match the current key.
- If fewer than five current-month bars completed, wait without consuming the
  month.
- If more than five current-month bars completed and no durable current-month
  attempt exists, persist the month as consumed and remain flat. Never shift
  or make a late entry after terminal restart.
- When exactly five current-month bars completed, persist the month as
  consumed before history validation, return calculation, news, spread, quote,
  sizing, or order gates. Never retry the month.
- Require those bars to be exactly the first five completed D1 bars of the
  current broker month and require the next older completed positive, finite
  D1 close to belong to a different, immediately prior broker month.
- Set `close_fifth` to the newest completed current-month close and
  `close_prior_month_end` to that next older close.
- Compute `formation_return = log(close_fifth / close_prior_month_end)`.
- BUY at market when `formation_return > 0`; SELL at market when
  `formation_return < 0`; stay flat on exact zero or invalid arithmetic.
- Require a valid `ATR(20,D1)` from the prior completed bar and place one
  frozen hard stop at `3.5 * ATR`; use no take-profit.
- Require no owned position, a valid positive quote, and no genuinely positive
  spread wider than 1,500 points. A zero modeled `.DWX` spread is valid.
- Use magic slot 0 only. Signal magnitude never scales risk.

## 5. Exit Rules

- On the first D1 bar whose broker year-month differs from the position's open
  year-month, close the owned package before any entry-only news or spread
  gate. Retry on later ticks until flat.
- Close after thirty-five calendar days as a stale-position guard.
- Close owned exposure that cannot provide a valid position open time.
- The frozen broker hard stop remains active throughout the hold.
- No target, intramonth opposite-signal exit, trailing stop, break-even move,
  partial exit, or discretionary close is authorized.
- Friday close is disabled to preserve the residual-month hold.

## 6. Filters (No-Trade Module)

- Exact host contract: `XTIUSD.DWX`, D1, magic slot 0.
- The strategy-specific history, bar-count, endpoint, price, arithmetic, ATR,
  quote, spread, attempt, and one-position checks fail closed.
- The framework kill switch remains authoritative.
- Both news axes are OFF because the signal uses only native completed prices;
  management and exit remain reachable regardless of entry clearance.
- No external data, futures curve, inventory, volume, open interest, event
  calendar, analyst forecast, file, API, or manual input is used at runtime.

## 7. Trade Management Rules

- One position per magic and at most one consumed attempt per broker month.
- Persist the current-month attempt before every fallible entry condition.
- On restart after the sixth bar, consume the current month flat if no attempt
  record exists; never backfill an entry late.
- A stop-out, rejected order, or framework gate never permits same-month
  re-entry.
- No scale-in, pyramid, grid, martingale, partial close, adaptive parameter,
  PnL-dependent state, or trained output.

## Parameters To Test

| parameter | default | declared range | role |
|---|---:|---|---|
| `strategy_formation_bars` | 5 | [5] | locked first-five current-month formation |
| `strategy_history_bars` | 120 | [120] | bounded D1 endpoint reconstruction |
| `strategy_atr_period` | 20 | [20] | frozen hard-stop estimate |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around month renewal |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

The formation length, endpoints, exact decision clock, sign map, no-late-entry
rule, direction, stop, spread, and month-boundary hold are locked. A later
phase may test only a separately approved, predeclared variant; a failed Q02
baseline may not be rescued by widening this card.

## Author Claims

No verbatim performance claim is imported. The paper is used only for the
own-return-sign continuation family, monthly cadence, and WTI membership. The
five-session month-opening realization is a QM hypothesis whose economics and
density must be measured by the unchanged pipeline.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering estimate, not evidence.
- `expected_dd_pct: 30.0` reflects crude-oil gap and false-continuation risk.
- `expected_trade_frequency`: approximately twelve positions per full year.
- `risk_class: high`.
- `ml_required: false`.

## Risk

Backtests use one fixed budget: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is sized only from the frozen server-side stop.
The absolute formation return never changes lots or the risk budget.

Q02 must retire on zero trades, fewer than five completed packages per full
year, nondeterministic first-five segmentation, late restart entries, risk-
mode mismatch, or nonpositive governed economics. Q09 alone may establish
realized correlation with the certified book.

## Strategy Allowability Check

- [x] R1: one source ID with peer-reviewed JFE lineage, DOI, complete-paper
  review evidence, and durable retrieval hash; translation distance disclosed.
- [x] R2: exact endpoint count, decision clock, sign, attempt, risk, stop,
  spread, and exits are deterministic.
- [x] R3: registered `XTIUSD.DWX` D1 history supplies every runtime input.
- [x] R4: deterministic native arithmetic, one position per magic, and no
  prohibited trained or adaptive logic.
- [x] No signal indicator: entry uses only two completed closes, their exact
  calendar positions, and a logarithmic return sign. ATR is risk plumbing only.
- [x] Exact and fuzzy dedup clean; all nearby WTI families manually separated.

## Framework Alignment

- no_trade: exact WTI/D1/slot, parameter, history, quote, spread, attempt, and
  one-position guards.
- trade_entry: bounded first-five current-month endpoint scan, exact log-return
  sign, fixed sixth-bar clock, frozen ATR stop, and consumed monthly attempt.
- trade_management: close prior-month, stale, or malformed owned exposure
  before entry-only gates and retry until flat.
- trade_close: `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)` plus broker hard
  stop.
- news hook: returns source-only metadata and never suspends management.

## Implementation Notes

- Build only `XTIUSD.DWX` D1, slot 0. This is an explicit single-symbol
  baseline; do not expand the carrier basket.
- Use the framework new-bar gate exactly once in the entry path. Management
  must run on every tick before the news/entry gate.
- A bounded `CopyRates` scan is allowed only behind that new-bar gate for the
  bespoke broker-month endpoint construction. Do not hand-roll a per-EA bar
  timestamp gate.
- Persist the consumed `yyyymm` state with the framework-compatible terminal
  global-variable pattern and corroborate it with entry deal history.
- Create exactly one D1 `backtest` setfile. Do not create demo, shadow, live,
  stress, or optimization setfiles.
- Estimated complexity: medium. Data requirements: standard native D1 history.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-15 | initial fixed month-opening momentum build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-15 | APPROVED | `decisions/2026-08-15_wti_mopen_momentum_g0.md` |
| Q01 Build Validation | TBD | NOT_STARTED | TBD |
| Q02 Baseline Screening | TBD | NOT_STARTED | TBD |

## Safety Boundary

Research/backtest only. This card does not authorize a manual tester, live,
demo, shadow, stress, or optimization setfile; AutoTrading; `T_Live`; a deploy
or T_Live manifest; portfolio admission; a portfolio-gate edit; or a
correlation waiver.
