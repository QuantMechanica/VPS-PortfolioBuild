---
card_schema_version: 2
type: strategy
strategy_id: HOLLSTEIN-VOV-2021_XAU_XAG_S02
variant_id: HOLLSTEIN-VOV-2021_XAU_XAG_S02
source_id: HOLLSTEIN-VOV-2021
ea_id: QM5_20236
slug: xauxag-vov-rank
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20236_xauxag-vov-rank_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_citation: "Hollstein, Prokopczuk, and Tharann (2021), Quarterly Journal of Finance 11(4), article 2150017, DOI 10.1142/S2010139221500178."
source_citations:
  - type: peer_reviewed_paper
    citation: "Hollstein, F., Prokopczuk, M., and Tharann, B. (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), 2150017."
    location: "Complete 57-page accepted manuscript and online appendix; especially pp. 5-9, p. 16, Appendix B p. 29, Table 4 Panel D, and Online Appendix Tables A1 and A3-A5; DOI https://doi.org/10.1142/S2010139221500178; governed packet strategy-seeds/sources/HOLLSTEIN-VOV-2021/source.md"
    quality_tier: A
    role: primary
strategy_mechanic: monthly-xau-xag-prior-252-overlapping-20d-realized-volatility-of-volatility-low-minus-high-rank
sources:
  - "[[sources/HOLLSTEIN-VOV-2021]]"
concepts:
  - "[[concepts/volatility-of-volatility-premium]]"
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/realized-volatility]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, realized-volatility-of-volatility, uncertainty-premium, cross-sectional-rank, market-neutral-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, gold, silver]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20236_XAU_XAG_VOV_D1
symbol: QM5_20236_XAU_XAG_VOV_D1
symbol_slot: 0
magic: 202360000
period: D1
timeframe: D1
expected_trade_frequency: "One XAU/XAG realized-VoV package each broker calendar month after 273 completed D1 closes; approximately 12 completed packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
review_focus: "Falsify a monthly relative uncertainty premium on the XAU/XAG carrier: long the metal with more stable rolling realized volatility and short the one with less stable rolling volatility. It adds a nested volatility-state driver rather than outright metal direction, ratio convergence, RSI, trend, seasonality, skewness, semivariance, or downside-tail exposure; Q09 alone may establish book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, completed_bar_history, aggregate_fixed_risk, restart_attempt_state, magic_schema, implied_realized_proxy, cfd_futures_basis, narrow_cross_section, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER 2026-08-06 commodity/energy sleeve mission: R1 complete peer-reviewed QJF source and durable governed packet; R2 locked nested 20-return/252-sample realized-VoV estimator, low-minus-high rank, shared fixed risk, hard stops, consumed attempt, renewal, and orphan repair; R3 registered native XAU/XAG D1 histories; R4 deterministic native arithmetic only. Deterministic dedup found no exact identity and five fuzzy neighbors; manual carrier and mechanic review is clean. The implied-to-realized proxy and the parent energy carrier's Q08 failure are disclosed, and no efficacy transfers."
---

# QM5_20236 XAU/XAG Monthly Realized-VoV Rank

## Hypothesis

Uncertainty about a commodity's risk can itself be priced. A monthly package
that buys the XAU/XAG leg whose rolling realized volatility is more stable and
shorts the leg whose rolling realized volatility is less stable tests that
structural uncertainty premium while reducing common precious-metal direction
relative to an outright XAU strategy.

Opposite directions and equal fixed-risk halves do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Q02 must establish trade
density and economics. The unchanged Q09 gate alone may measure realized
overlap with the certified XAU/SP500/NDX/XNG book.

## Source Traceability And Evidence Boundary

The governed source is Hollstein, Prokopczuk, and Tharann (2021), *Quarterly
Journal of Finance* 11(4), article 2150017. The complete accepted manuscript
and online appendix were read end to end and are bounded in
`strategy-seeds/sources/HOLLSTEIN-VOV-2021/source.md`.

The source ranks a broad commodity-futures universe monthly. It defines VoV
from 252 daily option-implied-volatility observations and reports a negative
high-minus-low relation, including a negative two-portfolio robustness result.
Darwinex CFD runtime has no commodity option chain, so this card uses a fully
declared price-native proxy: dispersion across overlapping rolling realized-
volatility estimates. This is a falsification, not a replication.

The paper does not test a two-metal CFD carrier, synchronized broker D1 bars,
equal stop-risk halves, ATR stops, legging, financing, or the QM portfolio. No
source return, alpha, significance, Sharpe, drawdown, cost, or correlation
number is imported.

The locked XTI/XNG carrier `QM5_13146_energy-vov` reached Q07 and then failed
Q08 on the runs-test hard classification, with separate invalid neighborhood
and PBO evidence. Its Q08 full-history baseline was PF 1.22 over 132 tester
trades. That result is adverse context only and does not transfer to XAU/XAG.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,293 registry rows and 409
canonical cards. It found no exact identity and five lexical fuzzy matches.
Manual review resolves them as follows:

- `QM5_13146_energy-vov` is the same locked estimator on XTI/XNG. This card is
  the OWNER-requested XAU/XAG carrier falsification, not an estimator,
  direction, cadence, or stop sweep.
- `QM5_20233_xauxag-skew-rank` estimates a centered third moment,
  `QM5_20234_xauxag-rsj` compares positive and negative semivariance, and
  `QM5_20235_xauxag-es-rank` averages the worst five percent of returns. None
  measures instability along a path of rolling realized-volatility estimates.
- XAU/XAG ratio and OLS baskets trade level convergence; quantile, momentum,
  calendar, return-shock, and idiosyncratic-volatility baskets use different
  state variables, transforms, or clocks.
- `QM5_1212_carver-kurtsabs`, `QM5_1221_carver-kurtsrv`, and
  `QM5_10322_realized-moments` are daily/weekly higher-moment composites, not
  this pure monthly nested realized-VoV rank.
- `QM5_12567_cum-rsi2-commodity` is short-horizon long-only oscillator logic.

The 20-return inner window, 252 overlapping RV observations, sample variance
inside RV, population dispersion across RV, division by mean RV,
low-minus-high direction, XAU/XAG carrier, monthly renewal, equal risk halves,
and no same-month retry are jointly load-bearing. Verdict:
`CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Concept And Formula

On the first tradable XAUUSD.DWX D1 bar of broker month t, load 273 completed
D1 closes for each metal. For each of 252 overlapping endpoints d, calculate
20-return annualized realized volatility:

```text
r[d,k] = log(close[d+k] / close[d+k+1]), k=0..19
rv[d]  = sample_std(r[d,0..19]) * sqrt(252)
```

Apply the source's dispersion-over-mean transform to the 252 price-native RV
observations:

```text
mean_rv      = average(rv[d], d=0..251)
realized_vov = sqrt(sum((rv[d] - mean_rv)^2) / 252) / mean_rv
```

- `realized_vov_XAU < realized_vov_XAG`: BUY XAU and SELL XAG.
- `realized_vov_XAU > realized_vov_XAG`: SELL XAU and BUY XAG.
- A numerical tie, stale endpoint, missing/nonpositive price, nonpositive
  variance or mean, invalid arithmetic, or insufficient history remains flat.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20236_XAU_XAG_VOV_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `202360000`.
- Traded slot 1: `XAGUSD.DWX`, D1, magic `202360001`.
- Formation: exactly 252 overlapping realized-volatility observations, each
  based on exactly 20 completed D1 log returns; current bars are excluded.
- Decision: first tradable host D1 bar of each broker month.
- Hold: until the next broker-month transition, bounded by 40 calendar days.
- Runtime data: native MT5 D1 time/close, ATR, spread, broker calendar, deal
  history, position state, and contract metadata only.

## Rules

### Entry

1. Require exact host `XAUUSD.DWX`, D1, and magic slot 0.
2. Detect a broker-month transition from the current and prior host D1 bars.
3. Before any data or order gate, persist the current period as consumed so a
   restart, invalid input, tie, or stopped package cannot retry that month.
4. Load bounded completed history for both legs. Require the newest endpoint
   to precede the decision bar and be no more than ten calendar days old.
5. Calculate the locked 20-return/252-sample realized-VoV values. Require all
   prices, variances, RV observations, means, and final values to be positive
   and finite; reject a numerical tie.
6. Buy the lower-VoV metal and short the higher-VoV metal.
7. Reject excess spread, existing/invalid package composition, invalid ATR or
   lot metadata, or a broker month already present in entry-deal history.
8. Split the one fixed-risk package equally. Attach a frozen
   `3.5 * ATR(20,D1)` hard stop to each leg.
9. If only one opening order succeeds, close that orphan immediately.

### Management And Exit

1. Close both legs on the first tradable D1 host bar of the next broker month
   before evaluating the replacement package.
2. Close both legs after `strategy_max_hold_days=40`.
3. If a stop removes one leg, flatten the orphan immediately.
4. Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
5. Friday close is disabled only to preserve the source-aligned monthly hold;
   the framework kill switch remains authoritative.
6. No take profit, trailing stop, break-even, partial close, scale-in, grid,
   martingale, pyramiding, external runtime feed, option input, adaptive PnL
   fit, or discretionary rule is authorized.

### No-Trade And News

- Exact host, timeframe, slot, parameter, bounded-history, endpoint-freshness,
  arithmetic, spread, ATR, lot, magic, package, and consumed-attempt checks
  fail closed.
- News compliance gates new entries for both traded symbols. Lifecycle exits
  and orphan repair remain active. The Q02 setfile disables both news axes.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_rv_window_d1` | 20 | [20] | completed log returns per RV observation |
| `strategy_vov_samples` | 252 | [252] | overlapping RV observations in VoV transform |
| `strategy_history_bars` | 320 | [300, 320, 400] | bounded D1 retrieval buffer only |
| `strategy_max_endpoint_gap_days` | 10 | [7, 10] | completed endpoint freshness |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg hard-stop ATR |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 40 | [40] | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | [1000, 1500, 2500] | XAU spread cap |
| `strategy_xag_max_spread_pts` | 3000 | [2000, 3000, 4500] | XAG spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | paired order deviation |

Only the bounded retrieval buffer, endpoint freshness, ATR safety stop, spread
caps, and order deviation may take the predeclared values. The nested 20/252
estimator, source transform, direction, carrier, decision clock, monthly hold,
equal risk halves, and consumed-attempt behavior are locked.

## Risk And Kill Criteria

- Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` for one aggregate package, split equally across legs.
- Risk class is high because the source signal is implied while the EA proxy
  is realized, the cross-section has only two CFDs, both metals share USD and
  precious-metal exposures, gaps and legging can break neutrality, and the
  parent carrier failed Q08.
- Expected density is approximately twelve packages/year after warm-up.
  Retire below five completed packages per full post-warm-up year.
- Fail on zero trades, wrong nested-window construction, wrong direction,
  nondeterminism, stale history, persistent orphan exposure, risk mismatch,
  nonpositive governed economics, or a later portfolio-correlation rejection.
- Do not switch to raw volatility level, implied data, a percentile, ratio
  reversion, a directional filter, another window, reversed direction, or a
  relaxed retry/package guard to rescue results.

## Strategy Allowability Check

- [x] Structural uncertainty-about-risk thesis with monthly cadence.
- [x] Peer-reviewed primary source with DOI, complete institutional text,
      formula locations, portfolio evidence, and robustness caveats.
- [x] Deterministic native MT5 arithmetic; no banned indicator, external
      runtime dependency, grid, martingale, pyramiding, or adaptive fitting.
- [x] Registered XAUUSD.DWX and XAGUSD.DWX D1 data inputs.
- [x] Expected frequency exceeds the binding five-package/year floor.
- [x] One fixed-risk basket setfile; no live artifact is authorized.
- [x] Exact dedup clean and all fuzzy matches manually resolved.

## Framework Alignment

- no_trade: exact host/slot, locked parameters, bounded completed history,
  endpoint freshness, finite arithmetic, spread, ATR, lot, magic, package,
  deal-history, and consumed-attempt guards.
- trade_entry: monthly lower/higher realized-VoV rank, paired orders, equal
  fixed-risk allocation, frozen hard stops, and second-leg rollback.
- trade_management: next-month close, 40-day stale exit, composition
  validation, and orphan repair.
- trade_close: framework close helper plus broker-side hard stops.

No live setfile, T_Live action, AutoTrading change, deploy manifest, portfolio
gate edit, portfolio admission, or correlation waiver is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | initial approved XAU/XAG realized-VoV carrier build | G0 | APPROVED |
| v1.1 | 2026-08-06 | restart-safe V5 implementation, strict compile, and build validation | Q01 | PASS |
| v1.2 | 2026-08-06 | paced Q02 enqueue withheld at the binding 9-of-7 factory-terminal CPU ceiling | Q02 | NOT ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20236_xauxag_vov_rank_g0.md` |
| Q01 Build Validation | 2026-08-06 | PASS | `framework/build/compile/20260806_013254/QM5_20236_xauxag-vov-rank.compile.log`; `D:/QM/reports/framework/21/build_check_20260806_013327.json` (0 errors, 0 warnings, 0 gate failures) |
| Q02 Baseline Screening | 2026-08-06 | NOT ENQUEUED - CPU CEILING | targeted dry run selected one priority item; apply withheld because 9 factory terminals were active against the ceiling of 7 |

## Lessons Captured

- 2026-08-06: The mechanic remains distinct only while the signal is
  dispersion across a path of rolling realized-volatility observations;
  replacing it with current RV rank, tail loss, skewness, or ratio convergence
  would recreate an existing family.
