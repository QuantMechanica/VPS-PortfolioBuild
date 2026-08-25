---
card_schema_version: 2
type: strategy
strategy_id: MOP-KOENKER-BASSETT-WTI-LAD-TREND-2026_S01
variant_id: MOP-KOENKER-BASSETT-WTI-LAD-TREND-2026_S01
source_id: MOP-KOENKER-BASSETT-WTI-LAD-2026
ea_id: QM5_41159
slug: wti-lad-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41159_wti-lad-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-25
created_by: Research+Development
last_updated: 2026-08-25
g0_status: APPROVED
g0_decision: decisions/2026-08-25_qm5_41159_wti_monthly_lad_trend_g0.md
source_approval: decisions/2026-08-25_wti_monthly_lad_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Roger Koenker; Gilbert Bassett Jr.; Karsten Schweikert"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Roger Koenker; Gilbert Bassett Jr.; Karsten Schweikert"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Schweikert (2018), Are gold and silver cointegrated? New evidence from quantile cointegrating regressions, Journal of Banking and Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_price_direction_monthly_cadence_and_wti_membership
  - type: peer_reviewed_statistical_method_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking and Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete 32-page author-preprint evidence strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md"
    quality_tier: A
    role: koenker_bassett_check_loss_and_exact_pairwise_breakpoint_lineage_only
  - type: governed_method_precedent
    citation: "QuantMechanica bounded thirteen-completed-month WTI log-price slope and lifecycle mechanization."
    location: "strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md"
    quality_tier: internal_governed
    role: endpoint_calendar_coordinate_risk_and_lifecycle_only
strategy_mechanic: monthly-wti-thirteen-completed-month-end-log-price-exact-least-absolute-deviation-median-regression-slope-sign-trend
sources:
  - "[[sources/MOP-KOENKER-BASSETT-WTI-LAD-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/least-absolute-deviation-trend]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-price]]"
  - "[[indicators/median-regression-slope]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, least-absolute-deviation, median-regression, robust-slope, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 411590000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed WTI positions per full post-warm-up year after thirteen completed month ends; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ESTIMATOR_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a direct WTI monthly robust trend outside the certified XAU/SP500/NDX/XNG book. Verify thirteen consecutive completed month ends, chronological log prices, all 78 pairwise breakpoint slopes, median residual intercepts, chronological absolute-loss sums, fixed 1e-12 equality guard, median minimizer, strict direction, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, first_tradable_month_bar, thirteen_consecutive_completed_months, latest_close_per_month, chronological_log_prices, exact_78_pairwise_candidates, median_residual_intercept, absolute_loss_objective, chronological_loss_sum, fixed_loss_equality_guard, median_minimizer, strict_trend_sides, monthly_attempt_state, fixed_risk, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-25 and decisions/2026-08-25_qm5_41159_wti_monthly_lad_trend_g0.md: R1 PASS with explicit estimator-translation risk using complete-read peer-reviewed WTI momentum and quantile-regression research; R2 PASS locks endpoints, 78 breakpoint slopes, median intercept, absolute objective, tie convention, direction, attempt, risk, stop, and repair; R3 PASS registered native WTI D1 with continuous-CFD basis risk; R4 PASS deterministic native arithmetic only. Canonical dedup is clean across 4,658 registry rows, 1,311 cards, and 45 Wiki nodes, while a fixed sign-divergence vector proves functional non-equivalence to OLS, endpoint, Theil-Sen, and repeated-median WTI trend."
---

# QM5_41159 WTI Thirteen-Month Least-Absolute-Deviation Trend

## Hypothesis

WTI can sustain slow directional regimes while production, investment,
inventory, transport, refining, hedging, and demand adjust. A single endpoint
return or least-squares line can be dominated by one oil shock. This card asks
for the straight time trend that minimizes total absolute vertical error over
thirteen completed month-end log prices, testing whether a broad WTI path has
a robust direction without fitting a model to PnL or scaling risk by signal
magnitude.

The direct crude-oil carrier is economically different from the certified
XAU, SP500, NDX, and XNG book. That is a diversification hypothesis, not proof
of low correlation, profitability, or portfolio suitability. Q02 owns density
and baseline economics; unchanged downstream gates, including Q09, own
robustness and realized overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/MOP-KOENKER-BASSETT-WTI-LAD-2026/source.md`. Its
trading parent records a complete read of Moskowitz, Ooi, and Pedersen (2012),
a peer-reviewed *Journal of Financial Economics* paper documenting monthly
own-return continuation over the first twelve lags and including NYMEX WTI in
its commodity-futures universe.

The method parent records a complete read of Schweikert (2018), a peer-
reviewed *Journal of Banking & Finance* paper and author preprint that uses
Koenker-Bassett check-loss quantile regression. At the median quantile,
symmetric check loss has the same minimizer as total absolute error. The
source packet preserves Schweikert's adverse evidence: it does not provide an
ex-ante profitable trading rule and rejects important specifications.

Neither source tests the locked thirteen-point WTI LAD slope. The endpoint
count, integer time coordinate, exhaustive breakpoint solver, median
intercept, equality guard, continuous CFD, broker-month reconstruction,
fixed-dollar sizing, ATR hard stop, spread cap, attempt ledger, and lifecycle
are transparent QM mechanizations. No source return, alpha, Sharpe ratio,
drawdown, WTI-only result, trade count, cost, CFD equivalence, estimator
superiority, or correlation statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,658 EA-registry rows, 1,311 cards, and 45
Strategy Wiki nodes with no exact or fuzzy match. Manual review resolves the
mechanical neighbors:

- `QM5_20271_wti-theilsen-tr` globally ranks 78 pairwise slopes. It does not
  profile an intercept or minimize an absolute-residual objective.
- `QM5_41158_wti-repmedian-tr` takes thirteen pivot-specific slope medians and
  one outer median. It also has no fitted intercept or loss objective.
- `QM5_20261_wti-lr-trend` uses squared-error OLS plus an `R^2` gate.
- On fixed log-price levels
  `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, LAD is `-0.002`
  while Theil-Sen, repeated median, OLS, and endpoint slope are positive. The
  rules take opposite positions on the same valid state.
- `QM5_13205_xau-xag-qc` fits three 504-observation conditional cross-metal
  regressions and trades a two-leg tail-envelope reversion basket. This card
  fits one thirteen-point time slope and trades one direct WTI trend leg.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG oscillator
  pullback, not a monthly WTI robust slope.

Verdict: `CLEAN_EXACT_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `411590000`.
- Decision clock: first executable D1 tick after a genuine broker-month
  transition, within 180 elapsed minutes of the raw current D1 bar open.
- Formation: thirteen consecutive completed broker-month closes.
- Candidate set: all 78 pairwise residual-order breakpoints.
- Holding clock: next broker-month boundary, with a forty-calendar-day stale
  guard.
- Expected cadence: approximately ten to twelve completed positions per full
  post-warm-up year; retire below five.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and terminal-persistent state only.

## Formula

At the start of month `t`, let `C[0]..C[12]` be completed month-end closes
from months `t-13..t-1`, ordered oldest to newest:

```text
x[i] = i
y[i] = ln(C[i]), i = 0..12

candidates = []
for i = 0..11:
  for j = i+1..12:
    candidates.append((y[j] - y[i]) / (j - i))
require len(candidates) == 78

for each b in candidates:
  residuals = [y[i] - b*x[i] for i=0..12]
  a = ascending(residuals)[6]
  loss[b] = sum(i=0..12, abs(y[i] - a - b*x[i]))

minimum = min(loss[b])
minimizers = [b for b in candidates
              if abs(loss[b] - minimum) <= 1e-12]
lad_slope = ordinary_median(ascending(minimizers))
```

BUY when `lad_slope > 0`; SELL when `lad_slope < 0`. Exact zero or any invalid
state consumes the month flat. The slope magnitude never scales risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to endpoint return, OLS, Theil-Sen, repeated median,
rank score, adjacent-return location, moving average, oscillator, calendar
direction, external series, or prior pipeline result.

## 4. Entry Rules

1. Require exact EA ID `41159`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates. Evaluate only at a genuine
   broker-month transition no later than 180 elapsed minutes after the raw D1
   bar open.
3. Persist the current `yyyymm` as consumed before history, signal, news,
   spread, quote, ATR, sizing, margin, or order checks. A flat, rejected,
   failed, stopped, or blocked outcome cannot retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Reconstruct exactly thirteen completed month-end closes from bounded D1
   history. Require the newest endpoint to be the immediately prior month, no
   more than ten calendar days stale, and every older month consecutive.
6. Keep endpoints oldest to newest; require positive finite closes and
   strictly increasing timestamps. Take exactly thirteen finite natural logs.
7. Enumerate exactly 78 slopes for all `i<j`, in lexicographic pair order.
   Require a positive integer month-index denominator and every slope finite.
8. For each candidate, calculate exactly thirteen finite residuals, sort a
   copy, take index 6 as intercept, and sum exactly thirteen absolute errors
   in chronological observation order. Require a finite nonnegative objective.
9. Find the finite minimum objective; retain every candidate within the
   locked `1e-12` equality guard, require at least one minimizer, sort them,
   and take the ordinary median. Buy for positive and sell for negative;
   exact zero consumes the month flat.
10. Require spread in `[0,1500]` points, an executable quote, completed
    `ATR(20,D1)`, valid point/digit/volume metadata, and valid fixed-risk
    sizing.
11. Open at most one market position with a frozen `3.5*ATR(20,D1)` broker
    hard stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed tick in every new broker
   month before considering replacement risk, even if direction is unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close duplicate, wrong-symbol, wrong-side, wrong-magic, invalid-type, or
   missing-stop exposure owned by this EA.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source-aligned hold spans weekends.
6. No intramonth flip, target, trail, break-even, partial close, scale-in,
   grid, martingale, pyramid, or retry is authorized.

## Risk

- Q02/backtest mode only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from the completed bar at entry.
- Maximum entry spread: 1,500 points.
- One position and one attempt per broker month.
- Signal magnitude, objective magnitude, intercept, and minimizer count never
  alter size.
- No live/demo/shadow/stress/optimization setfile is authorized.
- Both news axes and legacy news mode are OFF; Friday close is OFF.

## 7. Parameters To Test

The Q02 baseline is fully locked, not an optimization surface:

| Parameter | Baseline | Range |
|---|---:|---|
| `strategy_price_points` | 13 | locked |
| `strategy_history_bars_d1` | 800 | locked |
| `strategy_entry_grace_minutes` | 180 | locked |
| `strategy_endpoint_stale_days` | 10 | locked |
| `strategy_loss_tie_tolerance` | 1e-12 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |

No parameter sweep, direction flip, alternate LAD solver, candidate pruning,
fitted slope bound, loss normalization, volatility filter, seasonal filter,
or ensemble is authorized after results.

## 8. Failure Modes And Kill Criteria

Retire or fail the candidate on any of the following:

- fewer than five completed positions in any full post-warm-up Q02 year;
- zero trades, nonpositive governed economics, or a downstream gate failure;
- current-month leakage, missing/duplicate month keys, nonlatest month close,
  stale newest endpoint, nonchronological timestamps, or invalid label offset;
- candidate count other than 78, reversed denominator, nonfinite slope,
  residual count other than 13, wrong median index, nonfinite intercept,
  objective count other than 78, wrong loss order, negative/nonfinite loss,
  changed equality guard, empty minimizer set, wrong median convention, or
  wrong trade side;
- same-month retry, missing hard stop, wrong risk mode, wrong spread ceiling,
  late entry, malformed exposure, or missed month-boundary exit;
- nondeterministic output for identical history and inputs;
- any post-result rescue change to formation, solver, loss, tie convention,
  direction, risk, stop, hold, symbol, or carrier; or
- downstream portfolio-correlation rejection. No waiver is implied.

## 9. Execution And State Contract

- The D1 decision clock supports only raw-current-date labels and a uniformly
  applied raw-plus-one-day label convention; mixed offsets fail closed.
- A month is consumed before all fallible gates. Terminal global state and
  deal history prevent a restart retry.
- The current month contributes no signal close.
- Position repair and month rollover run every tick before new-entry gates.
- Logs expose decision month, label offset, endpoint count/times, candidate
  count, evaluated objective count, minimizer count, minimum loss, LAD
  intercept, LAD slope, direction, and state without logging credentials.

## 10. Portfolio Interaction

This is a direct physical-energy carrier intended to diversify an existing
XAU/SP500/NDX/XNG book. Its one-month robust trend driver is mechanically
different from the incumbent XNG cumulative-RSI2 pullback and from the metal
and index sleeves. Those statements are design facts only. No ex-ante or
realized correlation is claimed, and no portfolio gate, threshold, incumbent,
manifest, or admission state changes under this card. Q09 owns the first
realized overlap verdict; Q11+ remain manual OWNER gates.

## 11. Validation Plan

1. Schema-lint both canonical and approved card copies.
2. Prove all 78 pair slopes, median residual intercepts, 78 objectives,
   equality guard, minimizer median, strict direction, and the fixed sign-
   divergence vector with an independent deterministic reference suite.
3. Validate thirteen consecutive month keys, year rollover, latest-close
   selection, current-month exclusion, staleness, label conventions, grace,
   attempt order, and lifecycle repair.
4. Require strict zero-error/zero-warning compile, build guardrails, exact
   symbol scope, active registry identity, active magic row, and source-fresh
   EX5.
5. Enqueue exactly one `XTIUSD.DWX` D1 Q02 row only if the fresh paced-fleet
   CPU/queue ceiling permits. Enqueue does not launch a manual tester.
6. Retire below the five-per-year floor or on nonpositive governed economics.
7. Preserve all later gate criteria unchanged.

## 12. Framework Alignment

- no_trade: exact EA ID, symbol, timeframe, magic slot, risk, news, Friday,
  stress, and locked strategy-input validation.
- trade_entry: month clock, consume-first attempt, exact completed endpoints,
  logs, 78 candidates, residual medians, absolute objectives, minimizer tie
  set, strict direction, spread/quote/ATR/stop validation, and fixed-risk
  request.
- trade_management: malformed or wrong-side position repair, next-month exit,
  and stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## 13. Safety Boundary

This card authorizes one non-live V5 build and one paced Q02 enqueue after Q01
PASS. It does not authorize a manual backtest, `T_Live`, AutoTrading, deploy
or T_Live manifest, live/demo/shadow/stress/optimization preset, portfolio-
gate change, portfolio admission, threshold change, correlation waiver,
terminal process control, or claim that the strategy is certified.

## Revision History

| Version | Date | Reason | Phase | Verdict |
|---|---|---|---|---|
| v1 | 2026-08-25 | initial source-bounded WTI LAD trend card | G0 | APPROVED |
