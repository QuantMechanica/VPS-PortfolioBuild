---
card_schema_version: 2
ea_id: QM5_20145
slug: wti-fri-trend
type: strategy
strategy_id: GORSKA-MOP-WTI-FRITREND-2026_S01
variant_id: GORSKA-MOP-WTI-FRITREND-2026_S01
source_id: GORSKA-MOP-WTI-FRITREND-2026
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20145_wti-fri-trend_card.md
execution_contract_status: DRAFT
created: 2026-07-25
created_by: Research+Development
last_updated: 2026-07-25
source_authors: "Anna Gorska; Malgorzata Krawiec; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: friday-d1-wti-long-only-when-completed-252d-return-is-positive
source_citation: "Gorska and Krawiec (2015), Calendar Effects in the Market of Crude Oil; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum."
source_citations:
  - type: academic_journal_paper
    citation: "Gorska, A. and Krawiec, M. (2015). Calendar Effects in the Market of Crude Oil. Quantitative Methods in Economics 16(4)."
    location: "WTI weekday-return analysis; https://ageconsearch.umn.edu/record/230857/files/2015_4_7.pdf"
    quality_tier: B
    role: friday_calendar_state
  - type: peer_reviewed_journal_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "Own-past-return-sign momentum across futures; DOI https://doi.org/10.1016/j.jfineco.2011.11.003"
    quality_tier: A
    role: directional_state
sources:
  - "[[sources/GORSKA-MOP-WTI-FRITREND-2026]]"
concepts:
  - "[[concepts/crude-oil-day-of-week-seasonality]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/calendar-trend-interaction]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, time-series-momentum, agreement-filter, friday-session, long-only, atr-hard-stop, friday-close-flatten, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 15-35 Friday-session WTI packages/year when the completed 252-D1 return is strictly positive; Q02 must prove or retire the realized density."
expected_trades_per_year_per_symbol: 24
expected_pf: 1.01
expected_dd_pct: 20.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: PENDING
q02_status: PENDING
review_focus: "Falsify whether the WTI Friday premium survives only in positive slow-trend states after the omitted overnight gap, CFD/futures basis, costs, and post-source decay."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency, friday_close, risk_mode_dual, restart_safe_attempt, omitted_overnight_gap, cfd_futures_basis, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 PASS two governed academic source lineages; R2 PASS locked genuine-Friday WTI long gated by a strictly positive completed 252-D1 return, first-five-minute entry, frozen ATR stop, Friday close, stale repair, and restart-safe consumed attempt; R3 PASS registered XTIUSD.DWX D1; R4 PASS deterministic native MT5 data only with no ML, banned indicator, external feed, grid, martingale, scale-in, or pyramiding. Deterministic dedup CLEAN across 4,202 registry rows and 376 cards plus manual parent/neighbor resolution."
---

# QM5_20145 WTI Friday Premium / Slow-Trend Agreement

## Hypothesis

WTI has a source-documented positive Friday return effect, while
time-series-momentum research identifies an instrument's own completed
12-month return sign as a slow directional state. Taking the WTI Friday long
only when the completed 252-D1 return is strictly positive may isolate weeks
when the structural calendar premium and the slow crude-oil trend agree.

The candidate supplies direct crude-oil exposure whose calendar and
information clock differ from the certified XAU, SP500, NDX, and XNG book.
This is a falsifiable interaction hypothesis, not a profitability,
decorrelation, certification, or portfolio-admission claim.

## Source Traceability

The approved composite packet
`strategy-seeds/sources/GORSKA-MOP-WTI-FRITREND-2026/source.md` preserves the
two completely read parent lineages.

Gorska and Krawiec supply the WTI Friday calendar direction. Moskowitz, Ooi,
and Pedersen supply the instrument-own completed 12-month return-sign state.
Neither paper tests their conjunction, a continuous Darwinex CFD,
Friday-open execution, a fixed-risk ATR stop, or QM portfolio behavior. Those
are explicit QM hypotheses.

No external source is read at runtime. The EA uses registered `XTIUSD.DWX` D1
OHLC, ATR, executable quotes, spread, broker calendar, positions, deal
history, and V5 framework state only.

## Source-Defined Rules

- Gorska and Krawiec report Friday as the strongest positive average WTI
  weekday in their studied sample.
- Moskowitz, Ooi, and Pedersen define a slow directional state from the sign
  of an instrument's own completed trailing return, with 12 months as the
  canonical horizon.
- Both source states use completed historical observations.
- Neither source defines this interaction's CFD carrier, entry grace, ATR
  stop, consumed-attempt state, spread ceiling, or V5 risk budget.

## QM Interpretations

- `XTIUSD.DWX` is a continuous CFD, not the paper's WTI futures return series.
- The source calendar return is close-to-close. Entry on the first Friday D1
  tick omits the Thursday-close to Friday-open gap. A five-minute grace limit
  bounds late attachment but cannot restore that omitted component.
- `ln(Close[1] / Close[253])` is the strictly completed 252-D1 trend state.
- The framework Friday close at broker hour 21 defines the ordinary package
  exit.
- `ATR(20) * 3.0`, the 1,500-point spread cap, and one consumed attempt per
  broker week are fixed pre-result execution choices rather than source
  claims.

## Non-Duplicate Decision

The deterministic pre-allocation check scanned 4,202 EA-registry rows and 376
research cards and returned `CLEAN` for slug `wti-fri-trend`, strategy ID
`GORSKA-MOP-WTI-FRITREND-2026_S01`, and the full mechanic fingerprint.

Manual semantic review resolved the closest systems:

- `QM5_12597_wti-fri-prem` buys every eligible Friday and never reads trend.
- `QM5_12603_wti-tsmom12m` trades the 252-D1 sign symmetrically on a monthly
  clock and has no Friday gate.
- `QM5_20141_wti-sumtrend` sells at the start of July-November weeks when the
  252-D1 sign is negative; it does not trade the Friday premium.
- `QM5_20135_wti-winter-trend` is monthly, November-May, and symmetric.
- `QM5_20117_wti-fri-lagrev` sells Friday after a completed Thursday surge of
  at least 4.5%; it is a one-day tail reversal.
- `QM5_12753_wti-thu-pb-fri-bounce` buys after a one-day Thursday pullback and
  has no slow trend state.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The Friday calendar gate and positive completed 252-D1 sign are jointly
load-bearing. Removing either component recreates an already-built parent, so
neither may be ablated from the baseline.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; allocated magic `201450000`.
- Decision clock: first observed tick of each genuine broker-calendar Friday
  D1 bar, within five minutes of that bar's open.
- Direction: long only, and only while the completed 252-D1 log return is
  strictly positive.
- Ordinary lifecycle: framework Friday close at broker hour 21.
- Expected cadence: approximately 15-35 completed packages/year; Q02 must
  prove the binding average density after warm-up.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Rules

The rules below are the complete authorized baseline. A different weekday,
return horizon, sign threshold, direction, entry clock, stop, hold, spread
cap, retry policy, or risk mode requires a new card and binary.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX`, D1, magic slot 0, and every baseline input
   locked to the values below.
2. Evaluate entry only on a new broker-calendar Friday D1 bar.
3. Require the previous completed D1 bar to be Thursday. A holiday-broken
   sequence remains flat.
4. Require the first observed tick to be no more than five minutes after the
   current Friday D1 bar open. A late attachment remains flat.
5. Derive a stable Monday-anchored broker week key. Persist that key as
   consumed before history, signal, spread, quote, news, stop, or order gates.
   A rejection, restart, stop, or blocked gate cannot retry that week.
6. Reject when an entry deal or EA-owned position already exists for the
   current broker week.
7. Read completed D1 closes at shifts 1 and 253 and compute
   `ln(Close[1] / Close[253])`.
8. Permit one BUY only when that completed 252-D1 log return is strictly
   positive. A negative return, exact zero, insufficient history, or invalid
   arithmetic remains flat for the consumed week.
9. Require a non-negative spread no greater than 1,500 points, a valid
   executable BUY price, and completed D1 `ATR(20)`.
10. Attach one frozen hard stop `3.0 * ATR(20)` below the executable entry,
    normalized through V5 stop rules. There is no take-profit.
11. Open at most one position for magic `201450000`; no pending order,
    same-week retry, second entry, or scale-in is authorized.

## 5. Exit Rules

1. Framework Friday close at broker hour 21 is the ordinary package exit.
2. If Friday close did not complete, close on the first observed bar or tick
   whose broker weekday is not Friday.
3. Close immediately if an unexpected short position exists for the magic.
4. Close after three elapsed calendar days as a final stale-position guard.
5. The frozen broker hard stop and framework kill switch remain
   authoritative.
6. There is no profit target, signal-reversal exit, trailing stop, break-even
   move, partial close, or discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed for the wrong symbol, timeframe, EA ID, slot, or unlocked input.
- Fail closed for an invalid week key, non-Friday current bar,
  holiday-broken prior weekday, late attachment, missing completed D1 history,
  non-positive close, invalid logarithm, non-positive trend state, invalid ATR,
  negative/excess spread, invalid executable quote, or invalid normalized
  stop.
- Lock the news temporal and compliance axes OFF for the Q02 native-price
  baseline. Lifecycle exits are never delayed by entry-only news logic.
- Require `qm_friday_close_enabled=true` and broker close hour 21.
- Runtime may not read a futures curve, contract chain, inventory, WPSR, OPEC,
  COT, volume, open interest, options, CSV, API, analyst forecast, external
  calendar, discretionary input, or trained output.

## 7. Trade Management Rules

- One position for magic `201450000` and one consumed decision per broker
  week.
- Maintain the original server-side stop; never trail or move it.
- Restart recovery uses a terminal-persistent consumed-week marker plus
  position/deal history. A future-dated stale marker is cleared at
  initialization for deterministic historical reruns.
- Lifecycle exits run before all entry-only gates.
- No profit target, scale-in, pyramid, grid, martingale, partial close,
  randomness, adaptive fit, or discretionary override.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 252 | [252] | completed own-return horizon |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] | strict positive sign; no deadband |
| `strategy_entry_grace_minutes` | 5 | [5] | maximum Friday-bar attachment delay |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 3 | [3] | missed-Friday stale repair |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

There is no baseline parameter sweep. The Friday gate and positive 252-D1
sign are jointly load-bearing.

## Framework Execution Overrides

- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Friday close: enabled at broker hour 21.
- Framework kill switch and broker hard stop: authoritative.
- Forced session flatten: none beyond the Friday framework control.

## Exit Precedence

1. Framework kill switch and the server-side hard stop.
2. Framework Friday close at broker hour 21.
3. Non-Friday or unexpected-short cleanup.
4. Three-calendar-day stale close.
5. No discretionary or signal-reversal exit.

## Runtime Data Dependencies

- Exact chart and signal route: `XTIUSD.DWX`, D1.
- Native tester data: completed D1 closes, ATR, current executable quote,
  spread, symbol metadata, broker calendar, positions, deals, and terminal
  persistent state.
- No external calendar, futures contract chain, finite CSV dataset, API, or
  cross-symbol history.
- Tester account currency and fixed-risk lot sizing remain framework-owned.

## Author Claims

Gorska and Krawiec report a positive Friday average in their WTI sample.
Moskowitz, Ooi, and Pedersen report time-series momentum across futures.
Neither claims that this interaction, continuous CFD carrier, Friday-open
translation, risk controls, or portfolio objective is profitable.

No source return, hit rate, profit factor, drawdown, trade count, or
correlation estimate is imported as a QM expectation.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-order prior only.
- `expected_dd_pct: 20.0` reflects WTI gaps, the omitted overnight component,
  CFD roll/basis, Friday execution, source-sample decay, and trend-state
  sparsity.
- Expected frequency is approximately 24 completed packages/year, with a
  plausible 15-35 range. Q02 must measure it.
- Risk class is high.
- Gridding, scalping, pyramiding, and ML are false.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages/year on average.
- Fail on any short entry, non-Friday entry, entry without a strictly positive
  completed 252-D1 return, late entry, same-week retry, weekend hold, hold
  beyond three days, missing Friday-close behavior, missing hard stop, invalid
  risk mode, nondeterminism, or any governed PF/DD failure.
- Do not rescue failure by changing the weekday, trend horizon, sign
  threshold, direction, entry clock, stop, hold, spread cap, retry policy, or
  risk mode after results.
- Later gates must reject the sleeve if its realized return stream does not
  diversify the certified book. No correlation waiver is authorized.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses executable distance to the frozen
ATR stop. WTI gaps, Friday execution, continuous-CFD roll/basis, financing,
the omitted close-to-open return, positive-trend clustering, and source-sample
decay are first-order kill risks.

## Strategy Allowability Check

- [x] R1: two named-author academic journal lineages with durable, completely
  reviewed repository packets.
- [x] R2: fixed Friday gate, completed return sign, weekly attempt state,
  long-only direction, hard stop, Friday close, and stale repair.
- [x] R3: registered `XTIUSD.DWX` D1 history route and native V5 data only.
- [x] R4: deterministic calendar/OHLC/logarithm/ATR arithmetic; no ML, banned
  indicator, external signal, grid, martingale, scale-in, or pyramiding.
- [x] Dedup: deterministic CLEAN plus manual parent/neighbor differentiation.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked-input, Friday/prior-weekday, grace,
  history, arithmetic, trend, spread, quote, stop, consumed-week, and
  owned-position guards.
- trade_entry: genuine Friday D1 bar, positive completed 252-D1 state, one
  BUY, and frozen ATR stop.
- trade_management: non-Friday, wrong-side, and three-day stale closes before
  entry-only gates.
- trade_close: framework Friday close, position close, broker hard stop, and
  kill switch.

## Falsification And Requalification

Any change to the weekday, trend horizon, sign rule, entry grace, stop, stale
limit, spread cap, retry state, symbol, timeframe, or risk mode requires a new
binary and full pipeline requalification. Ambiguous history or state must fail
closed.

## Safety Boundary

This approval covers one card, deterministic registries, one EA build, strict
compile, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does
not authorize a manual backtest, live setfile, AutoTrading, `T_Live`, deploy
or T_Live manifest change, portfolio admission, portfolio-gate change,
portfolio KPI claim, or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-25 | initial source-backed WTI Friday/trend interaction card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-25 | APPROVED | this card |
| Q01 Build Validation | 2026-07-25 | PENDING | — |
| Q02 Baseline Screening | 2026-07-25 | PENDING | — |
