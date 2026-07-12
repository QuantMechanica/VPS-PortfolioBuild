---
strategy_id: HOLLSTEIN-DOWNBETA-2021_XTI_XNG_S01
source_id: HOLLSTEIN-DOWNBETA-2021
ea_id: QM5_13203
slug: energy-downbeta
status: APPROVED
created: 2026-07-12
created_by: Research
last_updated: 2026-07-12
g0_status: APPROVED
source_citations:
  - type: peer_reviewed_paper
    citation: "Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), article 2150017."
    location: "Complete 57-page accepted manuscript and online appendix; especially pp. 5-12, Appendix B p. 27, Table 4 Panel B, and Online Appendix Tables A1 and A3-A5; DOI https://doi.org/10.1142/S2010139221500178; https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf"
    quality_tier: A
    role: primary
strategy_type_flags: [symmetric-long-short, atr-hard-stop, time-stop]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
factor_symbols: [SP500.DWX]
read_only_symbols: [SP500.DWX]
single_symbol_only: false
logical_symbol: QM5_13203_XTI_XNG_DOWNBETA_D1
period: D1
expected_trade_frequency: "One XTI/XNG downside-beta package per broker calendar month after 253 completed synchronized XTI/XNG/SP500 D1 closes; approximately 12 completed packages/year before Q02 validation."
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
review_focus: "Strictly falsify an insignificant source sign: low SP500 downside-beta XTI/XNG leg long and high-beta leg short. The paper concludes DownBeta is unpriced; raw SP500/CFD returns, rf=0, the two-name rank, and the backtest-only factor are binding caveats. This is not energy BAB, jump beta, smooth-volatility beta, idiosyncratic volatility, ratio reversion, return-sign momentum, or XNG RSI."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, market_excess_proxy, sp500_read_only_factor, low_frequency, narrow_cross_section]
g0_approval_reasoning: "APPROVED under the OWNER commodity-sleeve mission: R1 peer-reviewed primary source with complete institutional text and appendix, with the paper's null DownBeta conclusion foregrounded; R2 locked 252-return synchronized formation, below-average SP500-return observation mask, intercept OLS, minimum down-day and variance guards, source-sign low-minus-high monthly basket, equal fixed-risk halves, hard stops, and lifecycle guards; R3 registered native XTI/XNG D1 traded data plus read-only backtest SP500.DWX factor; R4 no ML, banned indicator, external runtime feed, grid, martingale, or pyramiding. Targeted exact/fuzzy text and manual mechanic review are clean. The insignificant and unstable source evidence, raw-return/rf=0 and SP500-for-CRSP proxies, two-name narrowing, continuous-CFD basis, factor-history overlap, and legging are binding Q02 kill risks."
---

# XTI/XNG Monthly Downside-Beta Rank

## Hypothesis

The source does not establish a downside-beta premium in commodity futures.
Its high-minus-low DownBeta portfolio is negative but insignificant, so this
card locks the observed sign as a deliberately weak research hypothesis: buy
the XTI/XNG leg with lower sensitivity to SP500 downside days and short the
higher-sensitivity leg for one broker month.

This is a null-prior falsification, not inherited evidence. Opposite
directions and equal fixed-risk halves reduce common energy direction, but do
not guarantee dollar, beta, volatility, equity-factor, or realized market
neutrality. Q09 alone may establish correlation to the certified
XAU/SP500/NDX/XNG book after the strategy survives its own gates.

## Source And Evidence Boundary

The sole canonical source is Hollstein, Prokopczuk, and Tharann (2021),
*Quarterly Journal of Finance* 11(4), article 2150017. It studies 26 commodity
futures, explicitly includes WTI and natural gas, forms monthly
characteristic-sorted portfolios, and estimates downside beta from the prior
twelve months of daily commodity and market excess returns.

The source baseline three-portfolio high-minus-low return is -1.37%
annualized and insignificant; all factor alphas are insignificant. Two-,
four-, and five-portfolio variants preserve a negative sign but remain
insignificant. The Fama-MacBeth slope is essentially zero, and subperiod signs
are unstable. The authors conclude that "downside beta risk appears to be not
priced in the cross-section of commodity returns" (accepted manuscript
p. 12). No source performance or correlation statistic enters the QM prior
or acceptance gates.

## Concept And Formula

On the first tradable D1 host bar of broker month t, load exactly 253
synchronized completed D1 closes for XTIUSD.DWX, XNGUSD.DWX, and read-only
SP500.DWX. Calculate 252 simple returns from oldest to newest:

```text
market_d  = SP500 simple return on completed day d
market_mu = average(market_d, d=1..252)
down_d    = market_d < market_mu

For each energy leg i, using only observations where down_d is true:

mean_x      = average(market_d)
mean_y_i    = average(return_i,d)
market_var  = sum((market_d - mean_x)^2)
beta_down_i = sum((market_d - mean_x) * (return_i,d - mean_y_i))
              / market_var
```

- Require at least 100 qualifying down-market observations.
- `beta_down_XTI < beta_down_XNG`: BUY XTI and SELL XNG.
- `beta_down_XTI > beta_down_XNG`: SELL XTI and BUY XNG.
- Numerical tie, nonpositive selected-market variance, invalid synchronized
  history, or insufficient down-market observations: remain flat.

The source uses commodity-futures excess returns and CRSP total-market excess
return. QM uses raw close-to-close CFD returns, read-only SP500.DWX, and an
implicit zero daily risk-free return. These are disclosed price-native
proxies, not a replication.

## Markets And Timeframe

- Logical basket: `QM5_13203_XTI_XNG_DOWNBETA_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Read-only factor: `SP500.DWX`, D1; never traded and never included in
  package PnL or traded-magic allocation.
- Formation: 252 synchronized completed simple D1 returns; current bars are
  excluded.
- Rebalance: first tradable D1 host bar of each broker month.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally across both traded legs. No percentage-
  risk or live setfile is authorized.
- Runtime data: native MT5 D1 time/close, ATR, spread, broker calendar, deal
  history, position state, and contract metadata only.

## Rules

The entry, exit, filter, and lifecycle rules below are the complete authorized
baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Require exact host `XTIUSD.DWX`, timeframe D1, and traded magic slot 0.
- Detect the first tradable host D1 bar of each broker month using framework
  calendar helpers; do not depend on custom-symbol MN1 bars.
- Load exactly 253 completed D1 closes with matching timestamps for XTI, XNG,
  and SP500; require the newest signal endpoint to predate the decision bar and
  be no more than ten calendar days old.
- Calculate exactly 252 simple returns for all three series. Reject any
  missing, nonpositive, nonfinite, stale, duplicated, or unsynchronized input.
- Average all 252 SP500 returns and retain only observations strictly below
  that average. Require at least 100 retained observations.
- Estimate an intercept and contemporaneous SP500 slope separately for XTI
  and XNG on the identical retained observations. Reject nonpositive selected-
  market variance, nonfinite coefficients, or a beta tie within the locked
  numerical epsilon.
- Buy the lower-downside-beta energy leg and short the higher-beta energy leg.
- SP500.DWX is factor data only. Any code path that attempts to size, order,
  close, assign a traded magic to, or include SP500 in package PnL is invalid.
- Reject invalid ATR/lot metadata, excess spread, an existing package, or a
  broker month already entered. Scan positions and entry deals so restart or
  a stopped leg cannot create a second package in the same month.
- Split `RISK_FIXED` package risk equally and attach a frozen
  `ATR(20) * 3.5` hard stop to each traded leg. If the second order fails,
  flatten the first immediately.

## 5. Exit Rules

- Close both traded legs on the first tradable D1 host bar of the next broker
  month before evaluating a replacement package.
- Close both legs after `strategy_max_hold_days=40` as a stale time stop.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic traded-package
  composition. SP500 is never part of an open package.
- Friday close is disabled only to preserve the source-aligned monthly hold.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Locked formation, exact factor identity, minimum down-day count, exact
  host, bounded completed-bar history, endpoint freshness, synchronized
  timestamps, finite arithmetic, positive regression variance, beta tie,
  spread, ATR, lot, month-attempt, magic, and package checks fail closed.
- SP500.DWX must be readable as a factor but must never be tradable by this EA.
- News compliance gates new entries for both traded symbols; lifecycle
  management and orphan cleanup remain active. Q02 disables both news axes.

## 7. Trade Management Rules

- Exactly two opposite-side traded legs use equal `RISK_FIXED` shares.
- One paired package per broker month; a stopped or missing leg does not
  authorize same-month re-entry.
- The factor is recomputed only for a new monthly decision and never changes
  an open package mid-month.
- No TP, trail, break-even, partial close, scale-in, grid, martingale,
  pyramiding, external feed, banned indicator, adaptive PnL fit, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_lookback_d1` | 252 | [252] | locked source formation observations |
| `strategy_min_down_days` | 100 | [100] | locked regression-information floor |
| `strategy_beta_tie_epsilon` | 1e-8 | [1e-8] | locked numerical no-trade guard |
| `strategy_history_bars` | 420 | [360, 420, 500] | bounded retrieval buffer only |
| `strategy_max_endpoint_gap_days` | 10 | [7, 10] | completed-endpoint freshness guard |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 40 | [40] | stale guard around monthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The 252-return formation, SP500 factor, below-average-market observation mask,
100-observation floor, intercept OLS, no beta shrinkage or lags,
low-minus-high direction, monthly renewal, equal half-risk package, read-only
factor contract, and no same-month re-entry are locked. Changing any requires
a new card and full pipeline run.

## Author Claims

The source states that "downside beta risk appears to be not priced in the
cross-section of commodity returns" (accepted manuscript p. 12). Its abstract
and conclusion likewise classify downside beta among the unpriced or near-
zero commodity characteristics. These are adverse source findings and are
retained as the card's central prior.

## Risk And Kill Criteria

- `expected_pf: 1.01` is a near-null queue-ordering prior, not evidence.
- `expected_dd_pct: 30.0` reflects XNG gaps, legging, conditional-regression
  noise, factor proxy and overlap risk, narrow ranking, continuous-CFD basis,
  and monthly holds.
- Expected density is twelve packages/year after warm-up. Retire below five
  completed packages/year under the binding Q02 economic floor.
- Fail Q02 on zero trades, invalid logical-basket accounting,
  nondeterminism, persistent orphan exposure, stale or unsynchronized factor
  history, any SP500 trade attempt, or risk mismatch.
- Do not reverse direction after seeing Q02, change the down-market threshold,
  add market lags or beta shrinkage, use all market days, substitute an energy
  benchmark, relax the observation floor, or add directional momentum to
  rescue weak economics.
- The source null, unstable subperiods, raw-return/rf=0 proxy, SP500-for-CRSP
  proxy, later factor history, narrow rank, futures/CFD basis, gaps, legging,
  and costs are kill risks, never waiver grounds.

## Strategy Allowability Check

- [x] Mechanical structural conditional-beta hypothesis.
- [x] Peer-reviewed single primary source with DOI and complete institutional
      text plus online appendix.
- [x] Source-null evidence is explicit and no performance is imported.
- [x] No banned indicator, ML, external runtime feed, grid, martingale,
      pyramiding, or adaptive PnL fitting.
- [x] D1/monthly expected density is twelve packages/year before Q02.
- [x] Backtests use RISK_FIXED only; no live setfile is authorized.
- [x] SP500.DWX is read-only/backtest-only and Friday-close exception is
      documented.
- [x] Targeted text dedup plus manual mechanic review is clean.

## Non-Duplicate Decision

- `QM5_13132_energy-bab`: unconditional five-lag Dimson beta to an endogenous
  energy benchmark, shrinkage toward one, and inverse-beta sizing. DownBeta
  uses contemporaneous read-only SP500 returns only on below-average market
  days, no shrinkage, and equal fixed-risk sizing.
- `QM5_13147_energy-jumpbeta`: incremental realized common-jump sensitivity
  after controlling for common energy return, not conditional SP500 beta.
- `QM5_13151_energy-volbeta`: incremental sensitivity to changes in common
  smooth realized volatility, not a one-factor downside-market regression.
- `QM5_13133_energy-ivol`: residual-return dispersion rather than conditional
  systematic slope.
- XTI/XNG ratio, return-spread, carry, trend, calendar, return-sign momentum,
  and `QM5_12567_cum-rsi2-commodity` use different signals and horizons.

Targeted exact/fuzzy text, slug, and strategy-ID search plus manual mechanic
review found no downside-beta commodity implementation. Verdict:
`CLEAN_PRE_ALLOCATION`.

## Framework Alignment

- no_trade: exact host/slot/factor, locked estimator, bounded synchronized
  completed-bar history, endpoint freshness, minimum down days, finite
  arithmetic, positive selected-market variance, beta tie, spread, ATR, lot,
  month-attempt, magic, package, and read-only-factor guards.
- trade_entry: monthly lower-versus-higher SP500 downside-beta rank, two
  opposite orders, equal fixed-risk allocation, and frozen ATR hard stops.
- trade_management: next-month reset, 40-day stale close, restart-safe deal
  guard, composition validation, read-only-factor invariant, and orphan
  cleanup.
- trade_close: framework close helper plus broker-side hard stops on XTI/XNG
  only.

No T_Live, AutoTrading setting, live setfile, deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-12 | initial XTI/XNG SP500-downside-beta proxy | Q02 | Q01 PASS; Q02 ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-12 | APPROVED under OWNER commodity-sleeve mission; R1-R4 and dedup clean | this card |
| Q01 Build Validation | 2026-07-12 | PASS - strict compile 0 errors/0 warnings; validators PASS | `docs/ops/evidence/2026-07-12_qm5_13203_energy_downbeta_q02_enqueue.md` |
| Q02 Baseline Screening | 2026-07-12 | ENQUEUED - pending, attempt 0, unclaimed | work item `503e2088-87a8-4663-8cec-a105bae90bfb` |

## Lessons Captured

- 2026-07-12: DownBeta remains a distinct null-prior test only while the
  observation mask is tied to below-average read-only SP500 returns, the
  estimator remains contemporaneous and unshrunk, and low-minus-high is not
  changed after seeing Q02.
