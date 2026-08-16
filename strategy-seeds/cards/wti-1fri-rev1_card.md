---
card_schema_version: 2
type: strategy
strategy_id: GORSKA-YANG-WTI-1FRI-REV1-2026_S01
variant_id: GORSKA-YANG-WTI-1FRI-REV1-2026_S01
source_id: GORSKA-YANG-WTI-1FRI-REV1-2026
ea_id: QM5_41026
slug: wti-1fri-rev1
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41026_wti-1fri-rev1_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_wti_first_friday_reversal_g0.md
source_approval: decisions/2026-08-16_wti_first_friday_reversal_source_approval.md
source_author: "Anna Gorska; Malgorzata Krawiec; Liu Yang; Bige Kahraman Goncu; Athanasios A. Pantelous"
source_authors: "Anna Gorska; Malgorzata Krawiec; Liu Yang; Bige Kahraman Goncu; Athanasios A. Pantelous"
source_citation: "Gorska and Krawiec (2015), Quantitative Methods in Economics 16(4); Yang, Goncu, and Pantelous, Momentum and Reversal in Commodity Futures, SSRN 3069253."
source_citations:
  - type: academic_wti_calendar_paper
    citation: "Gorska, A. and Krawiec, M. (2015). Calendar Effects in the Market of Crude Oil. Quantitative Methods in Economics 16(4)."
    location: "Governed extraction at strategy-seeds/sources/GORSKA-WTI-CAL-2015/source.md."
    quality_tier: B
    role: positive_wti_friday_calendar_direction
  - type: academic_commodity_reversal_working_paper
    citation: "Yang, L., Goncu, B. K., and Pantelous, A. A. Momentum and Reversal in Commodity Futures. SSRN 3069253."
    location: "Governed extraction at strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md."
    quality_tier: B
    role: completed_month_commodity_loser_reversal_state
strategy_mechanic: first-genuine-friday-month-wti-long-after-negative-prior-complete-calendar-month-return-friday-close
sources:
  - "[[sources/GORSKA-YANG-WTI-1FRI-REV1-2026]]"
concepts:
  - "[[concepts/wti-day-of-week-seasonality]]"
  - "[[concepts/commodity-reversal]]"
  - "[[concepts/calendar-reversal-interaction]]"
indicators:
  - "[[indicators/completed-calendar-month-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, first-friday, calendar-seasonality, prior-month-reversal, long-only, atr-hard-stop, friday-close-flatten, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410260000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 4-8 completed WTI Friday-session positions per full post-warm-up year; Q02 must prove at least three/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: PENDING
q02_status: NOT_ENQUEUED
review_focus: "Falsify a sparse WTI first-Friday reversal interaction outside the certified XAU/SP500/NDX/XNG book. Verify exact monthly Friday identity, consecutive completed-month endpoints, negative-only long direction, restart-safe attempt state, and Friday close; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_first_genuine_friday_no_shift, normalized_energy_label, completed_calendar_month_endpoints, no_current_bar_leakage, negative_only_long_direction, persistent_month_attempt, no_late_restart_entry, friday_close, next_d1_repair, risk_mode_dual, cfd_futures_basis, sparse_density, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy portfolio mission: R1 named academic WTI calendar and commodity-reversal lineages with disclosed working-paper/composite risk; R2 exact normalized first-Friday clock, consecutive completed-month endpoints, negative-only long mapping, persistent attempt, stop, Friday close, and repair; R3 registered native XTIUSD.DWX D1 with measured session offset; R4 deterministic native arithmetic without ML or banned signal logic. Canonical exact/fuzzy dedup and manual family review are CLEAN."
---

# QM5_41026 WTI First-Friday / Prior-Month Reversal

## Hypothesis

WTI's source-documented positive Friday return pattern may be concentrated in
relief bounces after a negative completed calendar month. Buying only on the
first genuine Friday of the next broker month tests that calendar/reversal
interaction while limiting exposure to one Friday session per month.

This is a falsifiable direct-energy sleeve outside the certified
XAU/SP500/NDX/XNG book. It is not a source replication, profitability,
significance, decorrelation, certification, or portfolio-admission claim.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/GORSKA-YANG-WTI-1FRI-REV1-2026/source.md`, approved
before extraction in
`decisions/2026-08-16_wti_first_friday_reversal_source_approval.md` at commit
`5b0bd7603`.

Gorska and Krawiec supply the positive WTI Friday calendar direction. Yang,
Goncu, and Pantelous supply the fixed-horizon commodity-reversal lineage.
Neither source tests this conjunction, the first-Friday selector, exact
Darwinex broker months, a Friday-session hold, continuous CFD construction,
label normalization, fixed cash risk, or an ATR stop. Those are disclosed QM
choices. No source return, coefficient, trade count, cost, drawdown, CFD
equivalence, correlation, or portfolio statistic transfers.

## Source-Defined Rules

- Gorska and Krawiec report Friday as the strongest positive average WTI
  weekday in their source sample.
- Yang, Goncu, and Pantelous supply academic commodity-reversal lineage at
  fixed return horizons.
- Neither source defines the exact interaction or execution and risk controls
  below.

## QM Interpretations

The first-Friday-only selector, exact completed broker-calendar-month
endpoints, negative-only long mapping, governed zero-or-`+1`-day energy-label
normalization, 180-minute attachment grace, no-shift/no-retry contract,
Friday-close lifecycle, continuous-CFD carrier, fixed risk, ATR stop, and
spread cap are frozen QM falsification choices rather than author claims.

## Non-Duplicate Decision

The canonical checker scanned 4,513 registry rows and 609 root cards and
returned `CLEAN` without an exact or fuzzy match. Manual review returned
`CLEAN_WTI_FIRST_FRIDAY_PRIOR_MONTH_REVERSAL_AFTER_FAMILY_REVIEW`:

- `QM5_20172_wti-fri-bear` buys every genuine Friday in a negative completed
  252-D1 state. This card admits only one Friday per month and reads the exact
  immediately completed calendar-month return.
- `QM5_12597_wti-fri-prem` buys every eligible Friday unconditionally.
- `QM5_12709_commodity-reversal-1m` ranks four commodities and holds a
  two-leg package for a month; this card is a direct one-session WTI trade.
- `QM5_12621_comm-reversal-4wk-xtiusd` reads a rolling 20-D1 overreaction
  threshold rather than consecutive completed calendar-month endpoints.
- `QM5_41024_wti-1wed-mom1` follows either prior-month sign on first
  Wednesday. This card fades only the negative state on first Friday and
  delegates the ordinary exit to Friday close.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers, not fixed-clock direct-WTI calendar/reversal logic.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1; EA `QM5_41026`; magic slot 0; magic `410260000`.
- Decision: first genuine normalized broker Friday of each month.
- Direction: BUY only after a strictly negative immediately completed
  broker-calendar-month WTI return.
- Normal exit: V5 Friday close at broker hour 21.
- Expected cadence: approximately 4-8 completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. No neighboring-day
substitution, horizon/day/direction sweep, unconditional fallback, momentum
flip, event filter, curve input, oscillator, or post-result rescue is
authorized.

## 4. Entry Rules

1. Evaluate only on a new exact `XTIUSD.DWX` D1 bar with EA ID 41026 and
   magic slot 0.
2. Derive the governed energy label offset. Accept only a native same-day
   label or one uniform `+86400`-second normalization when the raw current D1
   label is 24-48 hours behind broker time. Apply the same offset to current
   and historical labels; all other states fail closed.
3. Require the normalized current label's date to equal the broker date, its
   weekday to be Friday, and its day of month to be in `[1,7]`. Require the
   immediately preceding normalized D1 label to be Thursday. Never shift an
   absent or holiday Friday.
4. Require the first observed tick within 180 minutes of executable D1 open.
   Persist the broker-month attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry or backfill the month.
5. Reject owned exposure or an owned entry deal already present for that
   broker month.
6. From completed D1 bars only, identify the newest positive finite close in
   the immediately prior normalized broker month and the newest close in the
   month before it. Require exact consecutive month keys and strict timestamp
   order. Current-month bars and the live bar enter neither endpoint.
7. Compute `prior_month_return = log(PriorMonthEnd /
   PriorPriorMonthEnd)`. Submit one BUY only when it is strictly negative.
   Exact zero, invalid endpoints, or a nonnegative state consumes the month
   flat. Signal magnitude never scales risk.
8. Require a non-negative spread no greater than 1,500 points, a positive
   finite executable quote, and completed `ATR(20,D1)`.
9. Attach one frozen broker hard stop `3.0 * ATR(20,D1)` from entry,
   normalized by V5 stop rules. There is no take-profit.
10. Open at most one position for magic `410260000`; no pending order,
    duplicate entry, scale-in, grid, martingale, or pyramid is authorized.

## 5. Exit Rules

1. The framework Friday-close guard closes the position at broker hour 21.
2. If Friday close cannot complete, close on the first normalized D1 bar
   whose date differs from the normalized entry date.
3. Close after four elapsed calendar days as a stale-position guard.
4. Close malformed, duplicated, wrong-side, or invalid owned exposure before
   evaluating a new entry.
5. Broker hard stops and the framework kill switch remain authoritative.
6. No target, opposite-signal exit, trailing stop, break-even move, partial
   close, scale-in, grid, martingale, or discretionary close is authorized.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol, timeframe, EA ID, slot, seed, risk contract,
  news contract, Friday-close contract, or unlocked strategy input.
- Fail closed for invalid label normalization, broker-date mismatch, a date
  outside first genuine Friday, late attachment, consumed month, owned
  exposure/deal, invalid or non-consecutive month endpoints, zero/nonnegative
  return, invalid ATR, quote, stop, or spread.
- Lock news temporal OFF, compliance NONE, and legacy news mode OFF for Q02.
- Runtime may not read futures curves, contracts, inventory, volume, open
  interest, COT, event feeds, CSV, API, forecasts, external calendars, or
  trained output.

## 7. Trade Management Rules

- Lifecycle repair executes before all entry-only gates on every tick.
- One BUY position maximum for magic `410260000` and one consumed attempt per
  broker month.
- Terminal-persistent attempt state plus owned deal history prevents restart
  re-entry; future-dated tester state is cleared on initialization.
- The original server-side hard stop is never moved.
- No hedge, averaging, scale-in, pyramid, grid, martingale, random path,
  adaptive fit, PnL-dependent state, or discretionary override exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_entry_dow` | 5 | [5] | exact Friday label |
| `strategy_first_week_last_dom` | 7 | [7] | first-Friday month boundary |
| `strategy_return_months` | 1 | [1] | consecutive completed calendar-month formation |
| `strategy_entry_grace_minutes` | 180 | [180] | measured WTI executable-session attachment |
| `strategy_history_bars` | 100 | [100] | bounded endpoint scan |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 4 | [4] | weekend-safe repair guard |
| `strategy_max_spread_points` | 1500 | [1500] | entry spread ceiling |

Every value is locked. A failed baseline may not be rescued by changing the
weekday, month selector, return horizon, sign, direction, entry grace, stop,
hold, or spread ceiling.

## Author Claims

Gorska and Krawiec document a positive Friday WTI cell in their historical
sample. Yang, Goncu, and Pantelous provide commodity-reversal lineage. The
exact first-Friday/prior-month interaction is a QM falsification hypothesis.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 25.0` reflects WTI gap, roll, sparse-sample, and
  interaction risk.
- Expected cadence is approximately 4-8 positions per full year.
- `risk_class: high`.
- `ml_required: false`.

## Risk

Backtests use one stop-normalized fixed budget: `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Signal magnitude never changes
lots or risk.

Q02 must retire on zero trades, fewer than three completed positions per full
year, wrong or shifted Fridays, invalid/non-consecutive month endpoints,
current-bar leakage, nonnegative-state trades, late/repeated entries, missing
stops, wrong exit timing, risk-mode mismatch, nondeterminism, or nonpositive
governed economics. Working-paper risk, multiple testing, post-sample decay,
the untested interaction, futures/CFD basis, broker-label mapping, spread,
gaps, financing, roll construction, and later book correlation are first-
order risks. No parameter rescue or correlation waiver is authorized.

## Strategy Allowability Check

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: named academic WTI
  calendar and commodity-reversal lineages with complete governed packets and
  disclosed translation/source risks.
- R2 `PASS`: first-Friday identity, normalized labels, endpoints, sign map,
  direction, attempt state, entry clock, risk, stop, spread, Friday close, and
  repair are fixed.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history with directly measured
  session offset supplies every runtime input.
- R4 `PASS`: deterministic calendar/OHLC/logarithm/ATR only; no trained or
  banned signal logic, external runtime feed, grid, martingale, scale-in, or
  pyramid.
- Dedup `PASS`: canonical exact/fuzzy check and manual family review are
  clean.

## Framework Alignment

- no_trade: exact host/D1/ID/slot/seed, locked fixed-risk/news/Friday/input
  contract, and cheap identity guards.
- trade_entry: normalized first-genuine-Friday clock, persistent monthly
  attempt, consecutive completed-month endpoint scan, negative-only long
  direction, spread/quote/ATR validation, and frozen hard stop.
- trade_management: wrong-side, malformed, first-later-D1, and stale repair
  before entry-only gates.
- trade_close: V5 Friday-close and position-close paths, server hard stop, and
  framework kill switch.

## Framework Execution Overrides

News temporal mode OFF, compliance NONE, and legacy news mode OFF. Friday
close is enabled at broker hour 21. Framework risk sizing, server-side hard
stop, and kill switch remain authoritative.

## Exit Precedence

1. Framework kill switch and server-side hard stop.
2. Framework Friday close at broker hour 21.
3. First later normalized D1 boundary or malformed/wrong-side exposure repair.
4. Four-calendar-day stale close.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` D1 OHLC, broker time/calendar, measured session-offset
contract, completed ATR, quotes, spread, symbol metadata, positions, deals,
and terminal global state only. No external runtime source is authorized.

## Falsification And Requalification

Any change to label normalization, first-Friday identity, completed-month
endpoints, return sign/direction, entry grace, stop, hold, spread, retry state,
symbol, timeframe, news/Friday contract, or risk mode requires a new binary
and full pipeline requalification.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial first-Friday/prior-month WTI reversal extraction | G0 | APPROVED |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED | `decisions/2026-08-16_wti_first_friday_reversal_g0.md` |
| Q01 Build Validation | - | PENDING | - |
| Q02 Baseline Screening | - | NOT ENQUEUED | - |

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does not authorize
a manual tester launch, live/demo/shadow/stress execution, AutoTrading,
`T_Live`, a deploy or T_Live manifest, portfolio admission, portfolio-gate
change, or a correlation waiver.
