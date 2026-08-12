---
card_schema_version: 2
type: strategy
strategy_id: HOLLSTEIN-MAX-2021_XAU_XAG_S04
variant_id: HOLLSTEIN-MAX-2021_XAU_XAG_S04
source_id: HOLLSTEIN-XAUXAG-MAX-2026
ea_id: QM5_20294
slug: xauxag-max-rk
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20294_xauxag-max-rk_card.md
execution_contract_status: DRAFT
created: 2026-08-12
created_by: Research+Development
last_updated: 2026-08-12
g0_status: APPROVED
source_authors: "Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_citation: "Hollstein, Prokopczuk, and Tharann (2021), Anomalies in Commodity Futures Markets, Quarterly Journal of Finance 11(4), article 2150017, DOI 10.1142/S2010139221500178."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Hollstein, F., Prokopczuk, M., and Tharann, B. (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), 2150017."
    location: "DOI https://doi.org/10.1142/S2010139221500178; complete accepted-manuscript evidence strategy-seeds/sources/HOLLSTEIN-MAX-2021/source.md; bounded carrier extraction strategy-seeds/sources/HOLLSTEIN-XAUXAG-MAX-2026/source.md"
    quality_tier: A
    role: primary_max_formula_post_financialization_direction_and_monthly_cadence
strategy_mechanic: monthly-xau-xag-prior-252-simple-return-top-five-max-low-minus-high-rank
sources:
  - "[[sources/HOLLSTEIN-XAUXAG-MAX-2026]]"
concepts:
  - "[[concepts/commodity-max-effect]]"
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/top-five-return-mean]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, max-effect, upside-order-statistic, cross-sectional-rank, market-neutral-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, gold, silver]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20294_XAU_XAG_LOWMAX_D1
symbol: QM5_20294_XAU_XAG_LOWMAX_D1
symbol_slot: 0
magic: 202940000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve two-leg XAU/XAG packages per year after 253 completed D1 closes; Q02 must prove at least five completed packages per full post-warm-up year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: NOT_STARTED
q02_status: NOT_STARTED
review_focus: "Falsify the source's post-financialization low-MAX relation on a paired XAU/XAG carrier. Full-sample and two-portfolio evidence is null; paired legs do not prove neutrality, and Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, exactly_252_simple_returns, exactly_five_largest_mean, low_max_direction, aggregate_fixed_risk, restart_attempt_state, magic_schema, cfd_futures_basis, narrow_cross_section, subsample_evidence, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-12_qm5_20294_xauxag_max_rank_g0.md: R1 peer-reviewed QJF source with complete-read evidence and full-sample/two-portfolio nulls disclosed; R2 exact 252-return top-five arithmetic mean, low-MAX direction, paired lifecycle, risk, and restart contract; R3 registered XAU/XAG D1 route; R4 deterministic native arithmetic without trained output or prohibited signal indicator. No exact identity; ten fuzzy neighbors were manually separated by statistic or carrier."
---

# QM5_20294 XAU/XAG Low-MAX Rank

## Hypothesis

A commodity characteristic associated with investor demand for lottery-like
upside extremes may survive in a two-metal carrier: each month, buy the
XAU/XAG leg with the lower average of its five largest prior-year daily
returns and short the higher-MAX leg. Opposite sides target less outright
metal direction than standalone XAU, but equal stop-risk halves do not prove
dollar, beta, volatility, factor, market, or portfolio neutrality.

The source evidence is subsample-dependent and null in the directly relevant
two-portfolio split. Q02 therefore owns density and economics; unchanged
downstream gates, especially Q09, own robustness and realized book overlap.

## Source Traceability And Claim Boundary

The trading source is Hollstein, Prokopczuk, and Tharann (2021), a peer-
reviewed QJF article with DOI and institutional accepted manuscript. The
complete-read parent and bounded carrier packet are listed in the metadata.

The paper defines the 252-return top-five MAX statistic, monthly cross-
sectional sort, and low-minus-high direction in its post-financialization
subsample. The full-sample hedge return and two-portfolio result are null,
the supporting subsample ends in 2015, and the paper does not test a two-
metal continuous-CFD carrier. No source return, alpha, Sharpe ratio,
drawdown, cost, CFD equivalence, trade count, neutrality, or correlation
transfers.

## Non-Duplicate Decision

The canonical pre-allocation check found no exact identity and ten fuzzy
source/carrier matches. Manual review separated them:

- `QM5_13130` applies the same statistic to XTI/XNG and supplies no result for
  this OWNER-authorized XAU/XAG carrier extension;
- `QM5_20291` uses all observations in Pearson historical kurtosis and buys
  high kurtosis; this rule averages only the five largest returns and buys
  low MAX;
- XAU/XAG skewness, semivariance, expected-shortfall, volatility-of-
  volatility, variance-ratio, ratio, residual, quantile, return-shock,
  momentum, calendar, and RSI systems use different information objects; and
- `QM5_12567` is a short-horizon long-only cumulative-RSI pullback.

The 252 simple returns, five-largest arithmetic mean, low-minus-high
direction, XAU/XAG carrier, monthly cadence, equal risk halves, and consumed-
attempt lifecycle are jointly load-bearing. Verdict:
`CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Formula

- Logical basket: `QM5_20294_XAU_XAG_LOWMAX_D1`.
- Host/slot 0: `XAUUSD.DWX`, D1, intended magic `202940000`.
- Traded slot 1: `XAGUSD.DWX`, D1, intended magic `202940001`.
- Decision clock: first processed host D1 bar after a genuine broker-month
  transition.
- Formation: exactly 253 completed closes and 252 chronological simple
  returns per leg, with a completed and fresh latest endpoint.

```text
r[d] = close[d] / close[d-1] - 1
MAX_i = arithmetic_mean(five_largest(r_i[1..252]))
```

BUY XAU/SELL XAG when `MAX_XAU < MAX_XAG`. SELL XAU/BUY XAG when
`MAX_XAU > MAX_XAG`. Stay flat when the absolute difference is at or below
`1e-12` or either state is invalid.

## Rules

These are the complete authorized baseline. There is no parameter sweep,
alternate estimator, direction flip, threshold rescue, or post-result repair.

## 4. Entry Rules

1. Require exact EA ID 20294, XAU host D1, slot 0, and all baseline inputs.
2. Detect a genuine broker-month transition and process lifecycle exits
   before entry-only gates.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, ATR, sizing, or order checks. No outcome retries that month.
4. Reject owned exposure or an entry deal for either registered magic in the
   same broker month.
5. Load bounded completed D1 history for both legs. Require exactly 253
   closes, strictly increasing timestamps, and a newest endpoint before the
   decision bar and no more than ten calendar days old.
6. Compute exactly 252 simple returns per leg, sort each complete vector, and
   average exactly its five largest observations. Reject invalid price,
   chronology, return, arithmetic, observation count, or numerical tie.
7. Buy the lower-MAX metal and short the higher-MAX metal.
8. Require spread within XAU 1500/XAG 3000 points, executable quotes,
   completed ATR(20,D1), and valid volume metadata.
9. Split one `RISK_FIXED=1000` package into equal stop-risk halves; attach a
   frozen `3.5 * ATR(20,D1)` hard stop to each leg and no take-profit.
10. If only one leg opens, close the orphan immediately and do not retry.

## 5. Exit Rules

1. Close both legs on the first processed D1 host bar of the next broker
   month before considering replacement risk.
2. Close both legs after forty elapsed calendar days as a stale guard.
3. Flatten an orphan, duplicate, same-side, wrong-symbol, wrong-magic, or
   missing-stop package immediately.
4. Per-leg broker hard stops and the framework kill switch remain binding.
5. Friday close is disabled to preserve the monthly source cadence.
6. No target, intramonth flip, trail, break-even, partial close, scale-in,
   grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

Fail closed on wrong host, timeframe, EA, slot, risk/news/Friday contract,
parameter mismatch, consumed attempt, existing or malformed package, stale
or incomplete history, non-increasing timestamps, nonpositive price, invalid
return or MAX measure, tie, excessive spread, invalid quote/ATR/stop/volume,
or same-month entry history. Runtime may not read futures chains, options,
volume, open interest, files, APIs, trained output, optimizer results, or
portfolio state. Both news axes are locked OFF for Q02.

## 7. Trade Management Rules

Maintain exactly zero or two opposite-side registered legs and no more than
one consumed attempt per broker month. Preserve each original hard stop;
close before monthly renewal or after forty days. A terminal-persistent month
marker plus deal history protects restart behavior; tester initialization
clears a future marker for deterministic historical reruns. Repair malformed
composition before evaluating any entry-only gate.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_lookback_d1` | 252 | [252] | exact completed simple returns |
| `strategy_top_return_count` | 5 | [5] | exact source order-statistic count |
| `strategy_history_bars` | 320 | [320] | bounded retrieval buffer |
| `strategy_max_endpoint_gap_days` | 10 | [10] | latest endpoint freshness |
| `strategy_rank_tolerance` | 1e-12 | [1e-12] | symmetric tie tolerance |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard stop |
| `strategy_max_hold_days` | 40 | [40] | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | basket-order deviation |

All signal, carrier, lifecycle, and risk values are locked. Any change
requires a new card and pipeline.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the whole package. Risks include metal co-movement,
top-order-statistic instability, source subsample decay, two-CFD basis and
financing, unequal dollar/beta exposure, per-leg stop orphaning, gaps,
slippage, and the source's full-sample/two-portfolio nulls.

## Kill Criteria

Retire on zero trades, fewer than five completed packages per full post-
warm-up year, nonpositive governed economics, or downstream correlation
rejection. Fail on wrong return count/orientation, wrong order-statistic
count, use of a maximum rather than the mean of five, high-MAX-long direction,
repeated attempt, orphan persistence, aggregate risk breach, missing stop,
hold beyond forty days, risk mismatch, or nondeterminism. Do not tune a
failure.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Peer-reviewed QJF paper, DOI, complete accepted-manuscript record, and adverse evidence disclosed. |
| R2 | PASS | Fixed return count, exact top-five mean, rank, package, attempt, risk, stop, renewal, and stale exit. |
| R3 | PASS | Registered XAU/XAG `.DWX` D1 history plus native execution state only. |
| R4 | PASS | Deterministic arithmetic; no trained output, prohibited signal indicator, or external feed. |

## Framework Alignment

- no_trade: exact host/EA/slot/input, fixed risk/news/Friday contract, and
  cheap guards.
- trade_entry: persistent attempt, bounded completed history, top-five MAX
  rank, spread/quote/ATR/stop checks, and paired fixed-risk orders.
- trade_management: malformed-package repair, broker-month exit, stale exit,
  and orphan cleanup before entry gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Safety Boundary

This card authorizes research, deterministic allocation, build, strict
compile/Q01, and one paced non-live Q02 handoff only. It excludes manual
backtests; live, demo, shadow, optimization, or stress setfiles; AutoTrading;
`T_Live`; deploy or T_Live manifests; portfolio-gate edits; portfolio
admission; and correlation waivers.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-12 | initial source-bounded XAU/XAG low-MAX carrier | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-12 | APPROVED | `decisions/2026-08-12_qm5_20294_xauxag_max_rank_g0.md` |
| Q01 Build Validation | - | NOT_STARTED | - |
| Q02 Baseline Screening | - | NOT_STARTED | - |
