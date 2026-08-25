---
card_schema_version: 2
type: strategy
strategy_id: MOP-SIEGEL-WTI-REPMEDIAN-TREND-2026_S01
variant_id: MOP-SIEGEL-WTI-REPMEDIAN-TREND-2026_S01
source_id: MOP-SIEGEL-WTI-REPMEDIAN-2026
ea_id: QM5_41158
slug: wti-repmedian-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41158_wti-repmedian-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-25
created_by: Research+Development
last_updated: 2026-08-25
g0_status: APPROVED
g0_decision: decisions/2026-08-25_qm5_41158_wti_monthly_repeated_median_trend_g0.md
source_approval: decisions/2026-08-25_wti_monthly_repeated_median_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Andrew F. Siegel"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Andrew F. Siegel"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Siegel (1982), Robust Regression Using Repeated Medians, Biometrika 69(1), 242-244, DOI 10.1093/biomet/69.1.242."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_price_direction_monthly_cadence_and_wti_membership
  - type: peer_reviewed_statistical_method_record
    citation: "Siegel, A. F. (1982). Robust Regression Using Repeated Medians. Biometrika 69(1), 242-244."
    location: "DOI 10.1093/biomet/69.1.242; official Oxford Academic bibliographic and abstract record; bounded lineage strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md"
    quality_tier: A
    role: repeated_median_nested_robust_regression_lineage_only
  - type: governed_method_precedent
    citation: "QuantMechanica bounded thirteen-completed-month WTI slope and lifecycle mechanization."
    location: "strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md"
    quality_tier: internal_governed
    role: endpoint_calendar_slope_orientation_risk_and_lifecycle_only
strategy_mechanic: monthly-wti-thirteen-completed-month-end-log-price-siegel-repeated-median-of-thirteen-pivot-specific-twelve-slope-medians-sign-trend
sources:
  - "[[sources/MOP-SIEGEL-WTI-REPMEDIAN-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/repeated-median-robust-trend]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-price]]"
  - "[[indicators/repeated-median-slope]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, repeated-median, robust-slope, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 411580000
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
review_focus: "Falsify a direct WTI monthly robust trend outside the certified XAU/SP500/NDX/XNG book. Verify thirteen consecutive completed month ends, chronological log prices, thirteen pivot groups, twelve forward-oriented slopes per pivot, inner median indexes 5/6, outer median index 6, strict direction, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, first_tradable_month_bar, thirteen_consecutive_completed_months, latest_close_per_month, chronological_log_prices, pivot_membership, forward_slope_orientation, exact_twelve_slopes_per_pivot, inner_even_median_indexes, exact_thirteen_pivot_medians, outer_odd_median_index, strict_trend_sides, monthly_attempt_state, fixed_risk, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-25 and decisions/2026-08-25_qm5_41158_wti_monthly_repeated_median_trend_g0.md: R1 PASS with explicit estimator-translation risk using complete-read peer-reviewed WTI momentum research and official peer-reviewed repeated-median lineage; R2 PASS locked endpoints, pivots, slope orientation, counts, both median stages, direction, attempt, risk, stop, and repair; R3 PASS registered native WTI D1 with continuous-CFD basis risk; R4 PASS deterministic native arithmetic only. Canonical dedup surfaced the expected Theil-Sen fuzzy neighbor, and a fixed sign-divergence vector proves functional non-equivalence."
---

# QM5_41158 WTI Thirteen-Month Repeated-Median Trend

## Hypothesis

WTI can sustain slow directional regimes while production, investment,
inventory, transport, refining, hedging, and demand adjust. A single endpoint
return or least-squares line can be dominated by one oil shock. A repeated
median gives each month-end pivot its own central forward slope before taking
the central pivot, testing whether broad path direction survives local
extremes without fitting a model or scaling risk by signal magnitude.

The direct crude-oil carrier is economically different from the certified
XAU, SP500, NDX, and XNG book. That is a diversification hypothesis, not proof
of low correlation, profitability, or portfolio suitability. Q02 owns density
and baseline economics; unchanged downstream gates, including Q09, own
robustness and realized overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md`. Its trading
parent records a complete read of Moskowitz, Ooi, and Pedersen (2012), a
peer-reviewed *Journal of Financial Economics* paper documenting monthly
own-return continuation over the first twelve lags and including NYMEX WTI in
its commodity-futures universe.

The official Oxford Academic record for Siegel (1982) supplies repeated-
median robust-regression lineage only. The paywalled paper body was not used.
Neither source tests the locked nested statistic on WTI. The endpoint count,
month-index slope, inner and outer median conventions, Darwinex continuous
CFD, broker-month reconstruction, fixed-dollar sizing, ATR hard stop, spread
cap, attempt ledger, and lifecycle are transparent QM mechanizations. No
source return, alpha, Sharpe ratio, drawdown, WTI-only result, trade count,
cost, CFD equivalence, robustness improvement, or correlation statistic is
imported.

## Non-Duplicate Decision

The canonical checker scanned 4,657 EA-registry rows, 1,309 cards, and 45
Strategy Wiki nodes. Its only fuzzy result was
`QM5_20271_wti-theilsen-tr` at score `0.6153846153846154`. Manual review
resolves the match:

- Theil-Sen pools all 78 unique forward slopes and takes one global median.
  This card groups slopes by each endpoint, takes thirteen separate inner
  medians, and then takes the outer median pivot.
- On fixed log-price levels
  `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, Theil-Sen is
  `+0.00155555555555556` while this repeated median is `-0.0045`; the systems
  take opposite positions on the same valid state.
- OLS plus `R^2`, ordinal rank trend, endpoint momentum, adjacent-return
  median/trim/Winsor/Huber/Hodges-Lehmann, weighted returns, sign votes, and
  path-efficiency rules use different state objects or aggregation.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG oscillator
  pullback, not a monthly WTI robust slope.

Verdict:
`CLEAN_AFTER_THEILSEN_FUZZY_MATCH_AND_SIGN_DIVERGENCE_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `411580000`.
- Decision clock: first executable D1 tick after a genuine broker-month
  transition, within 180 elapsed minutes of the raw current D1 bar open.
- Formation: thirteen consecutive completed broker-month closes and thirteen
  pivot groups of twelve forward-oriented log-price slopes.
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
y[i] = ln(C[i]), i = 0..12

for i = 0..12:
  slopes_i = []
  for j = 0..12, j != i:
    lo = min(i,j)
    hi = max(i,j)
    slopes_i.append((y[hi] - y[lo]) / (hi - lo))
  require len(slopes_i) == 12
  s = ascending(slopes_i)
  pivot_median[i] = (s[5] + s[6]) / 2

m = ascending(pivot_median[0..12])
repeated_median = m[6]
```

BUY when `repeated_median > 0`; SELL when `repeated_median < 0`. Exact zero or
any invalid state consumes the month flat. The statistic's magnitude never
scales risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to a global pairwise-slope median, endpoint return,
adjacent-return statistic, OLS, ordinal score, moving average, oscillator,
calendar direction, external series, or prior pipeline result.

## 4. Entry Rules

1. Require exact EA ID `41158`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates. Evaluate only at a genuine
   broker-month transition no later than 180 elapsed minutes after the raw D1
   bar open.
3. Persist the current `yyyymm` as consumed before history, signal, news,
   spread, quote, ATR, sizing, margin, or order checks. A flat, rejected,
   failed, stopped, or blocked outcome cannot retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Reconstruct exactly thirteen completed month-end closes from bounded D1
   history. Require the newest endpoint to be the immediately prior month,
   no more than ten calendar days stale, and every older month consecutive.
6. Keep endpoints oldest to newest; require positive finite closes and
   strictly increasing timestamps. Take exactly thirteen finite natural logs.
7. For each of thirteen pivots, enumerate exactly twelve slopes to all other
   endpoints. Orient every pair from earlier to later month, divide by the
   positive integer month-index distance, and require every slope finite.
8. Sort each pivot's twelve slopes and average zero-based indexes 5 and 6.
   Require thirteen finite pivot medians, sort them, and take zero-based index
   6. Buy for positive and sell for negative; exact zero consumes the month
   flat.
9. Require spread in `[0,1500]` points, an executable quote, completed
   `ATR(20,D1)`, valid point/digit/volume metadata, and valid fixed-risk sizing.
10. Open at most one market position with a frozen `3.5*ATR(20,D1)` broker
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
   grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, magic slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  malformed or nonconsecutive endpoints, current-month leakage, stale newest
  endpoint, nonpositive/nonfinite close, invalid log, wrong pivot or slope
  count, invalid denominator or median, exact-zero repeated median, excessive
  spread, invalid quote, unavailable ATR, invalid stop, or invalid volume.
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
  position and deal history; tester initialization clears a future/prior-run
  marker so historical runs remain deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, wrong-side, invalid-type,
  wrong-magic, or missing-stop exposure before any new entry logic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_price_points` | 13 | [13] | completed month-end log-price observations |
| `strategy_history_bars_d1` | 800 | [800] | bounded D1 endpoint reconstruction |
| `strategy_entry_grace_minutes` | 180 | [180] | maximum elapsed time after raw new-month D1 bar open |
| `strategy_endpoint_stale_days` | 10 | [10] | newest completed-month endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Every value is a locked singleton. Changing endpoint count, pivot membership,
slope orientation, median indexes, direction, clock, risk, stop, hold, spread,
or retry policy requires a new card and full pipeline run.

## Author Claims

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, positive continuation over the first twelve monthly lags, and WTI in
their commodity universe. Siegel documents repeated-median statistical
lineage. They do not claim that this WTI rule works, that the locked arithmetic
is superior, that a continuous CFD reproduces rolling futures, or that the
candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, CFD roll/basis and financing,
single-name concentration, slow state reversal, hard-stop slippage, and
correlation with XNG or risk assets can dominate the premise. Slopes share
endpoints and appear in two pivot groups; nested medians do not create
independent evidence or guarantee predictive value.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong endpoint order, nonconsecutive months, current-month leakage,
  stale newest endpoint, wrong pivot membership, slope orientation or
  denominator, any pivot count other than twelve, inner indexes other than
  5/6, pivot-median count other than thirteen, outer index other than 6,
  wrong-side entry, repeated monthly attempt, hold beyond forty days, missing
  hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing lookback, estimator, median definition,
  direction, entry clock, stop, hold, spread cap, retry policy, or carrier.

## Strategy Allowability Check

- [x] R1: PASS with estimator-translation risk. Complete-read peer-reviewed
  WTI trading evidence plus an official peer-reviewed method record; no method
  performance is imported.
- [x] R2: PASS. Fixed endpoints, pivot groups, slopes, both median stages,
  direction, attempt, hard stop, rollover, and stale exit.
- [x] R3: PASS with continuous-CFD basis risk. Registered `XTIUSD.DWX` D1 plus
  native V5 execution state only.
- [x] R4: PASS. Deterministic logarithm, pairwise arithmetic, sorting,
  calendar, and ATR risk arithmetic; no trained model, banned signal
  indicator, external feed, grid, or martingale.
- [x] Dedup: one Theil-Sen fuzzy neighbor manually resolved by different
  aggregation and a fixed opposite-sign counterexample.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, endpoint reconstruction, exact
  pivot slopes and nested medians, spread/quote/ATR/stop checks, and one
  fixed-risk order.
- trade_management: malformed-state repair, prior-month exit, and stale exit
  before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Falsification And Requalification

Retire at Q02 on zero trades, fewer than five completed positions per full
post-warm-up year, or nonpositive governed economics. Any current-month
leakage, missing/duplicate month, nonlatest close, wrong pivot, missing or
duplicated grouped slope, wrong denominator, count, inner or outer median,
direction, same-month retry, risk-mode breach, or nondeterminism is an
implementation failure rather than a tunable result.

Any change to carrier, observation count, pivot grouping, slope orientation,
median convention, direction, stop, spread cap, attempt lifecycle, symbol,
timeframe, news/Friday mode, or risk mode requires a new binary and full
pipeline requalification. Realized diversification may only be assessed at
the unchanged portfolio-correlation gate; a correlation failure receives no
waiver here.

## Safety Boundary

This card authorizes only governed magic allocation, one branch build, strict
compile/Q01, one D1 `RISK_FIXED` backtest setfile, and one paced non-live Q02
enqueue if CPU capacity permits. It does not authorize a manual backtest;
live, demo, shadow, stress, or optimization setfile; AutoTrading; `T_Live`;
deploy or T_Live manifest; portfolio-gate mutation; portfolio admission; or
correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-25 | initial thirteen-month WTI repeated-median robust-trend card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-25 | APPROVED; R1-R4 PASS | `decisions/2026-08-25_qm5_41158_wti_monthly_repeated_median_trend_g0.md`; approved source packet |
| Q01 Build Validation | - | NOT_BUILT | strict compile and build checks pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | Q01 and build review pending |
