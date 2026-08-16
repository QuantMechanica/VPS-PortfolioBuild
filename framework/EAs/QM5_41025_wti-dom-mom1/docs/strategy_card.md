---
card_schema_version: 2
type: strategy
strategy_id: BOROWSKI-MOP-WTI-DOMMOM1-2026_S01
variant_id: BOROWSKI-MOP-WTI-DOMMOM1-2026_S01
source_id: BOROWSKI-MOP-WTI-DOMMOM1-2026
ea_id: QM5_41025
slug: wti-dom-mom1
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41025_wti-dom-mom1_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_wti_dom_month_momentum_g0.md
source_approval: decisions/2026-08-16_wti_dom_month_momentum_source_approval.md
source_author: "Krzysztof Borowski; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Krzysztof Borowski; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Borowski (2016), Journal of Management and Financial Sciences 26, 27-44; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_commodity_seasonality_paper
    citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber. Journal of Management and Financial Sciences 26, 27-44."
    location: "Section 4.3 WTI numbered-day table and conclusion; complete governed review in strategy-seeds/sources/BOROWSKI-WTI-DOM26-2016/source.md."
    quality_tier: B
    role: exact_day_8_long_and_day_26_short_directions
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper review and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md."
    quality_tier: A
    role: immediately_completed_instrument_own_month_return_sign
strategy_mechanic: exact-broker-day-8-wti-long-only-after-positive-prior-calendar-month-or-day-26-short-only-after-negative-prior-calendar-month-next-d1-exit
sources:
  - "[[sources/BOROWSKI-MOP-WTI-DOMMOM1-2026]]"
concepts:
  - "[[concepts/wti-day-of-month-seasonality]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/calendar-trend-agreement]]"
indicators:
  - "[[indicators/completed-calendar-month-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, intraday-day-of-month, calendar-seasonality, one-month-momentum-gate, exact-date-entry, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410250000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 8-10 completed WTI positions per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 9
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_AND_MULTIPLE_TESTING_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify a sparse physical-crude calendar/month interaction outside the certified XAU/SP500/NDX/XNG book. Verify normalized exact dates, consecutive completed-month endpoints, agreement direction, no late/repeated entry, and next-D1 exit; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_day_8_day_26_no_shift, normalized_energy_label, completed_calendar_month_endpoints, no_current_bar_leakage, agreement_sign_direction, persistent_exact_date_attempt, no_late_restart_entry, next_d1_exit, risk_mode_dual, friday_close, cfd_futures_basis, multiple_testing, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy portfolio mission: R1 two peer-reviewed complete-read lineages with exact WTI calendar cells, complete MOP paper evidence, and disclosed multiple-testing/composite risk; R2 exact normalized dates, consecutive completed-month endpoints, agreement sign map, attempt state, stop, and next-D1 exit; R3 registered native XTIUSD.DWX D1 with measured session offset; R4 deterministic native arithmetic without ML or banned signal logic. Canonical dedup found no exact match; sole fuzzy family hit was manually resolved."
---

# WTI Exact-Day / Prior-Month Momentum Agreement

## Hypothesis

WTI's source-documented positive day-8 and negative day-26 return patterns may
be strongest when the immediately completed calendar month's own-price
direction agrees with the recurring physical-market calendar flow. The
strategy buys only on exact day 8 after a positive completed month and shorts
only on exact day 26 after a negative completed month, then owns one D1
interval.

This is a falsifiable direct-energy interaction outside the certified
XAU/SP500/NDX/XNG book. It is not a source replication, profitability,
significance, decorrelation, certification, or portfolio-admission claim.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/BOROWSKI-MOP-WTI-DOMMOM1-2026/source.md`, approved
before extraction in
`decisions/2026-08-16_wti_dom_month_momentum_source_approval.md` at commit
`600106d4e`.

Borowski supplies the positive WTI day-8 and negative day-26 calendar cells.
Moskowitz, Ooi, and Pedersen supply direction from an instrument's own
completed return sign, the `k=1`, `h=1` commodity family, and explicit WTI
membership.

Neither source tests the conjunction, exact Darwinex broker dates, a one-D1
hold, continuous CFD construction, label normalization, fixed cash risk, or
an ATR stop. Borowski searches many calendar cells without a reported
family-wise correction and its sample ends in 2016. The conjunction,
normalized date mapping, 180-minute entry boundary, endpoint implementation,
stop, spread cap, and persistent attempt ledger are disclosed QM choices. No
source return, coefficient, trade count, cost, drawdown, CFD equivalence,
correlation, or portfolio statistic transfers.

## Source-Defined Rules

- Borowski supplies a positive WTI day-8 direction and negative WTI day-26
  direction from the numbered-day table.
- Moskowitz, Ooi, and Pedersen supply the use of an instrument's completed
  own-return sign and explicitly include WTI in the commodity universe.
- Neither source defines the interaction or the execution and risk controls
  below.

## QM Interpretations

The exact Darwinex date mapping, governed zero-or-`+1`-day energy-label
normalization, completed calendar-month endpoint scan, strict agreement rule,
180-minute attachment grace, no-shift/no-retry contract, one-D1 lifecycle,
continuous-CFD carrier, fixed risk, ATR stop, and spread cap are frozen QM
falsification choices rather than author claims.

## Non-Duplicate Decision

The canonical checker scanned 4,512 registry rows and 608 root cards. It found
no exact match and raised only `wti-dom-ctrreg` for manual review. The review
returned
`CLEAN_WTI_DAY8_DAY26_PRIOR_MONTH_AGREEMENT_AFTER_FAMILY_REVIEW`:

- `QM5_41017_wti-dom-ctrreg` uses day 8/day 26 in the opposing completed
  252-D1 state. This card requires agreement with the immediately completed
  calendar month. The same-date triggers are mutually exclusive whenever the
  one-month and 252-D1 signs agree.
- `QM5_20215_wti-dom-trend` uses day 1/day 26 and a completed 252-D1 state.
  This card uses source-significant day 8/day 26 and consecutive completed
  calendar-month endpoints.
- `QM5_20036_wti-dom8-long` and `QM5_20027_wti-dom26-short` are unconditional
  source parents; the completed-month gate is load-bearing here.
- `QM5_20187_wti-tsmom1m` enters at the month boundary and holds through a
  month. This card samples the return state at two sparse exact dates and owns
  only the next D1 interval.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback across
  commodity carriers, not fixed-clock direct-WTI calendar/month logic.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1; EA `QM5_41025`; magic slot 0; magic `410250000`.
- Long decision: exact normalized broker-calendar day 8 after a strictly
  positive immediately completed calendar-month return.
- Short decision: exact normalized broker-calendar day 26 after a strictly
  negative immediately completed calendar-month return.
- Normal exit: first following normalized D1 boundary.
- Expected cadence: approximately 8-10 completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. No neighboring-date
substitution, horizon/date/direction sweep, unconditional fallback, trend
reversal, event filter, curve input, oscillator, or post-result rescue is
authorized.

## 4. Entry Rules

1. Evaluate only on a new exact `XTIUSD.DWX` D1 bar with EA ID 41025 and
   magic slot 0.
2. Derive the governed energy label offset. Accept only a native same-day
   label or one uniform `+86400`-second normalization when the raw current D1
   label is 24-48 hours behind broker time. Apply the same offset to current
   and historical labels; all other states fail closed.
3. Require the normalized current label's date to equal the broker date and
   its day of month to be exactly 8 or 26. Never shift an absent weekend or
   holiday date.
4. Require the first observed tick within 180 minutes of the executable D1
   session open. Persist the exact normalized `yyyymmdd` attempt before
   history, signal, news, spread, quote, ATR, sizing, or order gates. Never
   retry or backfill the date.
5. Reject an owned position or owned entry deal already present for that
   exact normalized date.
6. From completed D1 bars only, identify the newest positive finite close in
   the immediately prior normalized broker month and the newest close in the
   month before it. Require exact consecutive month keys and strict timestamp
   order. Current-month bars and the live bar enter neither endpoint.
7. Compute `prior_month_return = log(PriorMonthEnd /
   PriorPriorMonthEnd)`. On exact day 8, submit one BUY only when it is
   strictly positive. On exact day 26, submit one SELL only when it is
   strictly negative. Exact zero, invalid endpoints, or a disagreeing sign
   consumes the date flat. Signal magnitude never scales risk.
8. Require a non-negative spread no greater than 2,500 points, a positive
   finite executable quote, and completed `ATR(20,D1)`.
9. Attach one frozen hard stop `2.75 * ATR(20,D1)` from entry, normalized by
   V5 stop rules. There is no take-profit.
10. Open at most one position for magic `410250000`; no pending order,
    duplicate entry, scale-in, grid, martingale, or pyramid is authorized.

## 5. Exit Rules

1. Close on the first normalized D1 bar whose date differs from the
   position's normalized opening date, before evaluating a new entry.
2. Close after five elapsed calendar days as a stale-position guard.
3. Close malformed or duplicated owned exposure and exposure with invalid
   open time, volume, price, or direction.
4. Framework Friday close remains enabled at broker hour 21 as a fail-safe.
5. Broker hard stops and the framework kill switch remain authoritative.
6. No target, opposite-signal exit, trailing stop, break-even move, partial
   close, scale-in, grid, martingale, or discretionary close is authorized.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol, timeframe, EA ID, slot, seed, risk contract,
  news contract, Friday-close contract, or unlocked strategy input.
- Fail closed for invalid label normalization, broker-date mismatch, date
  outside 8/26, late attachment, consumed date, owned exposure/deal, invalid
  or non-consecutive month endpoints, zero/disagreeing return, invalid ATR,
  quote, stop, or spread.
- Lock news temporal OFF, compliance NONE, and legacy news mode OFF for Q02.
- Runtime may not read futures curves, contracts, inventory, volume, open
  interest, COT, event feeds, CSV, API, forecasts, external calendars, or
  trained output.

## 7. Trade Management Rules

- Lifecycle repair and exit execute before all entry-only gates on each new
  D1 bar.
- One position maximum for magic `410250000` and one consumed attempt per
  normalized exact date.
- Terminal-persistent attempt state plus owned deal history prevents restart
  re-entry; future-dated tester state is cleared on initialization.
- The original server-side hard stop is never moved.
- No hedge, averaging, scale-in, pyramid, grid, martingale, random path,
  adaptive fit, PnL-dependent state, or discretionary override exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_long_day` | 8 | [8] | exact source-positive date |
| `strategy_short_day` | 26 | [26] | exact source-negative date |
| `strategy_return_months` | 1 | [1] | consecutive completed calendar-month formation |
| `strategy_entry_grace_minutes` | 180 | [180] | measured WTI executable-session attachment |
| `strategy_history_bars` | 100 | [100] | bounded endpoint scan |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 2.75 | [2.75] | frozen hard-stop distance |
| `strategy_max_hold_days` | 5 | [5] | weekend-safe stale guard |
| `strategy_max_spread_points` | 2500 | [2500] | entry spread ceiling |

Every value is locked. A failed baseline may not be rescued by changing a
date, return horizon, agreement sign, direction, entry grace, stop, hold, or
spread ceiling.

## Author Claims

Borowski reports the positive day-8 and negative day-26 WTI cells at nominal
significance in its historical futures sample. Moskowitz, Ooi, and Pedersen
establish the completed own-return-sign momentum family across futures and
include WTI. The exact interaction is a QM falsification hypothesis.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 25.0` reflects WTI gap, roll, sparse-sample, and
  interaction risk.
- Expected cadence is approximately 8-10 positions per full year.
- `risk_class: high`.
- `ml_required: false`.

## Risk

Backtests use one stop-normalized fixed budget: `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Signal magnitude never changes
lots or risk.

Q02 must retire on zero trades, fewer than five completed positions per full
year, wrong or shifted dates, invalid/non-consecutive month endpoints,
current-bar leakage, disagreement-side trades, late/repeated entries, missing
stops, wrong exit timing, risk-mode mismatch, nondeterminism, or nonpositive
governed economics. Multiple testing, post-2016 decay, the untested
interaction, futures/CFD basis, broker-label mapping, spread, gaps, financing,
roll construction, and later book correlation are first-order risks. No
parameter rescue or correlation waiver is authorized.

## Strategy Allowability Check

- R1 `PASS_WITH_COMPOSITE_AND_MULTIPLE_TESTING_RISK`: two peer-reviewed
  complete-read lineages, exact WTI cells, JFE DOI and retrieval hash,
  explicit WTI membership, and disclosed translation/multiple-testing risk.
- R2 `PASS`: dates, normalized labels, endpoints, sign map, direction,
  attempt state, entry clock, risk, stop, spread, and exit are fixed.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history with directly measured
  session offset supplies every runtime input.
- R4 `PASS`: deterministic calendar/OHLC/logarithm/ATR only; no trained or
  banned signal logic, external runtime feed, grid, martingale, scale-in, or
  pyramid.
- Dedup `PASS`: no exact match; the sole fuzzy family match is manually
  separated by return horizon, regime relation, date set, and lifecycle.

## Framework Alignment

- no_trade: exact host/D1/ID/slot/seed, locked fixed-risk/news/Friday/input
  contract, and cheap identity guards.
- trade_entry: normalized exact-date clock, persistent attempt, consecutive
  completed-month endpoint scan, agreement direction, spread/quote/ATR
  validation, and frozen hard stop.
- trade_management: first-following-D1, stale, malformed, and duplicate
  exposure closes before entry-only gates.
- trade_close: V5 close path, server hard stop, Friday fail-safe, and
  framework kill switch.

## Framework Execution Overrides

News temporal mode OFF, compliance NONE, and legacy news mode OFF. Friday
close is enabled at broker hour 21. Framework risk sizing, server-side hard
stop, and kill switch remain authoritative.

## Exit Precedence

1. Framework kill switch and server-side hard stop.
2. First following normalized D1 boundary or malformed exposure cleanup.
3. Five-calendar-day stale close.
4. Friday-close fail-safe.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` D1 OHLC, broker time/calendar, measured session-offset
contract, completed ATR, quotes, spread, symbol metadata, positions, deals,
and terminal global state only. No external runtime source is authorized.

## Falsification And Requalification

Any change to label normalization, exact dates, completed-month endpoints,
return sign/direction, entry grace, stop, hold, spread, retry state, symbol,
timeframe, news/Friday contract, or risk mode requires a new binary and full
pipeline requalification.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial exact-date/prior-month WTI extraction | G0 | APPROVED |
| v1-build | 2026-08-16 | deterministic V5 implementation and strict validation | Q01 | PASS |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED | `decisions/2026-08-16_wti_dom_month_momentum_g0.md` |
| Q01 Build Validation | 2026-08-16 | PASS | strict compile `framework/build/compile/20260816_151015/QM5_41025_wti-dom-mom1.compile.log`; targeted build check `D:/QM/reports/framework/21/build_check_20260816_151014.json`; static P1 `D:/QM/reports/pipeline/QM5_41025/P1/P1_QM5_41025_result.json`; eight deterministic reference tests PASS |
| Q02 Baseline Screening | - | NOT ENQUEUED | - |

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does not authorize
a manual tester launch, live/demo/shadow/stress execution, AutoTrading,
`T_Live`, a deploy or T_Live manifest, portfolio admission, portfolio-gate
change, or a correlation waiver.
