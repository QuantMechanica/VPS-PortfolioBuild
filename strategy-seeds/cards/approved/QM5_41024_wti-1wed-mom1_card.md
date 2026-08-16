---
card_schema_version: 2
type: strategy
strategy_id: LI-MOP-WTI-1WED-MOM1-2026_S01
variant_id: LI-MOP-WTI-1WED-MOM1-2026_S01
source_id: LI-MOP-WTI-1WED-MOM1-2026
ea_id: QM5_41024
slug: wti-1wed-mom1
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41024_wti-1wed-mom1_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_wti_first_wednesday_month_momentum_g0.md
source_approval: decisions/2026-08-16_wti_first_wednesday_month_momentum_source_approval.md
source_author: "Wenhui Li; Qi Zhu; Fenghua Wen; Normaziah Mohd Nor; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Wenhui Li; Qi Zhu; Fenghua Wen; Normaziah Mohd Nor; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Li et al. (2022), Energy Economics 106, 105817, DOI 10.1016/j.eneco.2022.105817; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_energy_paper
    citation: "Li, W., Zhu, Q., Wen, F., and Nor, N. M. (2022). The evolution of day-of-the-week and the implications in crude oil market. Energy Economics 106, 105817."
    location: "DOI 10.1016/j.eneco.2022.105817; governed abstract/highlights evidence boundary in strategy-seeds/sources/LI-WTI-DOW-2022.md"
    quality_tier: A
    role: wti_wednesday_information_clock
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: instrument_own_completed_return_sign_and_one_month_formation
strategy_mechanic: first-genuine-wednesday-of-month-follow-prior-completed-calendar-month-wti-return-sign-next-d1-flat
sources:
  - "[[sources/LI-MOP-WTI-1WED-MOM1-2026]]"
concepts:
  - "[[concepts/crude-oil-day-of-week-seasonality]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/calendar-trend-interaction]]"
indicators:
  - "[[indicators/completed-calendar-month-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, day-of-week-seasonality, time-series-momentum, first-wednesday, monthly-attempt, one-session-hold, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410240000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed WTI positions per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_STARTED
review_focus: "Falsify a direct-WTI calendar/trend sleeve outside the certified XAU/SP500/NDX/XNG book. Verify normalized first-Wednesday identity, exact completed-month endpoints, no late/repeated entry, return-sign direction, and next-D1 exit; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_first_wednesday_no_shift, normalized_energy_label, completed_calendar_month_endpoints, no_current_bar_leakage, symmetric_return_sign, monthly_attempt_state, no_late_restart_entry, next_d1_exit, risk_mode_dual, friday_close, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 two peer-reviewed primary lineages with complete MOP paper evidence and explicit Li abstract/highlights boundary, plus disclosed conjunction/hold translation; R2 exact normalized first-Wednesday clock, completed-month endpoints, strict sign, attempt state, hard stop, and next-D1 lifecycle; R3 native XTI D1; R4 deterministic native arithmetic without trained or banned signal logic; canonical dedup CLEAN across 4,511 registry rows and 607 root cards plus manual family review."
---

# WTI First-Wednesday Prior-Month Momentum

## Hypothesis

WTI's immediately completed broker-month return direction may persist into the
first source-documented Wednesday information session of the next month. The
candidate waits for that exact session, takes the completed-month sign, and
owns only the following D1 interval. This combines a slow physical-crude
return state with a sparse calendar clock instead of holding WTI throughout a
month or trading every weekday occurrence.

This is a falsifiable composite hypothesis. It is not a source-replication,
profitability, significance, decorrelation, certification, or portfolio-
admission claim.

## Source Traceability And Claim Boundary

The governed source packet is
`strategy-seeds/sources/LI-MOP-WTI-1WED-MOM1-2026/source.md`, approved before
extraction in
`decisions/2026-08-16_wti_first_wednesday_month_momentum_source_approval.md`
at commit `01d4b0d45`.

Li et al. supply the positive Wednesday WTI information clock and warn that
weekday efficiency changes through time. Moskowitz, Ooi, and Pedersen supply
the sign of an instrument's own completed return, the one-month formation
family, and explicit WTI membership in their commodity universe.

Neither source tests a first-Wednesday/prior-month conjunction, symmetric
long/short direction at that clock, a one-session hold, continuous Darwinex
CFD bars, normalized energy labels, an ATR stop, fixed cash risk, or the QM
portfolio. No source return, coefficient, significance, trade density, cost,
drawdown, CFD equivalence, correlation, or portfolio statistic transfers.

## Non-Duplicate Decision

The canonical checker scanned 4,511 EA-registry rows and 607 root cards. It
found no exact identity and no fuzzy match above threshold. Manual review
fixes the material boundaries:

- `QM5_20154_wti-wed-trend` trades every genuine Wednesday, long only, when a
  completed 252-D1 return is positive. This card trades only once per month,
  uses consecutive completed calendar-month endpoints, and follows either
  sign.
- `QM5_20170_wti-wed-bear` trades every genuine Wednesday, long only, when a
  completed 252-D1 return is negative. This card follows rather than fades its
  completed-month sign.
- `QM5_20022_wti-wed-long` and `QM5_12775_wti-wed-prem` are unconditional
  Wednesday-long packages without a completed-month state.
- `QM5_20187_wti-tsmom1m` enters at the month boundary and owns a full monthly
  package. This card waits for the first genuine Wednesday and owns one D1
  interval.
- `QM5_41013_wti-mopen-mom` forms from the current month's first five sessions,
  enters on session six, and owns the residual month. This card forms only
  from the immediately completed prior month.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers, not fixed-clock WTI completed-month continuation.

Verdict:
`CLEAN_WTI_FIRST_WEDNESDAY_PRIOR_MONTH_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; magic `410240000`.
- Decision: first executable tick within 180 minutes of the first normalized
  Wednesday D1 session dated day 1-7 in each broker month.
- Formation: log return between the last completed closes of the two months
  immediately before the decision month.
- Direction: BUY positive, SELL negative, exact zero flat.
- Normal exit: first following normalized D1 boundary.
- Expected cadence: approximately 10-12 completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The rules below are the complete authorized baseline. No weekday, date range,
return horizon, magnitude threshold, stop, hold, news, or direction sweep is
authorized.

## 4. Entry Rules

1. Run only on exact `XTIUSD.DWX`, D1, EA ID 41024, magic slot 0, and every
   frozen baseline input.
2. On a new D1 bar, derive the governed energy label offset. Accept only zero
   or a uniform `+86400` seconds when the raw current label is respectively
   less than 24 hours or 24-48 hours behind broker time. Normalize the current
   and historical labels with that same offset; any other state fails closed.
3. Require the normalized current label's date to equal the broker date, its
   weekday to be Wednesday, and its day of month to be 1-7. Require the
   immediately prior normalized completed D1 label to be Tuesday. Never shift
   a missing or holiday first Wednesday.
4. Require the first observed tick within 180 minutes of the executable D1
   session open, using raw-label elapsed time modulo one day so both governed
   label conventions share the same grace. A late attachment consumes the
   month flat and is never backfilled.
5. Persist the exact normalized broker `yyyymm` attempt before history,
   signal, news, spread, quote, ATR, sizing, or order gates. Reject an owned
   position or owned entry deal already present for that month.
6. From completed D1 bars only, identify the newest close in the immediately
   prior normalized broker month and the newest close in the month before it.
   Require positive finite prices, strict reverse-chronological timestamps,
   and exact consecutive month keys. Current-month closes and the live bar do
   not enter either endpoint.
7. Compute `prior_month_return = log(PriorMonthEnd /
   PriorPriorMonthEnd)`. BUY only when it is strictly positive and SELL only
   when it is strictly negative. Exact zero, invalid history, or invalid
   arithmetic consumes the month flat. Signal magnitude never scales risk.
8. Require a non-negative spread no greater than 1,500 points, a valid
   executable quote, and completed `ATR(20,D1)`.
9. Attach one frozen hard stop `3.0 * ATR(20,D1)` from entry, normalized by V5
   stop rules. There is no take-profit.
10. Open at most one position for magic `410240000`; no pending order,
    duplicate entry, scale-in, grid, martingale, or pyramid is authorized.

## 5. Exit Rules

1. Close on the first normalized D1 bar whose date differs from the position's
   broker opening date, before evaluating a new entry.
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
- Fail closed for invalid label normalization; broker-date mismatch; a
  non-Wednesday, day outside 1-7, or non-Tuesday prior label; late attachment;
  consumed month; owned exposure/deal; invalid or non-consecutive month
  endpoints; zero/invalid return; invalid ATR, quote, stop, or spread.
- Lock news temporal OFF, compliance NONE, and legacy news mode OFF for Q02.
- Runtime may not read futures curves, contracts, inventory, volume, open
  interest, event feeds, CSV, API, forecasts, external calendars, or trained
  output.

## 7. Trade Management Rules

- Lifecycle repair and exit execute before all entry-only gates on each new D1
  bar.
- One position maximum for magic `410240000` and one consumed attempt per
  normalized broker month.
- Terminal-persistent attempt state plus owned deal history prevents restart
  re-entry; future-dated tester state is cleared on initialization.
- The original server-side stop is never moved.
- No hedge, averaging, scale-in, pyramid, grid, martingale, random path,
  adaptive fit, or discretionary override exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_entry_dow` | 3 | [3] | normalized Wednesday |
| `strategy_first_week_last_dom` | 7 | [7] | first-Wednesday boundary |
| `strategy_return_months` | 1 | [1] | completed calendar-month formation |
| `strategy_hold_bars` | 1 | [1] | first-following-D1 exit |
| `strategy_entry_grace_minutes` | 180 | [180] | executable-session attachment |
| `strategy_history_bars` | 100 | [100] | bounded endpoint scan |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 5 | [5] | stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | entry spread ceiling |

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. `RISK_FIXED` is a stop-normalized loss budget, not fixed
notional exposure.

Primary risks are source decay, the untested interaction, shortening the
source monthly hold to one D1 interval, continuous-CFD versus futures basis,
WTI gaps and roll construction, broker-label normalization, financing,
calendar holidays, sparse annual density, and overlap with other directional
energy systems.

Retire on zero trades or fewer than five completed packages/year on average;
nonpositive governed economics; wrong/shifted Wednesday; wrong month
endpoints; current-bar leakage; duplicate attempts; sign/direction mismatch;
hold beyond the next D1 boundary; missing hard stops; invalid risk mode;
nondeterminism; or later correlation rejection. No parameter rescue or
correlation waiver is authorized.

## Strategy Allowability Check

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: two peer-reviewed primary
  lineages with DOI identity, complete MOP paper evidence, explicit Li
  abstract/highlights boundary, and disclosed untested interaction/hold.
- R2 `PASS`: normalized date, exact first Wednesday, consecutive completed
  month endpoints, strict sign map, attempt state, stop, spread, and exit are
  fixed.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history and MT5 execution state
  supply every runtime input.
- R4 `PASS`: deterministic calendar/OHLC/logarithm/ATR only; no trained or
  banned signal logic, external runtime feed, grid, martingale, scale-in, or
  pyramid.
- Dedup `PASS`: canonical `CLEAN` plus manual family/parent resolution.

## Framework Alignment

- no_trade: exact host/D1/ID/slot/seed, locked fixed-risk/news/Friday/input
  contract, and cheap identity guards.
- trade_entry: normalized first-Wednesday clock, consumed-month state,
  consecutive completed-month endpoint scan, return-sign direction,
  spread/quote/ATR validation, and frozen hard stop.
- trade_management: first-following-D1, stale, malformed, and duplicate
  exposure closes before entry-only gates.
- trade_close: V5 close path, server hard stop, Friday fail-safe, and framework
  kill switch.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` D1 OHLC, broker time/calendar, ATR, quotes, spread, symbol
metadata, positions, deals, and terminal global state only. No external
runtime source is authorized.

## Falsification And Requalification

Any change to label normalization, weekday/date predicate, completed-month
endpoints, return sign/direction, entry grace, stop, hold, spread, retry state,
symbol, timeframe, news/Friday contract, or risk mode requires a new binary
and full pipeline requalification.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial first-Wednesday/prior-month WTI extraction | G0 | APPROVED |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED | `decisions/2026-08-16_wti_first_wednesday_month_momentum_g0.md` |
| Q01 Build Validation | pending | NOT STARTED | build only after registry preflight |
| Q02 Baseline Screening | pending | NOT STARTED | enqueue only after strict Q01 PASS |

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does not authorize
a manual tester launch, live/demo/shadow/stress execution, AutoTrading,
`T_Live`, a deploy or T_Live manifest, portfolio admission, portfolio-gate
change, or a correlation waiver.
