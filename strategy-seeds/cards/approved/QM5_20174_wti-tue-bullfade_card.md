---
card_schema_version: 2
ea_id: QM5_20173
slug: wti-mon-bullfade
type: strategy
strategy_id: QUAY-MOP-WTI-MONBULL-2026_S01
variant_id: QUAY-MOP-WTI-MONBULL-2026_S01
source_id: QUAY-MOP-WTI-MONBULL-2026
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20173_wti-mon-bullfade_card.md
execution_contract_status: DRAFT
created: 2026-07-26
created_by: Research+Development
last_updated: 2026-07-26
source_authors: "H. A. Quayyum, M. A. M. Khan, S. M. Ali; Tobias J. Moskowitz, Yao Hua Ooi, Lasse Heje Pedersen"
strategy_mechanic: monday-wti-short-only-when-completed-252d-return-is-positive
source_citation: "Quayyum, Khan, and Ali (2020), Seasonality in crude oil returns, Soft Computing 24; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104."
source_citations:
  - type: peer_reviewed_paper
    citation: "Quayyum, H. A., Khan, M. A. M., and Ali, S. M. (2020). Seasonality in crude oil returns. Soft Computing 24, 7857-7873."
    location: "DOI https://doi.org/10.1007/s00500-019-04329-0; governed packet strategy-seeds/sources/QUAY-WTI-DOW-2019/source.md"
    quality_tier: A
    role: monday_direction
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; governed packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: directional_state
sources:
  - "[[sources/QUAY-MOP-WTI-MONBULL-2026]]"
concepts:
  - "[[concepts/wti-day-of-week-seasonality]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/weekday-trend-interaction]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [day-of-week-seasonality, time-series-momentum, weekday-regime-gate, short-only, weekly-entry, next-bar-exit, atr-hard-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 12-30 completed Monday-session WTI packages/year when the completed 252-D1 return is strictly positive; Q02 must prove or retire the density."
expected_trades_per_year_per_symbol: 20
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: BLOCKED_FACTORY_OFF
review_focus: "Falsify whether the load-bearing conjunction of WTI Monday weakness and a positive completed 252-D1 trend clears density and costs while adding direct crude-oil exposure."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency, friday_close, risk_mode_dual, enhancement_doctrine, cfd_futures_basis, restart_attempt_state, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 PASS two peer-reviewed governed source lineages; R2 PASS locked genuine-Monday WTI short gated by strictly positive completed 252-D1 return, frozen ATR stop, next-D1 flatten, stale repair, and restart-safe consumed attempt; R3 PASS registered XTIUSD.DWX D1; R4 PASS deterministic native MT5 data only with no ML, banned indicator, external feed, grid, martingale, scale-in, or pyramiding. Deterministic dedup CLEAN across 4,206 registry rows and 376 cards plus manual parent/neighbor resolution."
---

# QM5_20173 WTI Monday Positive-Trend Counterfade Short

## Hypothesis

WTI has source-documented weak Monday returns, while broad futures evidence
supports using an instrument's own completed 12-month return sign as a slow
regime state. Taking the WTI Monday short only when the completed
252-D1 return is strictly positive may isolate weeks when the structural
weekday short and slow weekday weakness opposes the slow trend.

The candidate supplies direct crude-oil exposure whose calendar and
information clock differ from the certified XAU, SP500, NDX, and XNG book.
This is a falsifiable interaction hypothesis, not a profitability,
decorrelation, certification, or portfolio-admission claim.

## Source Traceability

The approved composite packet
`strategy-seeds/sources/QUAY-MOP-WTI-MONBULL-2026/source.md` preserves the
two completely read governed parent lineages.

Quayyum, Khan, and Ali supply the weak WTI Monday direction. Moskowitz, Ooi,
and Pedersen supply the instrument-own completed 12-month return-sign state.
Neither paper tests their conjunction, a continuous Darwinex CFD,
Friday-close-to-Monday-open attachment, an ATR stop, or QM portfolio
behavior. Those are explicit QM hypotheses.

No external source is read at runtime. The EA uses only registered
`XTIUSD.DWX` D1 OHLC, ATR, executable quotes, spread, broker calendar,
positions, deal history, and V5 framework state.

## Source-Defined Rules

- Quayyum et al. provide peer-reviewed structural lineage for weak WTI
  Monday returns.
- Moskowitz, Ooi, and Pedersen define the slow regime state from the sign
  of an instrument's own completed trailing return, with 12 months as the
  canonical horizon.
- Neither source defines the continuous-CFD attachment point, ATR stop,
  spread ceiling, attempt persistence, or QuantMechanica risk mode.

## QM Interpretations

- `XTIUSD.DWX` is a continuous-CFD carrier, not a matched futures series.
- A genuine Monday boundary requires the current D1 bar to be Monday and the
  immediately prior completed D1 bar to be Friday. A Monday holiday produces
  no shifted Tuesday trade.
- Entry uses the first executable quote observed within five minutes of the
  Monday D1 bar open. The Friday-close to Monday-open return is not captured.
- `Close[1] / Close[253]`, a strict positive sign, `ATR(20) * 3.0`, the
  1,500-point spread cap, and one consumed attempt per week are fixed,
  pre-result execution choices rather than source claims.

## Non-Duplicate Decision

The deterministic pre-allocation check scanned 4,206 EA-registry rows and 376
research cards and returned `CLEAN` for slug `wti-mon-bullfade`, strategy ID
`QUAY-MOP-WTI-MONBULL-2026_S01`, and mechanic
`Monday WTI short only when completed 252-D1 return is positive`.

Manual semantic review resolved the closest systems:

- `QM5_12596_wti-mon-fade` is an unconditional Monday short and never reads
  the slow WTI trend.
- `QM5_12603_wti-tsmom12m` is a year-round symmetric monthly trend package
  without a weekday gate.
- `QM5_12750` and `QM5_12779` condition Monday trades on the observed opening
  gap and target gap fill; this card never reads or targets that gap.
- `QM5_20016_xti-xng-mon-rv` is a two-leg fixed-direction XTI/XNG Monday
  basket; this card is a single-symbol, trend-conditioned WTI package.
- `QM5_20029_wti-monfri-daily` rotates an unconditional Monday short and
  Friday long; this card has no Friday entry.
- `QM5_20141_wti-sumtrend` is a July-November weekly seasonal short rather
  than a Monday-session effect.
- `QM5_20145_wti-fri-trend` buys positive-trend Fridays; this card shorts
  positive-trend Mondays.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The genuine Monday boundary and positive completed 252-D1 sign are jointly
load-bearing. Removing either component recreates an already-built parent, so
neither may be ablated from the baseline.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; allocated magic `201730000`.
- Decision clock: first observed tick within five minutes of a genuine Monday
  D1 bar immediately following a Friday D1 bar.
- Direction: short-only, and only while completed 252-D1 log return is
  strictly positive.
- Ordinary lifecycle: close on the first new non-Monday D1 bar.
- Expected cadence: approximately 12-30 completed packages/year; Q02 must
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
2. Evaluate entry only when the current D1 bar is broker-calendar Monday and
   the immediately prior completed D1 bar is Friday.
3. Require the first observed tick to occur within five minutes of the
   current Monday D1 bar open. A late attachment consumes no attempt and does
   not enter.
4. Derive a stable Monday-anchored broker week key. Persist that key as
   consumed before history, signal, spread, quote, news, stop, or order gates.
   A rejection, restart, stop, or blocked gate cannot retry that week.
5. Reject when an entry deal or EA-owned position already exists for the
   current broker week.
6. Read completed D1 closes at shifts 1 and 253 and compute
   `ln(Close[1] / Close[253])`.
7. Permit one SELL only when that completed 252-D1 log return is strictly
   positive. A negative return, exact zero, insufficient history, or invalid
   arithmetic remains flat for the consumed week.
8. Require a non-negative spread no greater than 1,500 points, a valid
   executable SELL price, and completed D1 `ATR(20)`.
9. Attach one frozen hard stop `3.0 * ATR(20)` above the executable entry,
   normalized through V5 stop rules. There is no take-profit.
10. Open at most one position for magic `201730000`; no pending order,
    same-week retry, second entry, or scale-in is authorized.

## 5. Exit Rules

1. Close the Monday package on the first new D1 bar whose broker weekday is
   not Monday.
2. Close immediately if an unexpected long position exists for the magic.
3. Close after two elapsed calendar days as a stale-position guard.
4. Framework Friday close at broker hour 21 remains enabled as a fail-safe,
   although the ordinary Tuesday-boundary exit should make it unreachable.
5. The frozen broker hard stop and framework kill switch remain authoritative.
6. There is no profit target, signal-reversal exit, trailing stop, break-even
   move, partial close, or discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed for the wrong symbol, timeframe, EA ID, slot, or unlocked input.
- Fail closed for a non-Monday current D1 bar, a prior bar that is not Friday,
  attachment beyond five minutes, invalid week key, missing completed D1
  history, non-positive close, invalid logarithm, non-positive trend state,
  invalid ATR, negative/excess spread, invalid executable quote, or invalid
  normalized stop.
- Lock the news temporal and compliance axes OFF for the Q02 native-price
  baseline. Lifecycle exits are never delayed by entry-only news logic.
- Require `qm_friday_close_enabled=true` and broker close hour 21.
- Runtime may not read a futures curve, contract chain, inventory, WPSR, OPEC,
  COT, volume, open interest, options, CSV, API, analyst forecast, external
  calendar, discretionary input, or trained output.

## 7. Trade Management Rules

- One position for magic `201730000` and one consumed decision per broker
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
| `strategy_entry_grace_minutes` | 5 | [5] | maximum Monday-bar attachment delay |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 2 | [2] | next-D1 stale repair |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

There is no baseline parameter sweep. The Monday gate and positive 252-D1 sign
are jointly load-bearing.

## Framework Execution Overrides

- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Friday close: enabled at broker hour 21.
- Framework kill switch and broker hard stop: authoritative.
- Forced session flatten: first non-Monday D1 bar.

## Exit Precedence

1. Framework kill switch and the server-side hard stop.
2. First non-Monday D1 boundary or unexpected-long cleanup.
3. Two-calendar-day stale close.
4. Framework Friday close fail-safe.
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

Quayyum, Khan, and Ali report crude-oil day-of-week seasonality including weak
WTI Mondays. Moskowitz, Ooi, and Pedersen report time-series momentum across
futures. Neither claims that this interaction, continuous-CFD carrier,
attachment rule, risk controls, or portfolio objective is profitable.

No source return, hit rate, profit factor, drawdown, trade count, or
correlation estimate is imported as a QM expectation.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-order prior only.
- `expected_dd_pct: 25.0` reflects WTI gaps, short squeezes, CFD roll/basis,
  financing, source-sample decay, and conditional-trend sparsity.
- Expected frequency is approximately 20 completed packages/year, with a
  plausible 12-30 range. Q02 must measure it.
- Risk class is high.
- Gridding, scalping, pyramiding, and ML are false.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages/year on average.
- Fail on any long entry, entry outside a genuine Monday/Friday boundary,
  entry without strictly positive completed 252-D1 return, same-week retry,
  hold beyond two days, missing next-D1 flatten, missing hard stop, invalid
  risk mode, nondeterminism, or any governed PF/DD failure.
- Do not rescue failure by changing the weekday, trend horizon, sign
  threshold, direction, entry clock, stop, hold, spread cap, retry policy, or
  risk mode after results.
- Later gates must reject the sleeve if its realized return stream does not
  diversify the certified book. No correlation waiver is authorized.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses executable distance to the frozen
ATR stop. WTI weekend gaps, short squeezes, continuous-CFD roll/basis,
financing, source-sample decay, conditional density, and the futures-to-CFD
translation are first-order kill risks.

## Strategy Allowability Check

- [x] R1: two peer-reviewed named-author journal lineages with durable,
  completely reviewed repository packets.
- [x] R2: fixed weekday boundary, completed return sign, weekly attempt state,
  short-only direction, hard stop, next-D1 exit, and stale repair.
- [x] R3: registered `XTIUSD.DWX` D1 history route and native V5 data only.
- [x] R4: deterministic calendar/OHLC/logarithm/ATR arithmetic; no ML, banned
  indicator, external signal, grid, martingale, scale-in, or pyramiding.
- [x] Dedup: deterministic CLEAN plus manual parent/neighbor differentiation.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked-input, genuine-Monday, grace,
  history, arithmetic, trend, spread, quote, stop, consumed-week, and
  owned-position guards.
- trade_entry: genuine Monday boundary, positive completed 252-D1 state, one
  SELL, and frozen ATR stop.
- trade_management: first non-Monday, wrong-side, and two-day stale closes
  before entry-only gates.
- trade_close: position close, framework Friday fail-safe, broker hard stop,
  and kill switch.

## Falsification And Requalification

Any change to the weekday boundary, trend horizon, sign rule, entry direction,
attachment grace, stop, stale limit, spread cap, retry state, symbol,
timeframe, or risk mode requires a new binary and full pipeline
requalification. Ambiguous history or state must fail closed.

## Safety Boundary

This approval covers one card, deterministic registries, one EA build, strict
compile, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does
not authorize a manual backtest, live setfile, AutoTrading, `T_Live`, deploy or
T_Live manifest change, portfolio admission, portfolio-gate change, portfolio
KPI claim, or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-26 | initial source-backed WTI Monday/trend interaction card | G0 | APPROVED |
| v1 | 2026-07-26 | strict compile and targeted build validation complete | Q01 | PASS |
| v1 | 2026-07-26 | targeted paced enqueue refused by canonical FACTORY_OFF safety flag | Q02 | BLOCKED_FACTORY_OFF |
