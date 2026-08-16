---
card_schema_version: 2
ea_id: QM5_20215
slug: wti-dom-trend
type: strategy
strategy_id: BOROWSKI-MOP-WTI-DOMTREND-2026_S01
variant_id: BOROWSKI-MOP-WTI-DOMTREND-2026_S01
source_id: BOROWSKI-MOP-WTI-DOMTREND-2026
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20215_wti-dom-trend_card.md
execution_contract_status: DRAFT
created: 2026-08-04
created_by: Research+Development
last_updated: 2026-08-16
source_authors: "Krzysztof Borowski; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: exact-broker-day-1-long-positive-252d-return-or-day-26-short-negative-252d-return-one-session
source_citation: "Borowski (2016), Journal of Management and Financial Sciences 26, 27-44; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: peer_reviewed_paper
    citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts. Journal of Management and Financial Sciences 26, 27-44."
    location: "WTI numbered-day table; complete governed review strategy-seeds/sources/BOROWSKI-WTI-DOM26-2016/source.md and day-1 extraction QM5_20028"
    quality_tier: A
    role: exact_numbered_day_direction
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete governed review strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: completed_252d_directional_state
sources:
  - "[[sources/BOROWSKI-MOP-WTI-DOMTREND-2026]]"
concepts: ["[[concepts/wti-day-of-month-seasonality]]", "[[concepts/time-series-momentum]]", "[[concepts/calendar-trend-agreement]]"]
indicators: ["[[indicators/rolling-return]]", "[[indicators/atr]]"]
strategy_type_flags: [commodity, energy, day-of-month-seasonality, time-series-momentum, trend-gate, symmetric-long-short, exact-date-entry, next-bar-exit, atr-hard-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 6-10 exact-date, trend-agreeing one-session WTI packages/year after warm-up; Q02 must prove at least five/year on average or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 20.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_STARTED
review_focus: "Falsify whether exact WTI numbered-day direction conditioned on agreeing slow trend supplies a sparse physical-crude clock distinct from the certified XAU/SP500/NDX/XNG book; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode, exact_date_no_shift, completed_bar_trend, restart_safe_attempt, next_d1_exit, friday_close, q02_frequency_floor, source_to_cfd_basis, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER 2026-08-04 commodity/energy sleeve mission: R1 two peer-reviewed complete-read lineages with weak day-1 evidence disclosed; R2 fixed exact dates, completed 252-D1 sign, directions, attempt state, stop, and next-D1 exit; R3 registered native XTIUSD.DWX D1 carrier; R4 deterministic native arithmetic only. Deterministic dedup CLEAN across 4,272 registry rows and 389 cards plus manual parent/neighbor resolution."
---

# QM5_20215 WTI Day-of-Month / Slow-Trend Agreement

## Hypothesis

WTI's numbered-day return pattern may reflect recurring physical-market cash
flows, hedging, storage, and contract-cycle behavior. Requiring WTI's own
completed 252-D1 trend to agree with the source-documented calendar direction
may suppress the unconditional calendar parent's counter-regime trades. The
result is a sparse crude-oil information clock distinct from the certified
index, metal, and natural-gas book.

This is a falsifiable interaction hypothesis. It is not a profitability,
significance, decorrelation, certification, or portfolio-admission claim.

## Source Traceability And Claim Boundary

The governed packet
strategy-seeds/sources/BOROWSKI-MOP-WTI-DOMTREND-2026/source.md joins the
complete Borowski WTI numbered-day review and the complete Moskowitz, Ooi,
and Pedersen time-series-momentum review. Borowski supplies the day-1 long
and day-26 short directions. Moskowitz, Ooi, and Pedersen supply the sign of
the instrument's own completed 12-month return.

Borowski's day-26 result is significant in the reported sample; day 1 is
not. Neither source tests the interaction, exact Darwinex CFD attachment,
one-session hold, ATR stop, fixed cash risk, or portfolio behavior. No source
performance or correlation statistic is imported.

## Non-Duplicate Decision

The deterministic checker scanned 4,272 registry rows and 389 cards and
returned CLEAN with no exact or fuzzy match above threshold. Manual review
separates the candidate from:

- QM5_20028, the unconditional exact-day-1 WTI long parent;
- QM5_20027, the unconditional exact-day-26 WTI short parent;
- QM5_12603, a year-round monthly 12-month WTI trend package;
- QM5_20136, a same-calendar-month plus 63-D1 monthly WTI system;
- QM5_20172, a Friday WTI pattern; and
- QM5_12567, a two-day commodity oscillator pullback.

The exact days, directional mapping, completed 252-D1 agreement, and
one-session lifecycle are jointly load-bearing. Ablating either the calendar
or trend component recreates an existing parent.

## Markets, Timeframe, And Cadence

- Carrier: exact XTIUSD.DWX, D1, slot 0, magic 202150000.
- Long decision: a D1 bar dated exactly day 1 and positive completed trend.
- Short decision: a D1 bar dated exactly day 26 and negative completed trend.
- Hold: first following D1 bar, with a one-calendar-day stale guard.
- Missing numbered dates never shift.
- Expected cadence: six to ten completed packages/year after warm-up; retire
  below five/year on average.

## Rules

The following rules are the complete baseline. There is no parameter sweep,
neighboring-date substitution, unconditional fallback, or post-result rescue.

## 4. Entry Rules

1. Require exact XTIUSD.DWX, D1, EA ID 20215, magic slot 0, and every frozen
   baseline input.
2. Evaluate only on a new D1 bar whose broker-calendar date is exactly 1 or
   26, and only on the first observed tick within five minutes of bar open.
3. Never shift a weekend, holiday, or absent numbered date.
4. Persist the exact YYYYMMDD attempt before history, trend, spread, quote,
   news, ATR, sizing, or order gates. A rejection cannot retry that date.
5. Reject an owned position or owned entry deal already present for that
   exact broker date.
6. Read completed D1 Close[1] and Close[253] and compute
   ln(Close[1] / Close[253]). Invalid endpoints, missing history, or exact
   equality remain flat for the consumed date.
7. On exact day 1, permit one BUY only when the completed return is strictly
   positive. On exact day 26, permit one SELL only when it is strictly
   negative. Every other date/sign combination remains flat.
8. Require a non-negative spread no greater than 2,500 points, a valid
   executable quote, and completed D1 ATR(20).
9. Attach one frozen hard stop 2.75 times ATR(20) from entry, normalized by
   V5 stop rules. There is no take-profit.
10. Open at most one position for magic 202150000; no pending order,
    duplicate entry, scale-in, or pyramid is authorized.

## 5. Exit Rules

1. Close on the first following D1 bar before evaluating a new entry.
2. Close after one elapsed calendar day as a stale-position guard.
3. Close an unexpected direction for the current exact-date package.
4. Framework Friday close remains enabled at broker hour 21 as a fail-safe.
5. Broker hard stops and the framework kill switch remain authoritative.
6. No take-profit, reversal exit, trail, break-even, partial close, scale-in,
   grid, martingale, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol, timeframe, ID, slot, risk contract, news
  contract, Friday-close contract, or unlocked strategy input.
- Fail closed outside exact dates 1 and 26, beyond the five-minute attachment
  window, with invalid attempt state/history/arithmetic, with a disagreeing
  trend sign, invalid ATR/quote/stop, or negative/excess spread.
- Lock news temporal OFF, compliance NONE, and legacy news mode OFF for Q02.
- Runtime may not read futures curves, contracts, inventory, volume, open
  interest, COT, CSV, API, forecasts, external calendars, or trained output.

## 7. Trade Management Rules

- One position maximum for magic 202150000 and one consumed attempt per exact
  broker date.
- Lifecycle exits execute before all entry-only gates and retry throughout
  the following D1 bar if a close is rejected.
- Terminal-persistent attempt state plus owned deal history prevents restart
  re-entry; future-dated tester state is cleared on initialization.
- The original server-side stop is never moved.
- No hedge, averaging, scale-in, pyramid, grid, martingale, random path,
  adaptive fit, or discretionary override exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| strategy_long_day | 1 | [1] | exact long date |
| strategy_short_day | 26 | [26] | exact short date |
| strategy_momentum_lookback_d1 | 252 | [252] | completed own-return horizon |
| strategy_min_abs_return_pct | 0.0 | [0.0] | strict sign; no deadband |
| `strategy_session_offset_min` | 61.6 | [61.6] | XTIUSD.DWX tick-measured maximum |
| `strategy_entry_grace_minutes` | 10 | [10] | tight window around the session-tick anchor |
| `strategy_min_stub_ticks` | 20 | [20] | reject thin weekend/holiday D1 stubs |
| `strategy_min_attach_ticks` | 20 | [20] | minimum ticks within 5 minutes of the qualifying tick |
| strategy_atr_period | 20 | [20] | completed D1 stop estimator |
| strategy_atr_sl_mult | 2.75 | [2.75] | frozen hard-stop distance |
| strategy_max_hold_days | 1 | [1] | next-D1 stale guard |
| strategy_max_spread_points | 2500 | [2500] | entry spread ceiling |

## Risk

Q02 uses exactly RISK_FIXED=1000, RISK_PERCENT=0, and PORTFOLIO_WEIGHT=1.
RISK_FIXED is a stop-normalized loss budget, not fixed notional exposure.
Primary risks are weak/non-significant day-1 evidence, multiple testing,
sample decay, sparse exact dates, WTI gaps and rolls, continuous-CFD basis,
financing, trend whipsaw, same-month state flips, and overlap with other
directional energy systems.

Retire on zero trades or fewer than five completed packages/year on average;
nonpositive governed economics; a wrong date, sign, or direction; current-bar
leakage; shifted dates; duplicate attempts; hold beyond the stale guard;
missing hard stops; invalid risk mode; nondeterminism; or later correlation
rejection. No parameter rescue or correlation waiver is authorized.

## Strategy Allowability Check

- R1 PASS: two peer-reviewed, named-author, complete-read lineages with the
  day-1 statistical weakness explicitly preserved.
- R2 PASS: exact dates, completed endpoints, sign map, entry clock, attempt
  state, stop, exit, and spread cap are mechanical.
- R3 PASS: registered native XTIUSD.DWX D1 route.
- R4 PASS: deterministic calendar/OHLC/logarithm/ATR only; no ML, banned
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.
- Dedup PASS: deterministic CLEAN plus manual parent/neighbor resolution.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
RISK_FIXED backtest setfile, and one paced Q02 enqueue. It does not authorize
manual tester launch, live/demo/shadow execution, AutoTrading, T_Live, a
deploy or T_Live manifest, portfolio admission, portfolio-gate change, or a
correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-04 | initial exact-date / slow-trend interaction | G0 | APPROVED; build pending |
| v2 | 2026-08-04 | initial framework implementation | Q01 | PASS; strict compile and build checks |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-04 | APPROVED; R1-R4 PASS | this card, governed source packet, and durable decision |
| Q01 Build Validation | 2026-08-04 | PASS; 0 compile errors/warnings and 0 build failures/warnings | D:/QM/reports/framework/21/build_check_20260804_201459.json |
| Q02 Baseline Screening | - | NOT STARTED | - |

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
