---
card_schema_version: 2
type: strategy
strategy_id: MOP-THEILSEN-KOENKER-SIEGEL-WTI-MROBUST3-AGREE-2026_S01
variant_id: MOP-THEILSEN-KOENKER-SIEGEL-WTI-MROBUST3-AGREE-2026_S01
source_id: MOP-THEILSEN-KOENKER-SIEGEL-WTI-MROBUST3-AGREE-2026
ea_id: QM5_41165
slug: wti-mrobust3-agree-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41165_wti-mrobust3-agree-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-26
created_by: Research+Development
last_updated: 2026-08-26
g0_status: APPROVED
g0_decision: decisions/2026-08-26_qm5_41165_wti_monthly_robust_three_consensus_trend_g0.md
source_approval: decisions/2026-08-26_wti_monthly_robust_three_consensus_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Roger Koenker; Gilbert Bassett Jr.; Andrew F. Siegel"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Roger Koenker; Gilbert Bassett Jr.; Andrew F. Siegel"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Schweikert (2018), Journal of Banking and Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Siegel (1982), Robust Regression Using Repeated Medians, Biometrika 69(1), 242-244, DOI 10.1093/biomet/69.1.242."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence preserved under strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_price_direction_monthly_cadence_and_wti_membership
  - type: peer_reviewed_statistical_method_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking and Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete author-preprint evidence in strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md"
    quality_tier: A
    role: koenker_bassett_check_loss_and_finite_lad_reduction_lineage
  - type: peer_reviewed_statistical_method_record
    citation: "Siegel, A. F. (1982). Robust Regression Using Repeated Medians. Biometrika 69(1), 242-244."
    location: "DOI 10.1093/biomet/69.1.242; official Oxford Academic record preserved in strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md"
    quality_tier: A
    role: nested_repeated_median_regression_lineage
  - type: governed_method_precedent
    citation: "QuantMechanica bounded thirteen-completed-month WTI Theil-Sen, LAD, and repeated-median source packets."
    location: "strategy-seeds/sources/MOP-THEILSEN-KOENKER-SIEGEL-WTI-MROBUST3-AGREE-2026/source.md"
    quality_tier: internal_governed
    role: exact_three_estimator_arithmetic_endpoint_calendar_risk_and_lifecycle
strategy_mechanic: monthly-wti-thirteen-completed-month-end-log-price-theilsen-lad-repeated-median-unanimous-strict-sign-consensus-trend
sources:
  - "[[sources/MOP-THEILSEN-KOENKER-SIEGEL-WTI-MROBUST3-AGREE-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/robust-slope-consensus]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-price]]"
  - "[[indicators/theilsen-lad-repeated-median-consensus]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, robust-consensus, theil-sen, least-absolute-deviation, repeated-median, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 411650000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-12 completed WTI positions per full post-warm-up year after thirteen completed month ends and strict three-estimator agreement; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ENSEMBLE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a direct-WTI monthly robust-consensus trend outside the certified XAU/SP500/NDX/XNG book. Verify thirteen consecutive completed month ends, all 78 pair slopes, exact Theil-Sen median, every LAD residual profile/objective/tie, every repeated-median pivot group, strict unanimous signs, consumed attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, first_tradable_month_bar, thirteen_consecutive_completed_months, latest_close_per_month, chronological_log_prices, exact_78_pair_slopes, theilsen_indexes_38_39, lad_median_residual_intercept, lad_absolute_loss_objective, fixed_loss_equality_guard, exact_thirteen_repeated_median_pivots, exact_twelve_slopes_per_pivot, strict_three_way_sign_agreement, monthly_attempt_state, fixed_risk, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-26 and decisions/2026-08-26_qm5_41165_wti_monthly_robust_three_consensus_trend_g0.md: R1 PASS with explicit ensemble-translation risk using complete-read peer-reviewed WTI momentum and quantile-regression packets plus an official peer-reviewed repeated-median method record; R2 PASS locks all three estimators, unanimous signs, attempt, risk, stop, and lifecycle; R3 PASS registered native WTI D1 with continuous-CFD basis risk; R4 PASS deterministic native arithmetic only. Canonical dedup found one expected Theil-Sen fuzzy match, manually cleared by two disagreement vectors and one unanimous executable vector."
---

# QM5_41165 WTI Thirteen-Month Robust-Three Consensus Trend

## Hypothesis

WTI can sustain slow directional regimes while production, investment,
inventory, transport, refining, hedging, and demand adjust, but one robust
estimator can still encode a particular outlier geometry. This card asks for
directional agreement among three independently defined robust slopes over the
same thirteen completed month-end log prices. The purpose is to test whether
only broadly estimator-stable WTI paths continue, without fitting to PnL or
scaling risk by signal magnitude.

The direct crude-oil carrier is economically different from the certified
XAU, SP500, NDX, and XNG carriers. That is a diversification hypothesis, not
proof of low correlation, profitability, or portfolio suitability. Q02 owns
density and baseline economics; unchanged downstream gates, including Q09,
own robustness and realized overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-THEILSEN-KOENKER-SIEGEL-WTI-MROBUST3-AGREE-2026/source.md`,
SHA-256
`65A2E315EADB52182C00BD6A86867F9321B48CF714D62361A99FCBC327344D69`,
authorized by
`decisions/2026-08-26_wti_monthly_robust_three_consensus_trend_source_approval.md`
and committed at `17565d58d` before card extraction.

Moskowitz, Ooi, and Pedersen supply WTI membership, own-price continuation
lineage, and monthly cadence. The governed Schweikert/Koenker-Bassett packet
supplies LAD median-regression lineage and adverse evidence. The Siegel record
supplies repeated-median lineage. The Theil-Sen arithmetic comes from the
complete governed WTI carrier packet. None tests this exact three-way
consensus, continuous CFD, or fixed-dollar execution contract.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, WTI-only result, CFD equivalence, estimator superiority,
decorrelation, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,664 registry
rows, 1,315 cards, and 45 Strategy Wiki nodes. It found no exact match and one
expected fuzzy match to `wti-theilsen-tr_card.md` at score
`0.5833333333333334`. The receipt is
`artifacts/qm5_wti_mrobust3_agree_tr_preallocation_dedup_20260826.json`,
SHA-256
`469540A81B2615A7EAA97A071763BF72713D1B51B0934CEC02028F17D32F61F6`.

Manual review finds a new conjunction. `QM5_20271` trades Theil-Sen alone;
`QM5_41159` trades LAD alone; `QM5_41158` trades repeated median alone. On
`[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, the three signs are
positive, positive, and negative, so every constituent trades while this card
is flat. A second valid vector makes LAD negative and both other estimators
positive. Conversely, `y[i]=0.01*i` makes all three exactly positive and this
card trades. This is not a renamed single estimator or a parameter alias.

Verdict: `CLEAN_AFTER_EXPECTED_THEILSEN_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`.
- Signal and execution timeframe: D1.
- Decision clock: first executable tick of a genuine broker-month transition.
- Formation: latest close in each of the immediately prior thirteen
  consecutive completed broker months; current month excluded.
- Hold: until first tick in a later broker month; forty days is stale repair.
- One consumed attempt and at most one owned position per broker month.
- Expected pre-result density: five to twelve completed positions per full
  post-warm-up year; retire below five in any full year.

## Formula

For chronological completed-month closes `C[0]..C[12]`:

```text
y[i] = ln(C[i])

B = sorted((y[j]-y[i])/(j-i) for every 0 <= i < j <= 12)
require len(B) == 78
theilsen = (B[38] + B[39]) / 2

for candidate b in the 78 unsorted pair slopes:
  A = sorted(y[i] - b*i for i=0..12)
  a = A[6]
  loss[b] = sum(abs(y[i] - a - b*i) for i=0..12 in chronological order)
M = sorted(b for every candidate with abs(loss[b]-min(loss)) <= 1e-12)
lad = M[len(M)//2] when len(M) is odd
      (M[len(M)//2-1] + M[len(M)//2]) / 2 otherwise

for pivot i=0..12:
  P = twelve forward-oriented slopes joining i to every other endpoint
  pivot_median[i] = (sorted(P)[5] + sorted(P)[6]) / 2
repeated_median = sorted(pivot_median)[6]

BUY  iff theilsen > 0 and lad > 0 and repeated_median > 0
SELL iff theilsen < 0 and lad < 0 and repeated_median < 0
FLAT otherwise
```

All values and intermediate sums must be finite. Slope magnitude, loss,
intercept, and minimizer count never change risk.

## Rules

- `ea_id=41165`, exact `XTIUSD.DWX`, D1, slot 0, magic `411650000`.
- Consume the normalized broker month before every fallible entry gate.
- Use exactly thirteen consecutive completed month keys and the latest close
  in each. Newest endpoint must be the immediately prior month and at most ten
  calendar days stale.
- Require all three complete estimators; no fallback, majority, weighting,
  threshold, fitted scale, OLS, endpoint, calendar, volatility, or external
  gate is allowed.
- Only one unanimous strict sign can open a position.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

On every new D1 bar, in this order:

1. Require exact EA ID, symbol, D1 period, risk mode, framework inputs, and all
   locked strategy inputs.
2. Repair malformed owned exposure and process month/stale exits before entry.
3. Normalize the raw current-bar date under one uniform label convention and
   require a genuine new month within 180 elapsed minutes of the raw bar open.
4. Persist the current `yyyymm` in terminal global state before history,
   signal, news, spread, quote, ATR, sizing, margin, or order checks.
5. Reconstruct exactly thirteen consecutive completed month-end closes,
   reverse them into strict chronological order, and validate positivity,
   finiteness, endpoint month, chronology, and staleness.
6. Compute exactly 78 pair slopes and the Theil-Sen median.
7. Profile all 78 LAD candidates, each with thirteen residuals, sorted index 6
   intercept, chronological absolute loss, fixed `1e-12` tie set, and ordinary
   minimizer median.
8. Compute thirteen repeated-median pivot groups, exactly twelve slopes per
   pivot, inner indexes 5/6, and outer index 6.
9. Require all three slopes strictly positive or all strictly negative. Any
   disagreement or zero consumes the month flat.
10. Require spread no greater than 1,500 points, valid quotes, finite completed-
    bar ATR, a valid frozen stop distance, and successful fixed-risk sizing.
11. Buy for unanimous positive slopes or sell for unanimous negative slopes,
    with one broker hard stop and no target.
12. Retain only one correctly directed, correctly registered, stop-protected
    position. A reject never retries the month.

## 5. Exit Rules

Exit or repair at the first applicable condition:

1. Framework kill switch.
2. Broker hard stop frozen at entry.
3. Any duplicate, wrong-symbol, wrong-magic, wrong-side, or stopless owned
   position.
4. First tick whose normalized broker month differs from the entry month.
5. Forty calendar days after entry as stale-position repair.

There is no target, trail, break-even move, partial exit, Friday close, news
exit, opposite-signal exit, scale-in, or same-month re-entry.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Stop: frozen `3.5*ATR(20,D1)` from the last completed bar at entry.
- Maximum entry spread: 1,500 points.
- One position and one attempt per broker month.
- Slope, loss, intercept, and consensus strength never alter size.
- No live/demo/shadow/stress/optimization setfile is authorized.

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

No parameter sweep, majority fallback, direction flip, constituent omission,
alternate solver, fitted threshold, volatility filter, seasonal filter, or
ensemble weighting is authorized after results.

## 8. Failure Modes And Kill Criteria

Retire or fail the candidate on any of the following:

- fewer than five completed positions in any full post-warm-up Q02 year;
- zero trades, nonpositive governed economics, or a downstream gate failure;
- current-month leakage, missing/duplicate month keys, nonlatest close, stale
  newest endpoint, nonchronological timestamps, or mixed label offsets;
- pair-slope count other than 78, reversed denominator, nonfinite slope,
  wrong Theil-Sen indexes, residual count other than 13, wrong LAD intercept,
  objective count other than 78, wrong loss order, negative/nonfinite loss,
  changed equality guard, empty minimizer set, wrong ordinary median, pivot
  count other than 13, pivot-slope count other than 12, wrong nested-median
  indexes, or skipped estimator;
- majority/weighted/non-strict consensus, wrong trade side, same-month retry,
  missing hard stop, wrong risk mode, wrong spread ceiling, late entry, or
  missed month-boundary exit;
- nondeterministic output for identical history and inputs;
- any post-result rescue change to formation, any estimator, tie convention,
  consensus, direction, risk, stop, hold, symbol, or carrier; or
- downstream portfolio-correlation rejection. No waiver is implied.

## 9. Execution And State Contract

- The D1 decision clock supports only raw-current-date labels and a uniformly
  applied raw-plus-one-day convention; mixed offsets fail closed.
- A month is consumed before all fallible gates. Terminal global state and
  deal history prevent a restart retry.
- The current month contributes no signal close.
- Position repair and month rollover run every tick before new-entry gates.
- Logs expose decision month, label offset, endpoint count/times, pair count,
  all three slopes and signs, LAD minimum loss/minimizer count/intercept,
  direction, and state without logging credentials.

## 10. Portfolio Interaction

This is a direct physical-energy carrier intended to diversify an existing
XAU/SP500/NDX/XNG book. Its one-month robust-consensus trend driver is
mechanically different from the incumbent XNG cumulative-RSI2 pullback and
from the metal and index sleeves. Those are design facts only. No ex-ante or
realized correlation is claimed, and no portfolio gate, threshold, incumbent,
manifest, or admission state changes under this card. Q09 owns the first
realized overlap verdict; Q11+ remain manual OWNER gates.

## 11. Validation Plan

1. Schema-lint both canonical and EA card copies.
2. Independently reproduce all 78 pair slopes, Theil-Sen indexes 38/39, every
   LAD residual median/objective/tie, every repeated-median pivot group, and
   strict three-way signs.
3. Prove the two locked disagreement vectors consume flat and the strict
   linear vector opens BUY; include a descending vector that opens SELL.
4. Validate thirteen consecutive month keys, year rollover, latest-close
   selection, current-month exclusion, staleness, label conventions, grace,
   attempt order, and lifecycle repair.
5. Require strict zero-error/zero-warning compile, build guardrails, exact
   symbol scope, active registry identity, active magic row, and source-fresh
   EX5.
6. Enqueue exactly one `XTIUSD.DWX` D1 Q02 row only if the fresh paced-fleet
   CPU/queue ceiling permits. Enqueue does not launch a manual tester.
7. Retire below the five-per-year floor or on nonpositive governed economics.

## 12. Framework Alignment

- no_trade: exact EA ID, symbol, timeframe, magic slot, risk, news, Friday,
  stress, and locked strategy-input validation.
- trade_entry: month clock, consume-first attempt, exact completed endpoints,
  all three estimators, strict consensus, spread/quote/ATR/stop validation,
  and fixed-risk request.
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
| v1 | 2026-08-26 | initial source-bounded WTI robust-three consensus card | G0 | APPROVED |
