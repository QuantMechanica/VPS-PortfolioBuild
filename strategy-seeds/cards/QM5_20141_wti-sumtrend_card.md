---
card_schema_version: 2
ea_id: QM5_20141
slug: wti-sumtrend
type: strategy
strategy_id: EWALD-MOP-WTI-SUMTREND-2026_S01
variant_id: EWALD-MOP-WTI-SUMTREND-2026_S01
source_id: EWALD-MOP-WTI-SUMTREND-2026
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20141_wti-sumtrend_card.md
execution_contract_status: DRAFT
created: 2026-07-25
created_by: Research+Development
last_updated: 2026-07-25
source_authors: "Christian-Oliver Ewald, Erik Haugom, Gudbrand Lien, Stale Stordal, Yuexiang Wu; Tobias J. Moskowitz, Yao Hua Ooi, Lasse Heje Pedersen"
strategy_mechanic: july-november-weekly-short-only-when-completed-252d-wti-return-is-negative
source_citation: "Ewald et al. (2022), Trading time seasonality in commodity futures, Energy Economics 115; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104."
source_citations:
  - type: peer_reviewed_paper
    citation: "Ewald, C.-O., Haugom, E., Lien, G., Stordal, S., and Wu, Y. (2022). Trading time seasonality in commodity futures: An opportunity for arbitrage in the natural gas and crude oil markets? Energy Economics 115, 106324."
    location: "Full paper, especially Section 5.1; DOI https://doi.org/10.1016/j.eneco.2022.106324; open version https://eprints.gla.ac.uk/281581/1/281581.pdf"
    quality_tier: A
    role: seasonal_regime
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "Own-past-return-sign momentum across futures; DOI https://doi.org/10.1016/j.jfineco.2011.11.003"
    quality_tier: A
    role: directional_state
sources:
  - "[[sources/EWALD-MOP-WTI-SUMTREND-2026]]"
concepts:
  - "[[concepts/wti-trading-time-seasonality]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/seasonal-trend-interaction]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [trading-time-seasonality, time-series-momentum, seasonal-regime-gate, short-only, weekly-entry, atr-hard-stop, friday-close-flatten, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 5-14 completed weekly WTI packages/year when July-November overlaps a strictly negative completed 252-D1 return; Q02 must prove or retire the density."
expected_trades_per_year_per_symbol: 9
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
review_focus: "Falsify whether the load-bearing conjunction of the WTI July-November trading-time short and negative completed 252-D1 trend clears density and costs while adding direct crude-oil exposure."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency, friday_close, risk_mode_dual, enhancement_doctrine, cfd_futures_basis, restart_attempt_state, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 PASS two peer-reviewed governed source lineages; R2 PASS locked July-November weekly WTI short gated by strictly negative completed 252-D1 return, frozen ATR stop, Friday close, stale exit, and restart-safe consumed attempt; R3 PASS registered XTIUSD.DWX D1;"
---

# QM5_20141 WTI Summer Trading-Time Trend Short

## Hypothesis

WTI has a source-documented July-to-December trading-time effect in
fixed-maturity futures, while broad futures evidence supports using an
instrument's own completed 12-month return sign as a slow directional state.
Taking the July-November WTI seasonal short only when the completed 252-D1
return is strictly negative may isolate periods when the structural calendar
short and slow trend agree.

The candidate supplies direct crude-oil exposure whose calendar and information
clock differ from the certified XAU, SP500, NDX, and XNG book. This is a
falsifiable interaction hypothesis, not a profitability, decorrelation,
certification, or portfolio-admission claim.

## Source Traceability

The approved composite packet
`strategy-seeds/sources/EWALD-MOP-WTI-SUMTREND-2026/source.md` preserves the
two completely read parent lineages.

Ewald et al. supply the July-to-December WTI trading-time short direction.
Moskowitz, Ooi, and Pedersen supply the instrument-own completed 12-month
return-sign state. Neither paper tests their conjunction, a continuous
Darwinex CFD, weekly fixed-risk tranches, an ATR stop, or QM portfolio
behavior. Those are explicit QM hypotheses.

No external source is read at runtime. The EA uses only registered
`XTIUSD.DWX` D1 OHLC, ATR, executable quotes, spread, broker calendar,
positions, deal history, and V5 framework state.

## Non-Duplicate Decision

The deterministic pre-allocation check scanned 4,198 EA-registry rows and 376
research cards and returned `CLEAN` for slug `wti-sumtrend`, strategy ID
`EWALD-MOP-WTI-SUMTREND-2026_S01`, and mechanic
`July-November weekly short only when completed 252-D1 WTI return is negative`.

Manual semantic review resolved the closest systems:

- `QM5_13107_wti-juldec-short` is the unconditional weekly July-November WTI
  short and never reads trend.
- `QM5_12603_wti-tsmom12m` trades the completed 252-D1 sign symmetrically
  year-round and has no calendar gate.
- `QM5_20135_wti-winter-trend` is monthly, November-May, and symmetric
  long/short; this candidate is weekly, July-November, and short-only.
- `QM5_20093_wti-summer-short` is an unconditional calendar short.
- `QM5_20136_wti-caltrend` estimates prior matching-calendar returns and uses
  a 63-D1 agreement state; it does not use Ewald's fixed trading-time window.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The fixed July-November window and negative completed 252-D1 sign are jointly
load-bearing. Removing either component recreates an already-built parent, so
neither may be ablated from the baseline.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; allocated magic `201410000`.
- Decision clock: first tradable D1 bar of each broker-calendar week.
- Active entry months: July, August, September, October, and November.
- Direction: short-only, and only while completed 252-D1 log return is
  strictly negative.
- Ordinary lifecycle: framework Friday close at broker hour 21.
- Expected cadence: approximately 5-14 completed packages/year; Q02 must prove
  the binding average density after warm-up.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Rules

The rules below are the complete authorized baseline. A different month
window, return horizon, sign threshold, direction, entry clock, stop, hold,
spread cap, retry policy, or risk mode requires a new card and binary.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX`, D1, magic slot 0, and every baseline input
   locked to the values below.
2. Evaluate entry only on the first tradable D1 bar of a new broker-calendar
   week.
3. Require the current broker month to be July through November inclusive.
4. Derive a stable Monday-anchored broker week key. Persist that key as
   consumed before history, signal, spread, quote, news, stop, or order gates.
   A rejection, restart, stop, or blocked gate cannot retry that week.
5. Reject when an entry deal or EA-owned position already exists for the
   current broker week.
6. Read completed D1 closes at shifts 1 and 253 and compute
   `ln(Close[1] / Close[253])`.
7. Permit one SELL only when that completed 252-D1 log return is strictly
   negative. A positive return, exact zero, insufficient history, or invalid
   arithmetic remains flat for the consumed week.
8. Require a non-negative spread no greater than 1,500 points, a valid
   executable SELL price, and completed D1 `ATR(20)`.
9. Attach one frozen hard stop `3.0 * ATR(20)` above the executable entry,
   normalized through V5 stop rules. There is no take-profit.
10. Open at most one position for magic `201410000`; no pending order,
    same-week retry, second entry, or scale-in is authorized.

## 5. Exit Rules

1. Framework Friday close at broker hour 21 is the ordinary package exit.
2. If Friday close did not complete, close an older-week package on the first
   D1 bar of the next broker week before evaluating replacement risk.
3. Close immediately on a D1 management pass outside July-November.
4. Close immediately if an unexpected long position exists for the magic.
5. Close after seven elapsed calendar days as a stale-position guard.
6. The frozen broker hard stop and framework kill switch remain authoritative.
7. There is no profit target, signal-reversal exit, trailing stop, break-even
   move, partial close, or discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed for the wrong symbol, timeframe, EA ID, slot, or unlocked input.
- Fail closed for an invalid week key, missing completed D1 history,
  non-positive close, invalid logarithm, non-negative trend state, invalid ATR,
  negative/excess spread, invalid executable quote, or invalid normalized stop.
- Lock the news temporal and compliance axes OFF for the Q02 native-price
  baseline. Lifecycle exits are never delayed by entry-only news logic.
- Require `qm_friday_close_enabled=true` and broker close hour 21.
- Runtime may not read a futures curve, contract chain, inventory, WPSR, OPEC,
  COT, volume, open interest, options, CSV, API, analyst forecast, external
  calendar, discretionary input, or trained output.

## 7. Trade Management Rules

- One position for magic `201410000` and one consumed decision per broker week.
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
| `strategy_start_month` | 7 | [7] | first Ewald short-window month |
| `strategy_end_month` | 11 | [11] | final entry month before December cover |
| `strategy_momentum_lookback_d1` | 252 | [252] | completed own-return horizon |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] | strict negative sign; no deadband |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 7 | [7] | weekly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

There is no baseline parameter sweep. The season gate and negative 252-D1 sign
are jointly load-bearing.

## Framework Execution Overrides

- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Friday close: enabled at broker hour 21.
- Framework kill switch and broker hard stop: authoritative.
- Forced session flatten: none beyond the Friday framework control.

## Author Claims

Ewald et al. report WTI trading-time seasonality in fixed-maturity futures.
Moskowitz, Ooi, and Pedersen report time-series momentum across futures.
Neither claims that this interaction, continuous CFD carrier, weekly package,
risk controls, or portfolio objective is profitable.

No source return, hit rate, profit factor, drawdown, trade count, or
correlation estimate is imported as a QM expectation.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-order prior only.
- `expected_dd_pct: 25.0` reflects WTI gaps, short-side tail risk, CFD
  roll/basis, financing, and conditional-trend sparsity.
- Expected frequency is approximately nine completed packages/year, with a
  plausible 5-14 range. Q02 must measure it.
- Risk class is high.
- Gridding, scalping, pyramiding, and ML are false.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages/year on average.
- Fail on any long entry, entry outside July-November, entry without strictly
  negative completed 252-D1 return, same-week retry, hold beyond seven days,
  missing Friday-close behavior, missing hard stop, invalid risk mode,
  nondeterminism, or any governed PF/DD failure.
- Do not rescue failure by changing the season, trend horizon, sign threshold,
  direction, entry clock, stop, hold, spread cap, retry policy, or risk mode
  after results.
- Later gates must reject the sleeve if its realized return stream does not
  diversify the certified book. No correlation waiver is authorized.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses executable distance to the frozen
ATR stop. WTI gaps, short squeezes, continuous-CFD roll/basis, financing,
source-sample decay, conditional density, and the futures-to-CFD translation
are first-order kill risks.

## Strategy Allowability Check

- [x] R1: two peer-reviewed named-author journal lineages with durable,
  completely reviewed repository packets.
- [x] R2: fixed month gate, completed return sign, weekly attempt state,
  short-only direction, hard stop, Friday close, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 history route and native V5 data only.
- [x] R4: deterministic calendar/OHLC/logarithm/ATR arithmetic; no ML, banned
  indicator, external signal, grid, martingale, scale-in, or pyramiding.
- [x] Dedup: deterministic CLEAN plus manual parent/neighbor differentiation.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked-input, history, arithmetic, trend,
  spread, quote, stop, consumed-week, and owned-position guards.
- trade_entry: first weekly D1 bar in July-November, negative completed 252-D1
  state, one SELL, and frozen ATR stop.
- trade_management: older-week, outside-window, wrong-side, and seven-day stale
  closes before entry-only gates.
- trade_close: framework Friday close, position close, broker hard stop, and
  kill switch.

## Falsification And Requalification

Any change to the month window, trend horizon, sign rule, weekly boundary,
entry direction, stop, stale limit, spread cap, retry state, symbol, timeframe,
or risk mode requires a new binary and full pipeline requalification.
Ambiguous history or state must fail closed.

## Safety Boundary

This approval request covers one card, deterministic registries, one EA build,
strict compile, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue.
It does not authorize a manual backtest, live setfile, AutoTrading, `T_Live`,
deploy or T_Live manifest change, portfolio admission, portfolio-gate change,
portfolio KPI claim, or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-25 | initial source-backed WTI summer/trend interaction card | G0 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-25 | PENDING | this card |
| Q01 Build Validation | - | NOT RUN | - |
| Q02 Baseline Screening | - | NOT ENQUEUED | - |

