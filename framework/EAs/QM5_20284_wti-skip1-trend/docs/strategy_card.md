---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_SKIP1_S32
variant_id: MOP-TSMOM-2012_XTI_SKIP1_S32
source_id: MOP-WTI-SKIP1-2026
ea_id: QM5_20284
slug: wti-skip1-trend
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20284_wti-skip1-trend_card.md
execution_contract_status: DRAFT
created: 2026-08-11
created_by: Research+Development
last_updated: 2026-08-11
g0_status: APPROVED
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-WTI-SKIP1-2026/source.md"
    quality_tier: A
    role: primary_own_price_direction_and_monthly_cadence
strategy_mechanic: monthly-wti-sign-of-twelve-completed-month-return-ending-before-one-skipped-completed-month
sources:
  - "[[sources/MOP-WTI-SKIP1-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/delayed-trend-state]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, time-series-momentum, skip-one-month, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202840000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI packages/year after fourteen completed month ends because only exact-zero or invalid delayed trends stay flat; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify a direct WTI delayed trend that excludes the newest completed month without conditioning on it; Q09 alone may establish realized book decorrelation from XAU/SP500/NDX/XNG."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [consecutive_completed_months, skipped_interval_exclusion, delayed_return_orientation, no_skipped_return_gate, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-11_qm5_20284_wti_skip1_trend_g0.md: R1 one complete-read peer-reviewed WTI source; R2 fixed fourteen endpoints, excluded newest return, exact older twelve-month return, symmetric direction, attempt, stop, and lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic. The canonical checker found no exact identity; shared-source fuzzy matches and the closest trailing/pullback systems were manually separated."
---

# QM5_20284 WTI Skip-One-Month Trend

## Hypothesis

WTI can sustain slow directional regimes as production, capital investment,
inventory, transport, refining, hedging, and demand adjust. The newest month
can be dominated by a temporary shock or partial reversal. This card tests a
delayed structural state: ignore that newest completed month and trade the
sign of the exact twelve-month return that ended one month earlier.

The direct crude-oil carrier is economically different from the certified
XAU, SP500, NDX, and XNG book. That does not prove decorrelation,
profitability, or portfolio suitability. Q02 owns density and baseline
economics; unchanged downstream gates, including Q09, own robustness and
realized overlap.

## Source Traceability And Claim Boundary

The sole source of record is the governed bounded packet
`strategy-seeds/sources/MOP-WTI-SKIP1-2026/source.md`. Its complete-read parent
is Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of Financial
Economics* paper documenting monthly own-return continuation over the first
twelve lags and including WTI among its commodity futures.

The source does not test discarding the newest completed month. The excluded
interval, exact endpoint convention, Darwinex continuous CFD, broker-month
reconstruction, fixed-dollar sizing, ATR hard stop, spread cap, attempt
ledger, and lifecycle controls are transparent QM mechanizations. No source
return, WTI-only alpha, drawdown, trade count, CFD equivalence, or correlation
statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,349 EA-registry rows and 460 root cards. It
found no exact identity and surfaced three shared-source fuzzy matches. Manual
mechanic review resolves those and the closest systems:

- `QM5_12603_wti-tsmom12m` ends its trailing return at the newest available
  observation and uses a neutral band;
- `QM5_20239_wti-pulltrend` uses the older twelve-month interval only when the
  newest month has the opposite sign; this card never conditions on that sign;
- `QM5_20258_wti-mom-vote` votes nested 1/3/12-month returns sharing the newest
  endpoint;
- `QM5_20280_wti-tsmom4m` uses four months ending at the newest endpoint; and
- XNG, calendar, event, range, rank, regression, robust-location, and basket
  systems use different carriers or information objects.

The fourteen endpoints, deliberate exclusion of `M0/M1`, exact `M1/M13`
return, absence of any skipped-return gate, exact-zero rejection, consumed
attempt, and monthly renewal are jointly load-bearing. Verdict:
`CLEAN_AFTER_FUZZY_AND_MECHANIC_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202840000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: fourteen consecutive completed broker-month closes.
- Signal state: sign of the exact twelve-month return ending at `t-2`.
- Excluded state: the newest completed `t-2` to `t-1` return is validated but
  cannot affect direction, eligibility, or risk.
- Holding clock: next broker-month boundary, with a forty-calendar-day guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and contract metadata only.

## Formula

At the start of broker month `t`, define completed month-end closes in reverse
chronological order:

```text
M0  = close at end of month t-1  // deliberately skipped
M1  = close at end of month t-2  // trend endpoint
M13 = close at end of month t-14 // trend start

skipped_return = ln(M0 / M1)
trend_return   = ln(M1 / M13)
```

BUY when `trend_return > 0`. SELL when `trend_return < 0`. Exact zero or an
invalid state stays flat. `skipped_return` must be finite and may be logged,
but it must not gate, confirm, reverse, or size the position.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to a return containing `M0`, a different horizon,
moving average, rank, regression, vote, calendar state, external series, or
previous pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20284`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order checks. A flat, rejected, failed,
   stopped, or blocked outcome cannot retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Reconstruct exactly fourteen completed month-end closes from bounded D1
   history. Require the newest endpoint to be the immediately prior month and
   every older month key to be consecutive.
6. Require positive finite closes. Calculate `ln(M0/M1)` only to validate the
   skipped interval and calculate the signal only as `ln(M1/M13)`.
7. Buy for a positive signal or sell for a negative signal. Exact zero stays
   flat. Never use the skipped return as a condition or sizing input.
8. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, valid point/digit/volume metadata, and fixed-risk sizing.
9. Open at most one market position with a frozen `3.5 * ATR(20,D1)` broker
   hard stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement risk, even if direction is unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close duplicate, wrong-symbol, invalid-type, or missing-stop exposure owned
   by this EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source-aligned hold spans weekends.
6. No intramonth signal flip, profit target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  malformed or nonconsecutive endpoints, current-month leakage, nonpositive
  or nonfinite close, wrong return orientation, exact-zero signal, excessive
  spread, invalid quote, unavailable ATR, invalid stop, or invalid metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read a futures chain, inventory release, volume, open
  interest, file, API, analyst forecast, trained output, optimizer result, or
  portfolio state.

## 7. Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly renewal or after forty
  calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; tester initialization clears a future marker so
  historical runs remain deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or missing-
  stop exposure before any new entry logic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_trend_months` | 12 | [12] | exact older completed-month interval |
| `strategy_skip_months` | 1 | [1] | newest completed interval excluded |
| `strategy_history_bars` | 500 | [500] | bounded D1 endpoint reconstruction |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

The endpoint count, excluded interval, return orientation, direction, entry
clock, risk, stop, hold, and no-retry policy are locked. Changing any requires
a new card and full pipeline run.

## Author Claims

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, report continuation across the first twelve monthly lags, and identify
WTI in their commodity universe. They do not claim this skipped-month rule
works, that a continuous CFD reproduces rolling futures, or that the candidate
diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, CFD roll/basis and financing,
single-name concentration, delayed reactions to regime changes, hard-stop
slippage, and correlation with XNG or risk assets can dominate the premise.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full
  post-warm-up year.
- Fail on wrong endpoint order, nonconsecutive months, current-month leakage,
  inclusion of the skipped interval, a skipped-return gate, wrong orientation,
  wrong-side entry, repeated attempt, hold beyond forty days, missing hard
  stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing horizon, excluded interval, direction,
  entry clock, stop, hold, spread cap, retry policy, or carrier.

## Strategy Allowability Check

- [x] R1: PASS. One tier-A peer-reviewed source with DOI, complete-paper
  evidence, durable retrieval hash, and explicit WTI membership.
- [x] R2: PASS. Fixed endpoints, excluded interval, return, direction,
  attempt, hard stop, rollover, and stale exit.
- [x] R3: PASS. Registered `XTIUSD.DWX` D1 plus native V5 execution state only.
- [x] R4: PASS. Deterministic logarithm, calendar, and ATR arithmetic; no
  trained model, prohibited signal indicator, external feed, grid, or
  martingale.
- [x] Dedup: no exact identity; fuzzy and closest mechanic neighbors manually
  resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, endpoint reconstruction, skipped
  interval validation, delayed trend sign, spread/quote/ATR/stop checks, and
  one fixed-risk order.
- trade_management: malformed-state repair, prior-month exit, and stale exit
  before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a
manual backtest; live, demo, shadow, optimization, or stress setfile;
AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio admission;
portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-11 | initial source-bounded WTI skip-one-month trend card | G0 | APPROVED |
| v1-q01 | 2026-08-11 | deterministic V5 build, strict compile, target validation, skipped-month reference vectors, and P1 artifact validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-11 | APPROVED | `decisions/2026-08-11_qm5_20284_wti_skip1_trend_g0.md` |
| Q01 Build Validation | 2026-08-11 | PASS | `D:/QM/reports/compile/20260811_213056/summary.csv`; `D:/QM/reports/framework/21/build_check_20260811_213037.json`; `D:/QM/reports/pipeline/QM5_20284/P1/P1_QM5_20284_result.json` |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |
