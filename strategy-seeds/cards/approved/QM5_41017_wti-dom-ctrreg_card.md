---
card_schema_version: 2
type: strategy
strategy_id: BOROWSKI-MOP-WTI-DOMCOUNTER-2026_S01
variant_id: BOROWSKI-MOP-WTI-DOMCOUNTER-2026_S01
source_id: BOROWSKI-MOP-WTI-DOMCOUNTER-2026
ea_id: QM5_41017
slug: wti-dom-ctrreg
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41017_wti-dom-ctrreg_card.md
execution_contract_status: APPROVED
created: 2026-08-15
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-15_wti_dom_counterregime_g0.md
source_approval: decisions/2026-08-15_wti_dom_counterregime_source_approval.md
source_author: "Krzysztof Borowski; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Krzysztof Borowski; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Borowski (2016), Journal of Management and Financial Sciences 26, 27-44; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: peer_reviewed_commodity_seasonality_paper
    citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber. Journal of Management and Financial Sciences 26, 27-44."
    location: "Section 4.3, WTI numbered-day table: positive day 8 with reported p=0.0430 and negative day 26 with reported p=0.0424; complete governed review in strategy-seeds/sources/BOROWSKI-WTI-DOM26-2016/source.md."
    quality_tier: B
    role: exact_numbered_day_directions
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md."
    quality_tier: A
    role: completed_own_return_sign_as_slow_state
strategy_mechanic: exact-broker-day-8-wti-long-only-in-negative-252d-state-or-day-26-short-only-in-positive-252d-state-next-d1-exit
sources:
  - "[[sources/BOROWSKI-MOP-WTI-DOMCOUNTER-2026]]"
concepts:
  - "[[concepts/wti-day-of-month-seasonality]]"
  - "[[concepts/completed-own-return-state]]"
  - "[[concepts/counter-regime-calendar-flow]]"
indicators:
  - "[[indicators/closed-price-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, intraday-day-of-month, calendar-seasonality, counter-regime-gate, exact-date-entry, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410170000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately six to ten completed WTI positions per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_MULTIPLE_TESTING_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ZERO_TRADES
q02_work_item_id: 7eb89f24-8be4-49a0-8b94-5501e124f059
q02_recovery_status: BLOCKED_CARD_MECHANICS
q02_recovery_evidence: docs/ops/evidence/2026-08-16_qm5_41017_q02_zero_trades_classification.md
review_focus: "Falsify whether significant WTI numbered-day directions are concentrated in the opposing completed 252-D1 regime, producing a sparse physical-crude calendar stream distinct from the certified XAU/SP500/NDX/XNG book; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_day_8_day_26_no_shift, opposing_completed_252d_state, completed_bar_only, persistent_exact_date_attempt, next_d1_exit, risk_mode_dual, friday_close, cfd_futures_basis, multiple_testing, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy portfolio mission: R1 PASS_WITH_MULTIPLE_TESTING_RISK for two peer-reviewed complete-read lineages and explicit translation gap; R2 PASS for exact dates, completed 252-D1 opposing state, attempt, stop, and next-D1 exit; R3 PASS for registered XTIUSD.DWX D1; R4 PASS for deterministic native arithmetic without ML or banned signal logic. Canonical dedup CLEAN plus manual parent and sibling review."
---

# WTI Exact-Day Counter-Regime Calendar

## Hypothesis

WTI's source-documented positive day-8 and negative day-26 return patterns may
be concentrated when those recurring physical-market calendar flows run
against the instrument's slow price regime. The strategy therefore buys only
on exact day 8 while the completed 252-D1 WTI return is negative and shorts
only on exact day 26 while that return is positive, then exits at the next D1
boundary.

This is a falsifiable interaction hypothesis. It adds a direct crude-oil
calendar driver outside the certified XAU/SP500/NDX/XNG book, but carrier and
logic do not prove low realized correlation.

## Source Traceability And Claim Boundary

The sole bounded composite packet is
`strategy-seeds/sources/BOROWSKI-MOP-WTI-DOMCOUNTER-2026/source.md`, approved
before extraction in
`decisions/2026-08-15_wti_dom_counterregime_source_approval.md` at commit
`22b4896d1`.

Borowski supplies the day-8 long and day-26 short directions from the WTI
numbered-day table. Moskowitz, Ooi, and Pedersen supply the completed
own-return sign as a slow state. Neither source tests the opposing-state
conjunction, exact Darwinex broker dates, a continuous CFD, a one-session
hold, fixed cash risk, or an ATR hard stop.

Borowski tests many calendar cells without a reported family-wise correction,
and its sample ends in 2016. The five-minute attachment, no-shift calendar,
252-D1 endpoint convention, state opposition, CFD mapping, stop, spread cap,
attempt ledger, and restart lifecycle are disclosed QM translations. No source
return, profit factor, drawdown, trade density, cost, CFD equivalence,
decorrelation, or portfolio result transfers.

## Source-Defined Rules

- Borowski supplies the positive WTI day-8 direction and negative WTI day-26
  direction from the numbered-day table.
- Moskowitz, Ooi, and Pedersen supply the use of a completed own-return sign as
  a slow instrument state and identify WTI in the commodity universe.
- Neither source defines the opposing-state conjunction or the execution and
  risk controls below.

## QM Interpretations

The opposing state, exact Darwinex broker-date mapping, five-minute attachment
grace, `Close[1]`/`Close[253]` endpoint convention, no-shift rule, persistent
attempt, continuous-CFD carrier, ATR stop, spread cap, fixed cash risk, and
next-D1 exit are frozen QM falsification choices. They are not author claims.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,504 EA-registry rows and 600 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review fixes
the material boundaries:

- `QM5_20036_wti-dom8-long` buys every eligible exact day 8 and has no slow
  state or day-26 arm.
- `QM5_20027_wti-dom26-short` sells every eligible exact day 26 and has no slow
  state or day-8 arm.
- `QM5_20215_wti-dom-trend` buys exact day 1 only in a positive 252-D1 state
  and sells exact day 26 only in a negative state. This candidate uses the
  source-significant day-8 long and requires the opposite state on both arms;
  its shared day-26 signals are mutually exclusive with that EA.
- `QM5_12603_wti-tsmom12m` owns a monthly symmetric trend position and has no
  exact-date trigger or one-session lifecycle.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback and reads
  neither an exact numbered-day clock nor a completed 252-D1 state.

Verdict:
`CLEAN_WTI_EXACT_DAY8_DAY26_COUNTER_REGIME_CALENDAR_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1; EA `QM5_41017`; magic slot 0; magic `410170000`.
- Long decision: exact broker-calendar day 8 with a strictly negative
  completed 252-D1 log return.
- Short decision: exact broker-calendar day 26 with a strictly positive
  completed 252-D1 log return.
- Normal exit: the first following D1 boundary.
- Expected cadence: approximately six to ten completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. No neighboring-date
substitution, threshold sweep, unconditional fallback, trend-following arm,
weekday, event, curve, volume, oscillator, or external-data filter is
authorized.

## 4. Entry Rules

1. Evaluate only on a new exact `XTIUSD.DWX` D1 bar.
2. Require the broker-calendar day of month to be exactly 8 or 26. Never shift
   a missing weekend or holiday date to an adjacent session.
3. Require the first observed tick to be within five minutes of the current D1
   bar's opening timestamp. A late attachment consumes the date flat.
4. Persist the exact `yyyymmdd` attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry the date.
5. Require exactly 253 positive finite completed D1 closes and compute
   `slow_return = log(Close[1] / Close[253])`. Current-bar OHLC may not enter
   the state.
6. On exact day 8, submit one BUY only when `slow_return < 0`. On exact day 26,
   submit one SELL only when `slow_return > 0`. Exact zero, invalid history, or
   the other date/sign combinations consume the date flat.
7. Require completed `ATR(20,D1)` and attach one frozen hard stop at
   `2.75 * ATR`. Use no take-profit.
8. Require no owned position, a positive finite executable quote, and no
   genuinely positive spread wider than 2,500 points. A modeled zero `.DWX`
   spread is valid.
9. Use magic slot 0 only. Signal magnitude never scales risk. No pending order,
   duplicate entry, scale-in, pyramid, grid, or martingale exists.

## 5. Exit Rules

1. Close owned exposure on the first D1 bar whose opening timestamp differs
   from the position's entry D1 bar, before any entry-only gate.
2. Close after one elapsed calendar day as a stale guard.
3. Close an owned position with an invalid open time, wrong symbol, wrong
   magic, or a side inconsistent with its entry date.
4. Framework Friday close remains enabled at broker hour 21 as a fail-safe.
5. The frozen broker hard stop and framework kill switch remain authoritative.
6. No target, opposite-state exit, trailing stop, break-even move, partial
   close, scale-in, pyramid, or discretionary close is authorized.

## 6. Filters (No-Trade Module)

- Exact host contract: `XTIUSD.DWX`, D1, magic slot 0, allocated EA ID.
- Every strategy parameter is locked to the card baseline.
- Exact dates, opening grace, completed history, strict state opposition,
  quote, spread, ATR, stop, attempt, and one-position checks fail closed.
- Both news axes and legacy news mode are OFF because the signal uses only
  native completed prices and broker dates.
- Runtime may not read futures curves, contracts, inventory, volume, open
  interest, COT, external calendars, files, APIs, forecasts, or trained
  output.

## 7. Trade Management Rules

- One position maximum per magic and one consumed attempt per exact date.
- Lifecycle exits execute on every tick before entry-only gates and retry
  throughout the following D1 bar if a close is rejected.
- Terminal-persistent exact-date state plus owned entry-deal history prevents
  restart re-entry; future-dated tester state is cleared at initialization.
- The original server-side hard stop is never moved.
- No hedge, averaging, scale-in, pyramid, grid, martingale, random path,
  adaptive fit, PnL-dependent state, or discretionary override exists.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_long_day` | 8 | [8] | exact source-positive long date |
| `strategy_short_day` | 26 | [26] | exact source-negative short date |
| `strategy_momentum_lookback_d1` | 252 | [252] | completed slow-state horizon |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] | strict sign; no deadband |
| `strategy_entry_grace_minutes` | 5 | [5] | exact-bar attachment bound |
| `strategy_atr_period` | 20 | [20] | completed hard-stop estimator |
| `strategy_atr_sl_mult` | 2.75 | [2.75] | frozen stop distance |
| `strategy_max_hold_days` | 1 | [1] | next-D1 stale guard |
| `strategy_max_spread_points` | 2500 | [2500] | WTI entry spread ceiling |

Every value is locked. A failed baseline may not be rescued by shifting dates,
flipping state logic, adding a deadband, widening stops, or extending the hold.

## Author Claims

Borowski reports the positive day-8 and negative day-26 WTI cells at nominal
significance in its historical sample. Moskowitz, Ooi, and Pedersen establish
the own-return-sign state family across futures, including WTI. The opposing-
state conjunction is entirely a QM falsification hypothesis.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering estimate, not evidence.
- `expected_dd_pct: 25.0` reflects WTI gap, roll, and counter-regime risk.
- Expected cadence is approximately six to ten positions per full year.
- `risk_class: high`.
- `ml_required: false`.

## Risk

Backtests use one fixed stop-normalized budget: `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Signal magnitude never changes
lots or risk.

Q02 must retire on zero trades, fewer than five completed positions per full
year, wrong or shifted dates, non-opposing state, current-bar leakage,
late/repeated entries, missing stops, wrong exit timing, risk-mode mismatch,
nondeterminism, or nonpositive governed economics. Multiple testing,
post-2016 decay, CFD/futures basis, gaps, roll construction, financing, and
later book correlation are first-order risks. No parameter rescue or
correlation waiver is authorized.

## Strategy Allowability Check

- R1 `PASS_WITH_MULTIPLE_TESTING_RISK`: two peer-reviewed complete-read
  lineages, exact WTI table locations, JFE DOI and retrieval hash, and an
  explicit untested-conjunction boundary.
- R2 `PASS`: dates, endpoints, sign map, attempt state, clock, direction,
  stop, spread, risk, and exit are deterministic.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 route.
- R4 `PASS`: native calendar/OHLC/logarithm/ATR only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.
- Dedup `PASS`: deterministic `CLEAN` plus manual parent/sibling review.

## Framework Alignment

- no_trade: exact host/D1/ID/slot, locked inputs, news OFF, Friday-close
  contract, and identity guards.
- trade_entry: exact day 8/day 26 clock, persistent attempt, completed 252-D1
  opposing state, spread/quote/ATR validation, and one directed order.
- trade_management: next-D1, malformed-side, and one-day stale closes before
  entry-only gates.
- trade_close: V5 close path, hard stop, Friday fail-safe, and kill switch.

## Framework Execution Overrides

News temporal mode OFF, compliance NONE, and legacy mode OFF. Friday close is
enabled at broker hour 21. Framework risk sizing, server-side hard stop, and
kill switch remain authoritative.

## Exit Precedence

1. Framework kill switch and server-side hard stop.
2. First following D1 boundary or malformed exposure cleanup.
3. One-calendar-day stale close.
4. Friday-close fail-safe.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` D1 OHLC, completed ATR, executable quotes, modeled spread,
symbol metadata, broker calendar, positions, deals, and terminal global state
only.

## Falsification And Requalification

Any change to dates, no-shift behavior, direction, return horizon or sign,
entry grace, stop, hold, spread, attempt state, symbol, timeframe, news mode,
Friday close, or risk mode requires a new binary and full pipeline
requalification.

## Safety Boundary

OWNER G0 authorizes one branch-only non-live build, strict Q01 validation,
one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It excludes
manual tester dispatch;
live/demo/shadow/stress/optimization setfiles; AutoTrading; `T_Live`; deploy or
T_Live manifests; portfolio-gate changes; portfolio admission; and correlation
waivers.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-15 | initial exact-date counter-regime extraction | G0 | APPROVED |
| v2 | 2026-08-15 | initial V5 implementation and strict validation | Q01 | PASS |
| v3 | 2026-08-16 | paced never-tested baseline enqueue | Q02 | ENQUEUED; pending |
| v3-z1 | 2026-08-16 | classify the valid bound zero-trade result without changing mechanics | Q02 recovery | `ZERO_TRADES`; frozen five-minute D1-open rule requires a new approved variant |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-15 | APPROVED; R1-R4 reviewed | source packet, source-approval decision, G0 decision, and this card |
| Q01 Build Validation | 2026-08-15 | PASS; 0 errors, 0 warnings | `D:\QM\reports\framework\21\build_check_20260815_221224.json`; deterministic reference tests 8/8 PASS |
| Q02 Baseline Screening | 2026-08-16 | `ZERO_TRADES`; valid bound run, not PASS or certification | work item `7eb89f24-8be4-49a0-8b94-5501e124f059`; `D:/QM/reports/work_items/7eb89f24-8be4-49a0-8b94-5501e124f059/QM5_41017/20260815_222420/summary.json` |
| Q02 Zero-Trades Recovery | 2026-08-16 | `BLOCKED_CARD_MECHANICS`; normal WTI first ticks miss the frozen five-minute nominal D1-open gate | `docs/ops/evidence/2026-08-16_qm5_41017_q02_zero_trades_classification.md` |
