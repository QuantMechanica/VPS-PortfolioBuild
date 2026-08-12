---
card_schema_version: 2
type: strategy
strategy_id: HOLLSTEIN-MAX-2021_XAU_XAG_S03
variant_id: HOLLSTEIN-MAX-2021_XAU_XAG_S03
source_id: HOLLSTEIN-XAUXAG-KURT-2026
ea_id: QM5_20291
slug: xauxag-kurt-rk
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20291_xauxag-kurt-rk_card.md
execution_contract_status: DRAFT
created: 2026-08-12
created_by: Research+Development
last_updated: 2026-08-12
g0_status: APPROVED
source_author: "Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_authors: "Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_citation: "Hollstein, Prokopczuk, and Tharann (2021), Anomalies in Commodity Futures Markets, Quarterly Journal of Finance 11(4), article 2150017, DOI 10.1142/S2010139221500178."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Hollstein, F., Prokopczuk, M., and Tharann, B. (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), 2150017."
    location: "DOI https://doi.org/10.1142/S2010139221500178; complete accepted-manuscript evidence strategy-seeds/sources/HOLLSTEIN-MAX-2021/source.md; bounded carrier extraction strategy-seeds/sources/HOLLSTEIN-XAUXAG-KURT-2026/source.md"
    quality_tier: A
    role: primary_historical_kurtosis_formula_direction_and_monthly_cadence
strategy_mechanic: monthly-xau-xag-prior-252-simple-return-pearson-historical-kurtosis-high-minus-low-rank
sources:
  - "[[sources/HOLLSTEIN-XAUXAG-KURT-2026]]"
concepts:
  - "[[concepts/historical-kurtosis-premium]]"
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/pearson-kurtosis]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, historical-kurtosis, fourth-moment-premium, cross-sectional-rank, market-neutral-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, gold, silver]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20291_XAU_XAG_HKURT_D1
symbol: QM5_20291_XAU_XAG_HKURT_D1
symbol_slot: 0
magic: 202910000
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
pipeline_phase: G0_APPROVED
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a monthly XAU/XAG fourth-moment relative premium without directional metal intent. It differs from ratio convergence, skewness, semivariance, expected-shortfall, volatility-of-volatility, variance-ratio, trend, calendar, and RSI systems; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, exactly_252_simple_returns, source_variance_denominator, source_fourth_moment_denominator, high_kurtosis_direction, aggregate_fixed_risk, restart_attempt_state, magic_schema, cfd_futures_basis, narrow_cross_section, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-12_qm5_20291_xauxag_kurt_rank_g0.md: R1 peer-reviewed QJF source with complete-read evidence and adverse robustness disclosed; R2 exact 252-return Pearson historical-kurtosis rank and paired lifecycle; R3 registered XAU/XAG D1 route; R4 deterministic native arithmetic without trained output or prohibited signal indicator. No exact identity; five fuzzy neighbors were manually separated by carrier or statistic."
---

# QM5_20291 XAU/XAG Historical-Kurtosis Rank

## Hypothesis

A relative premium associated with the shape of commodity return
distributions may survive in a two-metal carrier: each month, buy the XAU/XAG
leg with higher prior-year Pearson historical kurtosis and short the lower-
kurtosis leg. Opposite sides reduce common precious-metal direction relative
to outright XAU exposure, but equal stop-risk halves do not prove market,
dollar, beta, volatility, factor, or portfolio neutrality.

The source evidence is weak for a two-way split and reverses in its later
subperiod. Q02 therefore owns density and economics; unchanged downstream
gates, especially Q09, own robustness and realized book overlap.

## Source Traceability And Claim Boundary

The trading source is Hollstein, Prokopczuk, and Tharann (2021), a peer-
reviewed QJF article with DOI and institutional accepted manuscript. The
complete-read parent and bounded carrier packet are listed in the metadata.

The paper specifies the 252-return historical-kurtosis statistic, monthly
cross-sectional sort, and high-minus-low direction. It does not test a two-
metal continuous-CFD carrier. Its directly relevant two-portfolio result is
insignificant, the later-period result changes sign and is insignificant,
and the regression slope is insignificant. No source return, alpha, Sharpe,
drawdown, cost, CFD equivalence, trade count, or correlation transfers.

## Non-Duplicate Decision

The canonical pre-allocation check found no exact identity and five lexical
fuzzy matches. Manual mechanic review separated them:

- `QM5_13131_energy-kurt-rank` is the same source rule on XTI/XNG. This card
  is the OWNER-authorized XAU/XAG carrier falsification and imports no sibling
  result.
- `QM5_20233` ranks third-moment skewness; `QM5_20234` ranks signed
  semivariance; `QM5_20235` ranks expected shortfall; and `QM5_20236` ranks
  volatility-of-volatility. None computes the fourth central moment divided
  by squared sample variance.
- Ratio, OLS, quantile, return-shock, momentum, calendar, variance-ratio, and
  idiosyncratic-volatility metal baskets use different information objects.
- The legacy kurtosis EAs combine higher moments with other daily or weekly
  states rather than trading a pure monthly XAU/XAG rank.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback and has neither a fourth-moment rank nor paired lifecycle.

The 252 simple returns, source denominators, Pearson fourth moment, high-
minus-low direction, XAU/XAG carrier, monthly cadence, equal risk halves, and
consumed-attempt lifecycle are jointly load-bearing. Verdict:
`CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Formula

- Logical basket: `QM5_20291_XAU_XAG_HKURT_D1`.
- Host/slot 0: `XAUUSD.DWX`, D1, intended magic `202910000`.
- Traded slot 1: `XAGUSD.DWX`, D1, intended magic `202910001`.
- Decision clock: first processed host D1 bar after a genuine broker-month
  transition.
- Formation: exactly 253 completed closes and 252 chronological simple
  returns per leg, with a completed and fresh latest endpoint.

```text
r[d] = close[d] / close[d-1] - 1
mu = sum(r[d]) / 252
s2 = sum((r[d] - mu)^2) / 251
m4 = sum((r[d] - mu)^4) / 252
kurtosis = m4 / (s2^2)
```

BUY XAU/SELL XAG when `kurtosis_XAU - kurtosis_XAG > 1e-12`.
SELL XAU/BUY XAG when the difference is below `-1e-12`. Otherwise stay flat.

## Rules

These are the complete authorized baseline. There is no parameter sweep,
alternate estimator, level-ratio fallback, or post-result repair.

## 4. Entry Rules

1. Require exact EA ID 20291, XAU host D1, slot 0, and all baseline inputs.
2. Detect a genuine broker-month transition and process lifecycle exits
   before entry-only gates.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, ATR, sizing, or order checks. No outcome retries that month.
4. Reject owned exposure or an entry deal for either registered magic in the
   same broker month.
5. Load bounded completed D1 history for both legs. Require exactly 253
   closes, strictly increasing timestamps, and a newest endpoint before the
   decision bar and no more than ten calendar days old.
6. Compute exactly 252 simple returns and the locked Pearson historical-
   kurtosis values. Reject invalid price, arithmetic, variance, kurtosis, or
   a numerical tie.
7. Buy the higher-kurtosis metal and short the lower-kurtosis metal.
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
parameter mismatch, consumed attempt, existing/invalid package, stale or
incomplete history, non-increasing timestamps, nonpositive price or variance,
invalid moment, tie, excessive spread, invalid quote/ATR/stop/volume, or
same-month entry history. Runtime may not read options, a futures chain,
volume, open interest, files, APIs, trained output, optimizer results, or
portfolio state. Both news axes are locked OFF for Q02.

## 7. Trade Management Rules

Maintain exactly zero or two opposite-side registered legs and no more than
one consumed attempt per broker month. Preserve each original hard stop;
close before monthly renewal or after forty days. A terminal-persistent month
marker plus deal history protects restart behavior; tester initialization
clears a future marker for deterministic historical runs. Repair malformed
composition before evaluating any entry-only gate.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_lookback_d1` | 252 | [252] | exact completed simple returns |
| `strategy_history_bars` | 320 | [320] | bounded retrieval buffer |
| `strategy_max_endpoint_gap_days` | 10 | [10] | latest completed-bar freshness |
| `strategy_variance_floor` | 1e-16 | [1e-16] | positive sample-variance floor |
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
unstable fourth-moment estimation, outlier dominance, CFD roll/financing,
unequal dollar and beta exposure, per-leg stop orphaning, gaps, slippage,
and the source's insignificant or sign-reversed robustness evidence.

## Kill Criteria

Retire on zero trades, fewer than five completed packages per full post-
warm-up year, nonpositive governed economics, or downstream correlation
rejection. Fail on wrong return count/orientation, wrong denominators,
excess-kurtosis substitution, low-kurtosis-long direction, repeated attempt,
orphan persistence, aggregate risk breach, missing stop, hold beyond forty
days, risk mismatch, or nondeterminism. Do not rescue a failure by tuning.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Peer-reviewed QJF paper, DOI, complete accepted-manuscript record, and adverse robustness disclosed. |
| R2 | PASS | Fixed return count, Pearson formula, rank, package, attempt, risk, stop, renewal, and stale exit. |
| R3 | PASS | Registered XAU/XAG `.DWX` D1 history plus native execution state only. |
| R4 | PASS | Deterministic arithmetic; no trained output, prohibited signal indicator, or external feed. |

## Framework Alignment

- no_trade: exact host/EA/slot/input, fixed risk/news/Friday contract, and
  cheap guards.
- trade_entry: persistent attempt, bounded completed history, Pearson
  kurtosis rank, spread/quote/ATR/stop checks, and paired fixed-risk orders.
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
| v1 | 2026-08-12 | initial source-bounded XAU/XAG historical-kurtosis carrier | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-12 | APPROVED | `decisions/2026-08-12_qm5_20291_xauxag_kurt_rank_g0.md` |

