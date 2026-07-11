---
strategy_id: HE-SALIENCE-2025_XTI_XNG_S01
source_id: HE-SALIENCE-2025
ea_id: QM5_13142
slug: energy-sal-rank
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citations:
  - type: paper
    citation: "He, Zhongda; Jia, Yuecheng; Shen, Mi; and Yang, Yuqing (2025). Salience Theory and the Returns of Commodity Futures. Author-uploaded academic preprint dated 2025-02-03."
    location: "Complete 52-page paper; Sections 2-6, Equations 2-5, Tables 1-12, Appendices A1-A5; DOI https://doi.org/10.13140/RG.2.2.26815.83364"
    quality_tier: B
    role: primary
  - type: paper
    citation: "Cosemans, Mathijs and Frehen, Rik (2021). Salience Theory and Stock Prices: Empirical Evidence. Journal of Financial Economics 140, 460-483."
    location: "Peer-reviewed salience-weight methodology supplement; https://ssrn.com/abstract=2887956"
    quality_tier: A
    role: supplement
strategy_type_flags: [symmetric-long-short, atr-hard-stop, time-stop]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13142_XTI_XNG_SAL_D1
period: D1
expected_trade_frequency: "One XTI/XNG salience package each broker calendar month after at least 15 synchronized observations in the immediately prior complete month; approximately 12 packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.02
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Falsify whether a fixed four-CFD reference payoff and two-energy-CFD rank preserve the source's monthly high-minus-low salience premium. The driver is context-relative payoff salience; realized book orthogonality is unclaimed until Q09."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, benchmark_proxy, low_frequency, narrow_cross_section, preprint_source]
g0_approval_reasoning: "OWNER mission-directed G0 approval: complete primary-source review plus peer-reviewed method supplement; locked one-complete-month four-CFD panel, theta 0.1, delta 0.7, deterministic salience ranks, population covariance, high-ST direction, monthly paired hold, equal-notional guard, fixed-risk ATR stops, restart guard, and orphan cleanup; native registered D1 data, no ML/banned/external/grid/martingale logic. Preprint status, broad-universe substitution, four-CFD benchmark, and two-CFD breadth remain binding Q02 kill risks."
---

# XTI/XNG Monthly Commodity-Salience Rank

## Hypothesis

Commodity investors may demand compensation for holding contracts whose most
attention-grabbing recent payoffs were positive relative to the same-day
commodity opportunity set. The source reports a positive cross-sectional
relation between its salience-theory statistic and next-month commodity-futures
returns. This card expresses that structure as a monthly energy package: buy
the higher-ST XTI/XNG leg and short the lower-ST leg.

The package is opposite-side and approximately equal-notional, not guaranteed
beta, factor, or dollar neutral. Its driver is the covariance of deterministic
salience weights with prior-month returns, not RSI, trend, seasonality, raw
skew, extreme-return rank, volatility, liquidity, or price-ratio reversion.
Only later portfolio evidence may establish realized correlation to the
certified XAU/SP500/NDX/XNG book.

## Source And Evidence Boundary

The canonical primary source is He, Jia, Shen, and Yang (2025), DOI
`10.13140/RG.2.2.26815.83364`. The complete 52-page author-uploaded paper,
tables, appendices, and references were reviewed end to end. It:

- studies a liquid commodity-futures universe that explicitly includes light
  crude oil and natural gas;
- defines daily payoff salience relative to the unweighted same-day
  cross-sectional mean return with `theta=0.1`;
- ranks days from most to least salient, distorts equal probabilities with
  `delta=0.7`, and defines ST as covariance of weights and returns; and
- ranks contracts monthly, long high ST and short low ST for the next month.

The source is a primary academic preprint, not peer-reviewed. Cosemans and
Frehen (2021), *Journal of Financial Economics* 140, is the peer-reviewed
methodology supplement. The EA substitutes a fixed equal-weight
XTI/XNG/XAU/XAG reference payoff and trades only the two energy legs. It is a
new carrier falsification, not a replication. No source performance, alpha,
drawdown, correlation, or cost number is imported.

## Concept And Formula

On the first tradable `XTIUSD.DWX` D1 bar of a broker month, collect timestamps
common to all four symbols from the immediately preceding complete broker
calendar month. Use simple close-to-close returns and exclude the open bar and
all current-month returns. For each common date:

    r_bar[d] = 0.25 * (r_XTI[d] + r_XNG[d] + r_XAU[d] + r_XAG[d])

For each energy leg `i`:

    sigma_i[d] = abs(r_i[d] - r_bar[d]) /
                 (abs(r_i[d]) + abs(r_bar[d]) + theta)

Rank dates by descending `sigma_i`, assigning `k=1` to the most salient.
Exact numerical ties are resolved deterministically by array order; ties are
expected to be rare and the rule never consults future data.

    omega_i[d] = delta ^ k_i[d] / mean(delta ^ k_i[all dates])
    ST_i = cov_population(omega_i[d], r_i[d])

Direction is locked:

- `ST_XTI > ST_XNG`: BUY XTI and SELL XNG.
- `ST_XTI < ST_XNG`: SELL XTI and BUY XNG.
- tie within `1e-12` or invalid data: remain flat.

## Rules

The locked rule is a monthly high-ST-long/low-ST-short energy package using
the source's daily payoff-salience transform, rank-normalized probability
weights, and covariance statistic. Detailed entry, exit, filter, and
management rules follow.

## Markets And Timeframe

- Logical basket: `QM5_13142_XTI_XNG_SAL_D1`.
- Host and traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Read-only reference members: `XAUUSD.DWX`, `XAGUSD.DWX`, D1.
- Formation: exactly the immediately prior complete broker month; current
  month and current D1 bar are excluded.
- Rebalance: first tradable D1 bar of every broker month.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, bounded across both legs.
- Runtime data: MT5-native D1 time/close, ATR, spread, broker calendar, deal
  history, position state, and contract metadata only.

## 4. Entry Rules

- Require exact host `XTIUSD.DWX`, timeframe D1, and magic slot 0.
- Detect a monthly transition from the current and prior completed host bars.
- Load at most `strategy_history_bars=80` completed D1 bars for all four
  registered symbols and retain only timestamps common to all four histories.
- Require the immediately prior month key and at least
  `strategy_min_return_observations=15` synchronized simple returns.
- Reject nonpositive prices, mismatched return intervals, nonfinite arithmetic,
  invalid theta/delta, invalid rank normalization, or a numerical ST tie.
- Buy the higher-ST energy leg and short the lower-ST leg.
- Reject missing ATR, excess spread, invalid lot metadata, post-rounding
  notional mismatch above 20%, an existing package, or a month already entered.
- Scan current positions and entry deals so restart or one-leg stop cannot
  create another package in the same month.
- Split the fixed package stop-risk to target equal dollar notional after
  broker volume-step rounding and attach frozen `ATR(20) * 3.5` hard stops.
- If the second order fails, flatten the first leg immediately.

## 5. Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month before
  evaluating a replacement package.
- Close both legs after `strategy_max_hold_days=40` as a stale time stop.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source-aligned monthly hold.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Locked formation window, theta/delta, exact host, synchronized history,
  prior-month coverage, observation count, rank normalization, spread, ATR,
  lot, notional, prior-attempt, magic, and composition checks fail closed.
- News compliance gates new entries for both traded symbols; lifecycle
  management and orphan cleanup remain active. Q02 disables both news axes.

## 7. Trade Management Rules

- Exactly two opposite-side energy legs with approximately equal notional and
  one shared fixed-risk budget.
- Close both legs together at monthly reset or 40-day stale limit; flatten any
  orphan or invalid composition on the next tick.
- No TP, trail, break-even, partial close, scale-in, grid, martingale,
  pyramiding, regression, PCA, external feed, adaptive PnL fit, banned
  indicator, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_formation_months` | 1 | [1] | source baseline complete-month window |
| `strategy_history_bars` | 80 | [60, 80, 100] | bounded D1 retrieval buffer only |
| `strategy_min_return_observations` | 15 | [15, 18, 20] | synchronized-data floor |
| `strategy_salience_theta` | 0.1 | [0.1] | source payoff-salience denominator constant |
| `strategy_salience_delta` | 0.7 | [0.7] | source probability-distortion constant |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_notional_mismatch_pct` | 20.0 | [10.0, 20.0, 30.0] | post-rounding neutrality guard |
| `strategy_max_hold_days` | 40 | [40] | stale guard around monthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG entry spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The immediately prior complete month, simple returns, equal-weight four-CFD
reference payoff, `theta=0.1`, descending salience ranks, `delta=0.7`, weight
normalization, population covariance, high-minus-low direction, monthly
renewal, paired carrier, equal-notional target, and no same-month re-entry are
locked. Changing any requires a new card and full pipeline run.

## Author Claim

The authors "document a significant positive association between ST and
commodity futures returns" (abstract). This source claim motivates a queue
candidate; it is not evidence for the two-CFD proxy carrier.

## Risk

### Initial Risk Profile And Kill Criteria

- `expected_pf: 1.02` is a low queue-ordering prior, not evidence.
- `expected_dd_pct: 30.0` reflects XNG gaps, legging, preprint uncertainty,
  reference-payoff endogeneity, two-name rank, CFD basis, and month holds.
- Expected frequency is 12 packages/year after warm-up. Retire below five
  completed packages/year under the binding Q02 economic floor.
- Fail Q02 on zero trades, invalid logical-basket accounting, persistent
  notional mismatch, nondeterminism, orphan persistence, or risk-mode mismatch.
- Do not widen the universe opportunistically, change theta/delta, reverse the
  commodity-specific direction, add MAX/skew confirmation, shorten the hold,
  or relax the neutrality guard to rescue a weak baseline.

## Strategy Allowability Check

- [x] Mechanical structural cross-sectional salience-risk-premium thesis.
- [x] Complete primary academic source plus peer-reviewed method supplement;
      preprint status is explicit and not presented as Tier A.
- [x] No ML, PCA, density fit, external feed, futures curve, grid, martingale,
      pyramiding, banned indicator, or adaptive PnL fitting.
- [x] D1/monthly expected density is 12 packages/year before Q02 validation.
- [x] Backtests use RISK_FIXED; no live setfile is authorized.
- [x] Friday-close exception is source-aligned and documented.
- [x] Canonical dedup fuzzy hits were manually reviewed and found mechanically
      distinct before atomic allocation.

## Non-Duplicate Decision

- `QM5_13118_energy-skew-rank`: raw third moment, not salience weights.
- `QM5_13129_energy-rsj`: realized semivariance imbalance, not salience.
- `QM5_13130_xti-xng-lowmax`: direct extreme-return rank, not context-relative
  payoff salience or covariance.
- `QM5_13131_energy-kurt-rank`: fourth moment, not rank-weight covariance.
- `QM5_13133_energy-ivol`: residual dispersion, not salience.
- `QM5_13139_energy-cv-rank`: 36-month variance/mean ratio, not daily ST.
- `QM5_13140_energy-aliq-rank`: return per tick-volume activity, not ST.
- `QM5_13141_energy-ie-rank`: residual tail probability, not ST.
- `QM5_12567_cum-rsi2-commodity`: short-horizon long-only RSI pullback.

The dedup checker returned only fuzzy slug-token matches to CV, IE, and value
ranks. Manual signal-input, transform, direction, window, and exit review
verdict: `CLEAN_AFTER_MANUAL_REVIEW`.

## Framework Alignment

- no_trade: exact host/slot, locked estimator, synchronized bounded history,
  prior-month coverage, observation floor, rank normalization, spread, ATR,
  lot, notional, current-month attempt, magic, and package guards.
- trade_entry: prior-month salience-weight covariance rank, equal-notional risk
  translation, paired orders, and frozen hard stops.
- trade_management: broker-month reset, 40-day stale close, restart-safe deal
  guard, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

No T_Live, AutoTrading setting, live setfile, deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial monthly XTI/XNG salience-rank basket | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-11 | APPROVED by OWNER mission directive | this card |
| Q01 Build Validation | 2026-07-11 | PENDING | `artifacts/qm5_13142_build_result.json` |
| Q02 Baseline Screening | 2026-07-11 | PENDING | `docs/ops/evidence/2026-07-11_qm5_13142_energy_salience_rank_q02_enqueue.md` |

## Lessons Captured

- 2026-07-11: Salience is mechanically distinct from MAX and skew only when
  the same-date reference payoff, date ranking, normalized delta weights, and
  weight-return covariance remain explicit and locked.
