---
strategy_id: FRAZZINI-BAB-2014_XTI_XNG_S01
source_id: FRAZZINI-BAB-2014
ea_id: QM5_13132
slug: energy-bab
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citation: "Frazzini and Pedersen (2014), Betting Against Beta, Journal of Financial Economics 111(1), 1-25, DOI 10.1016/j.jfineco.2013.10.005; NBER Working Paper 16601."
source_citations:
  - type: peer_reviewed_paper
    citation: "Frazzini, Andrea, and Lasse Heje Pedersen (2014). Betting Against Beta. Journal of Financial Economics 111(1), 1-25."
    location: "Equation 9; Sections II-III; Table II; Table IX; NBER Working Paper 16601 pp. 10-17 and 21-22; DOI https://doi.org/10.1016/j.jfineco.2013.10.005"
    quality_tier: A
    role: primary
sources:
  - "[[sources/FRAZZINI-BAB-2014]]"
concepts:
  - "[[concepts/betting-against-beta]]"
  - "[[concepts/funding-constraints]]"
  - "[[concepts/energy-relative-value]]"
indicators:
  - "[[indicators/dimson-beta]]"
  - "[[indicators/equal-risk-benchmark]]"
  - "[[indicators/atr]]"
strategy_type_flags: [symmetric-long-short, atr-hard-stop, time-stop, signal-reversal-exit]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
markets: [commodities, energy, crude_oil, natural_gas]
single_symbol_only: false
logical_symbol: QM5_13132_XTI_XNG_BAB_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "One monthly beta-matched XTI/XNG package after the 258-close warm-up; approximately 12 completed packages/year."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.03
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Source-backed commodity BAB translation; Q02 must falsify the two-CFD carrier and Q09 alone may establish realized portfolio orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, narrow_cross_section]
g0_approval_reasoning: "OWNER mission 2026-07-11: R1 peer-reviewed JFE/NBER commodity-futures BAB source read in full; R2 locked one-year Dimson beta, 0.5 shrinkage, low-versus-high beta direction, beta-matched sizing, and monthly lifecycle; R3 native registered XTI/XNG D1 data; R4 no ML/banned/external/grid/martingale; manual repository dedup CLEAN before atomic CEO+CTO allocation."
---

# XTI/XNG Betting Against Beta

## Hypothesis

Leverage-constrained investors prefer high-beta instruments because those
instruments provide more unlevered market exposure per dollar. That demand can
make high-beta assets expensive relative to low-beta assets. This card tests
the source's commodity BAB structure inside a paired energy carrier: buy the
lower-beta XTI/XNG leg and short the higher-beta leg, scaling both sides to
approximately equal energy-benchmark beta.

The opposite positions target common energy-direction neutrality, but neither
dollar neutrality nor realized portfolio decorrelation is assumed. Q02 tests
the trading carrier; Q09 alone may establish correlation to the certified
XAU/SP500/NDX/XNG book.

## Source And Evidence Boundary

The primary source is Frazzini and Pedersen (2014), *Journal of Financial
Economics* 111(1), DOI `10.1016/j.jfineco.2013.10.005`, with implementation
details from official NBER Working Paper 16601. The complete September 2010
conference draft was read, including theory, methods, proofs, appendices,
tables, and figures.

The source includes crude oil and natural gas among 24 commodity futures. It
estimates daily-return betas, ranks instruments monthly, and makes each low-
and high-beta portfolio carry beta one before taking the long-short spread.
The source commodity result is positive but statistically weak. This card
does not import any performance number.

## Concept And Non-Duplicate Decision

On the first tradable XTI D1 bar of each broker month:

1. Load synchronized completed D1 closes for XTI and XNG.
2. Form a two-leg inverse-volatility energy benchmark.
3. Estimate each leg's one-year Dimson beta from the current benchmark return
   and five lags, then shrink beta halfway toward one.
4. Buy the lower-beta leg and sell the higher-beta leg.
5. Split fixed stop risk so intended notional exposure is proportional to
   inverse beta; reject excessive post-rounding beta mismatch.
6. Close and renew on the next broker-month transition.

This is mechanically distinct from XTI/XNG momentum, trend, return-spread,
carry, value, same-calendar, skew, kurtosis, MAX, RSJ, momentum-reversal, and
volatility-breakout baskets. Existing BAB builds cover equity indices, while
the existing Carver low-beta relative-value build is registered for indices
and FX only. It contains no RSI and is not `QM5_12567`.

## Markets And Timeframe

- Logical basket: `QM5_13132_XTI_XNG_BAB_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Signal cadence: first tradable D1 bar of each broker month.
- Formation: 257 completed simple returns, yielding 252 regression
  observations after the five-lag buffer.
- Expected density: approximately 12 packages/year after warm-up; retire below
  five completed packages/year.
- Runtime data: native MT5 D1 closes, ATR, spread, contract metadata, broker
  calendar, and framework position/deal state only.

## Rules

The locked rule is monthly low-beta-long/high-beta-short exposure using the
source's daily Dimson estimator and beta-one scaling translated to bounded
fixed-risk CFD orders. The detailed entry, exit, filter, and management rules
follow.

## 4. Entry Rules

- Evaluate only when the current XTI D1 host bar and immediately prior bar
  belong to different broker months.
- Copy exactly `strategy_beta_observations + strategy_dimson_lags + 1`
  synchronized completed closes for both legs.
- Compute simple close-to-close returns and reject nonpositive prices,
  nonfinite arithmetic, or incomplete history.
- Estimate each leg's sample standard deviation over the latest 252 returns.
- Form the equal-risk benchmark return at every observation using fixed
  inverse-volatility weights from those two standard deviations.
- For each leg, regress its latest 252 returns on an intercept, current
  benchmark return, and benchmark lags 1 through 5.
- `raw_beta = sum(the six market-return slopes)`.
- `shrunk_beta = 0.5 * raw_beta + 0.5 * 1.0`.
- Reject a nonpositive beta, singular regression, exact numerical beta tie,
  missing ATR, excessive spread, existing package, or month already attempted.
- Buy the lower shrunk-beta leg and sell the higher shrunk-beta leg.
- Intended notional scale is `1 / shrunk_beta` for each side. With ATR hard
  stops, split fixed risk in proportion to
  `(ATR / entry_price) / shrunk_beta` so pre-rounding notional beta is equal.
- After broker volume-step rounding, calculate each leg's dollar-notional
  proxy times beta. Reject entry if the relative mismatch exceeds 20%.
- Attach a frozen `ATR(20) * 3.5` hard stop to both legs; no take-profit.

## 5. Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month before
  evaluating a replacement package.
- Close both legs after 35 calendar days as a stale-package guard.
- If either stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source's monthly hold.

## 6. Filters (No-Trade Module)

- Exact host guard: XTIUSD.DWX, D1, magic slot 0.
- Locked beta-observation count, Dimson lag count, shrinkage, benchmark
  construction, beta direction, and one-package-per-month lifecycle.
- Parameter, history, covariance, matrix-solve, beta, ATR, volume-step,
  beta-mismatch, spread, and package checks fail closed.
- Framework kill switch and entry-only news compliance remain authoritative.

## 7. Trade Management Rules

- Current positions plus current-month entry-deal history prevent restart from
  bypassing the monthly attempt guard.
- A valid package contains exactly one XTI leg and one XNG leg with opposite
  directions and this EA's registered magics.
- Close both legs on a new broker month, on the stale guard, or whenever the
  package composition becomes invalid.
- No TP, trail, break-even, partial close, scale-in, grid, martingale,
  pyramiding, external data, adaptive fit, banned indicator, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_beta_observations` | 252 | [252] | source one-year daily regression |
| `strategy_dimson_lags` | 5 | [5] | source nonsynchronous-trading correction |
| `strategy_beta_shrink_weight` | 0.5 | [0.5] | source shrinkage toward one |
| `strategy_history_bars` | 320 | [300, 320, 380] | bounded warm-up buffer |
| `strategy_min_beta` | 0.10 | [0.05, 0.10] | fail-closed inverse-beta floor |
| `strategy_max_beta_mismatch_pct` | 20.0 | [10.0, 20.0, 30.0] | post-rounding neutrality guard |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg hard-stop ATR |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | order deviation |

The 252 observations, five benchmark lags, 0.5 shrinkage, equal-risk
benchmark, low-beta-long/high-beta-short direction, inverse-beta notional
target, monthly renewal, paired carrier, and no same-month re-entry are locked.
Changing any requires a new card.

## Author Claim

The source describes BAB as "long a portfolio of low-beta assets" and short
high-beta assets (abstract). No return statistic is imported.

## Initial Risk Profile And Kill Criteria

- `expected_pf: 1.03` is only a conservative queue prior.
- `expected_dd_pct: 30.0` reflects XNG gaps, funding-risk crashes, legging,
  regression noise, and the two-contract narrowing.
- Fail Q02 on fewer than five completed packages/year, zero trades, singular
  or unstable beta construction, persistent beta mismatch, nondeterminism,
  orphan persistence, or risk-mode mismatch.
- Do not shorten the beta window, remove shrinkage, relax the neutrality guard,
  add a directional overlay, or substitute a different benchmark after a poor
  baseline.
- Treat 24-future-to-two-CFD narrowing, benchmark endogeneity, lack of a daily
  risk-free series, and futures/CFD roll/financing differences as
  falsification risks, not waiver grounds.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed JFE paper, official NBER DOI and full text.
- [x] R2 mechanical: fixed regression, shrinkage, ranking, sizing, lifecycle,
  stops, and beta-mismatch guard.
- [x] R3 testable: registered XTIUSD.DWX and XNGUSD.DWX D1 history and broker
  contract metadata.
- [x] R4 compliant: no banned indicator, ML, external feed, grid, martingale,
  or pyramiding.
- [x] Expected source-aligned monthly density exceeds the five-trade Q02 floor.
- [x] Repository dedup was clean before atomic ID allocation.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. The fixed package stop-risk budget is split according to relative ATR
and inverse beta; both legs together remain bounded by the framework budget
before broker rounding. No live setfile, T_Live change, AutoTrading action,
deploy manifest, portfolio gate, or admission artifact is authorized.

## Framework Alignment

- no_trade: exact host/slot, locked estimator, synchronized bounded history,
  matrix condition, beta floor, spread, ATR, broker volume, neutrality, and
  package guards.
- trade_entry: equal-risk benchmark, two Dimson regressions, source shrinkage,
  low/high rank, inverse-beta risk split, paired orders, and hard stops.
- trade_management: monthly reset, 35-day stale close, restart-safe deal guard,
  post-entry composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

## Hard Rules At Risk

- `friday_close`: disabled only because forced weekly flattening conflicts with
  the source's monthly rebalance; later live consideration requires re-review.
- `risk_mode_dual`: Q02 uses only RISK_FIXED and no live setfile exists.
- `magic_schema`: two registered slots are required for the logical package.
- `dwx_suffix_discipline`: both runtime symbols retain `.DWX`.
- `enhancement_doctrine`: any estimator, benchmark, shrinkage, direction, or
  sizing change is a new entry hypothesis and requires a full rerun.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial source-backed energy BAB build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-11 | APPROVED by OWNER mission directive | this card |
| Q01 Build Validation | 2026-07-11 | PASS | `artifacts/qm5_13132_build_result.json` |
| Q02 Baseline Screening | 2026-07-11 | ENQUEUED; pending and unclaimed | work item `92097f32-58bb-4c86-9b54-5ee371716499` |

## Lessons Captured

- 2026-07-11: A two-instrument BAB carrier is mechanically testable, but its
  endogenous benchmark makes Q02 a strict low-volatility/low-beta energy
  falsification rather than evidence inherited from the broad source universe.
