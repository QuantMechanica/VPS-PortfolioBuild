---
strategy_id: HOLLSTEIN-AGGVOL-2021_XTI_XNG_S01
source_id: HOLLSTEIN-AGGVOL-2021
ea_id: QM5_13151
slug: energy-volbeta
status: APPROVED
created: 2026-07-12
created_by: Research
last_updated: 2026-07-12
g0_status: APPROVED
source_citations:
  - type: peer_reviewed_paper
    citation: "Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), article 2150017."
    location: "Complete 57-page accepted manuscript and online appendix; especially pp. 5-12, Appendix B pp. 26-27, Table 4 Panel A, and Online Appendix Tables A1 and A3-A5; DOI https://doi.org/10.1142/S2010139221500178; https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf"
    quality_tier: A
    role: primary
strategy_type_flags: [symmetric-long-short, atr-hard-stop, time-stop]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13151_XTI_XNG_VBETA_D1
period: D1
expected_trade_frequency: "One XTI/XNG smooth-volatility-beta package per broker calendar month after 273 completed synchronized D1 closes; approximately 12 completed packages/year before Q02 validation."
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
review_focus: "Falsify whether the source's positive continuous aggregate-volatility-sensitivity premium survives as an OHLC-only common-energy smooth-volatility-beta rank. This is not jump beta, volatility-of-volatility, total beta, residual volatility, ratio reversion, return-sign momentum, or the incumbent XNG RSI pullback. Realized book orthogonality remains unclaimed until Q09."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, option_realized_proxy, low_frequency, narrow_cross_section]
g0_approval_reasoning: "APPROVED under the OWNER commodity-sleeve mission: R1 peer-reviewed primary source with complete institutional text; R2 locked 252-observation regression plus 20-return realized-volatility warm-up, inverse-vol energy benchmark, two-sigma jump exclusion, market-controlled OLS smooth-volatility beta, high-minus-low monthly basket, hard stops, and lifecycle guards; R3 registered native XTI/XNG D1 data; R4 no ML, banned indicator, external runtime feed, grid, martingale, or pyramiding. Exact/fuzzy text and manual mechanic review are clean. The option-factor-to-realized-volatility substitution, endogenous two-name factor, return-based jump exclusion, continuous-CFD basis, and legging are binding Q02 kill risks."
---

# XTI/XNG Monthly Smooth-Volatility Beta Rank

## Hypothesis

The primary paper reports a positive high-minus-low return when commodities
are ranked by sensitivity to its continuous aggregate-volatility factor. This
card tests a price-native energy carrier: buy the XTI/XNG leg with higher
incremental sensitivity to changes in smooth common energy volatility and
short the lower-sensitivity leg for one broker month.

Opposite directions and equal fixed-risk halves reduce common energy
direction. They do not guarantee dollar, beta, volatility, factor, or realized
market neutrality. Q09 alone may establish correlation to the certified
XAU/SP500/NDX/XNG book after the strategy survives its own gates.

## Source And Evidence Boundary

The canonical source is Hollstein, Prokopczuk, and Tharann (2021),
*Quarterly Journal of Finance* 11(4), article 2150017. It studies 26 commodity
futures, explicitly includes WTI and natural gas, forms monthly
characteristic-sorted portfolios, and estimates aggregate-volatility
sensitivity from the prior twelve months of daily observations while
controlling for the market return.

The continuous aggregate-volatility-beta sort reports a positive 3.56%
annualized high-minus-low return in the source baseline. It does not clear the
paper-wide multiple-testing threshold. The source factor is option-derived
and market-wide; Darwinex CFD runtime cannot reproduce it. This card therefore
uses a disclosed realized common-energy proxy. It is a falsification, not a
replication. No source performance or correlation statistic enters the QM
prior or acceptance gates.

## Concept And Formula

On the first tradable D1 host bar of broker month t, load exactly 273
synchronized completed D1 closes for each leg and calculate 272 simple returns
from oldest to newest. Use the latest 252 returns to lock inverse-volatility
benchmark weights, its mean, and its sample standard deviation:

```text
vol_i      = sample_std(r_i, latest 252 observations)
w_i        = (1 / vol_i) / sum_j(1 / vol_j)
energy_d   = w_XTI * r_XTI,d + w_XNG * r_XNG,d
mu_energy  = average(energy_d over latest 252 observations)
sd_energy  = sample_std(energy_d over latest 252 observations)
rv20_d     = sample_std(energy_[d-19:d])

smooth_d = rv20_d - rv20_[d-1]
           if abs(energy_d - mu_energy) < 2.0 * sd_energy
           else 0
```

Estimate separately for each leg using the latest 252 observations:

```text
r_i,d = alpha_i + beta_energy_i * energy_d
                  + beta_smooth_i * smooth_d + epsilon_i,d
```

- Require at least 200 observations not excluded as return jumps.
- `beta_smooth_XTI > beta_smooth_XNG`: BUY XTI and SELL XNG.
- `beta_smooth_XTI < beta_smooth_XNG`: SELL XTI and BUY XNG.
- Numerical tie, singular regression, invalid synchronized history, or
  insufficient smooth observations: remain flat.

## Markets And Timeframe

- Logical basket: `QM5_13151_XTI_XNG_VBETA_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Formation: 272 synchronized completed D1 simple returns; current bars are
  excluded; the regression uses 252 observations after 20-return warm-up.
- Rebalance: first tradable D1 host bar of each broker month.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally across both traded legs.
- Runtime data: native MT5 D1 time/close, ATR, spread, broker calendar, deal
  history, position state, and contract metadata only.

## Rules

The entry, exit, filter, and lifecycle rules below are the complete authorized
baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Require exact host `XTIUSD.DWX`, timeframe D1, and magic slot 0.
- Detect the first tradable host D1 bar of each broker month using framework
  calendar helpers; do not depend on unavailable custom-symbol MN1 bars.
- Load exactly 273 completed synchronized D1 closes for both legs; require the
  newest signal endpoint to predate the decision bar and be no more than ten
  calendar days old.
- Calculate 272 simple returns, then use the latest 252 observations for
  per-leg sample volatility, fixed inverse-volatility benchmark weights,
  benchmark mean, and sample standard deviation.
- Calculate a 20-return rolling benchmark standard deviation. Set its daily
  change to zero when the same day's benchmark-return innovation is at least
  two benchmark standard deviations in magnitude.
- Require at least 200 non-jump observations and estimate a deterministic
  intercept/benchmark-return/smooth-volatility OLS for each leg.
- Buy the higher smooth-volatility-beta leg and short the lower-beta leg;
  reject a numerical tie or singular/invalid regression.
- Reject invalid history, prices, arithmetic, ATR/lot metadata, excess spread,
  an existing package, or a broker month already entered.
- Scan positions and entry deals so restart or a stopped leg cannot create a
  second package in the same month.
- Split fixed package risk equally and attach a frozen `ATR(20) * 3.5` hard
  stop to each leg. If the second order fails, flatten the first immediately.

## 5. Exit Rules

- Close both legs on the first tradable D1 host bar of the next broker month
  before evaluating a replacement package.
- Close both legs after `strategy_max_hold_days=40` as a stale time stop.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source-aligned monthly hold.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Locked formation, realized-volatility window, jump threshold, minimum smooth
  count, exact host, bounded completed-bar history, endpoint freshness,
  synchronized timestamps, finite arithmetic, nonsingular OLS, spread, ATR,
  lot, month-attempt, magic, and package checks fail closed.
- News compliance gates new entries for both symbols; lifecycle management and
  orphan cleanup remain active. Q02 disables both news axes.

## 7. Trade Management Rules

- Exactly two opposite-side legs use equal fixed-risk shares.
- One paired package per broker month; a stopped or missing leg does not
  authorize same-month re-entry.
- No TP, trail, break-even, partial close, scale-in, grid, martingale,
  pyramiding, external feed, option data, banned indicator, adaptive PnL fit,
  or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_lookback_d1` | 252 | [252] | locked regression observations |
| `strategy_rv_window_d1` | 20 | [20] | locked realized-volatility window |
| `strategy_jump_exclusion_z` | 2.0 | [2.0] | locked return-jump exclusion |
| `strategy_min_smooth_days` | 200 | [200] | locked regression-information floor |
| `strategy_history_bars` | 360 | [330, 360, 450] | bounded retrieval buffer only |
| `strategy_max_endpoint_gap_days` | 10 | [7, 10] | completed-endpoint freshness guard |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 40 | [40] | stale guard around monthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The 252-observation regression, 20-return warm-up, inverse-vol benchmark,
two-sigma jump exclusion, 200-observation floor, return-factor control, OLS
smooth-volatility coefficient, high-minus-low direction, monthly renewal,
equal half-risk package, and no same-month re-entry are locked. Changing any
requires a new card and full pipeline run.

## Risk And Kill Criteria

- `expected_pf: 1.02` is a low queue-ordering prior, not evidence.
- `expected_dd_pct: 30.0` reflects XNG gaps, legging, proxy/endogeneity risk,
  regression instability, continuous-CFD basis, and monthly holds.
- Expected density is twelve packages/year after warm-up. Retire below five
  completed packages/year under the binding Q02 economic floor.
- Fail Q02 on zero trades, invalid logical-basket accounting, nondeterminism,
  persistent orphan exposure, stale history, or risk mismatch.
- Do not reverse direction, include return-jump volatility changes, substitute
  total beta or volatility-of-volatility, add directional momentum, or relax
  synchronization/package guards to rescue weak economics.
- The option-to-realized substitution, endogenous factor, narrow rank, source
  endpoint, futures/CFD basis, gaps, legging, and costs are kill risks, never
  waiver grounds.

## Strategy Allowability Check

- [x] Mechanical structural common smooth-volatility-risk thesis.
- [x] Peer-reviewed primary source with DOI and complete institutional text.
- [x] No banned indicator, ML, external runtime feed, options, grid,
      martingale, pyramiding, or adaptive PnL fitting.
- [x] D1/monthly expected density is twelve packages/year before Q02.
- [x] Backtests use RISK_FIXED; no live setfile is authorized.
- [x] Friday-close exception is source-aligned and documented.
- [x] Canonical text dedup plus manual mechanic review is clean.

## Non-Duplicate Decision

- `QM5_13147_energy-jumpbeta`: regression exposure to extreme common-return
  days, low beta long. This card excludes those days from the volatility
  innovation and holds high smooth-volatility beta long.
- `QM5_13146_energy-vov`: dispersion of each leg's own rolling volatility
  level, not its controlled sensitivity to changes in common volatility.
- `QM5_13132_energy-bab`: total return beta with low-beta direction and
  inverse-beta sizing, not a second-factor smooth-volatility coefficient.
- `QM5_13133_energy-ivol`: residual return dispersion, not volatility-factor
  sensitivity.
- XTI/XNG ratio, return-spread, carry, trend, calendar, return-sign momentum,
  and `QM5_12567_cum-rsi2-commodity` use different signals and horizons.

Pre-allocation exact and fuzzy text search plus manual mechanic review found
no smooth aggregate-volatility-beta build. Verdict: `CLEAN_PRE_ALLOCATION`.

## Framework Alignment

- no_trade: exact host/slot, locked estimator, bounded synchronized completed-
  bar history, endpoint freshness, finite arithmetic, nonsingular OLS,
  minimum smooth days, spread, ATR, lot, month-attempt, magic, and package
  guards.
- trade_entry: monthly high-versus-low smooth-volatility-beta rank, paired
  orders, equal fixed-risk allocation, and frozen ATR hard stops.
- trade_management: next-month reset, 40-day stale close, restart-safe deal
  guard, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

No T_Live, AutoTrading setting, live setfile, deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-12 | initial XTI/XNG smooth-volatility-beta proxy | Q02 | Q01 PASS; Q02 ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-12 | APPROVED under OWNER commodity-sleeve mission; R1-R4 and dedup clean | this card |
| Q01 Build Validation | 2026-07-12 | PASS - strict compile 0 errors/0 warnings; validators PASS | `docs/ops/evidence/2026-07-12_qm5_13151_energy_volbeta_q02_enqueue.md` |
| Q02 Baseline Screening | 2026-07-12 | ENQUEUED - pending, attempt 0, unclaimed | work item `d792f306-3b9c-4ff6-b317-61c1137e6c92` |

## Lessons Captured

- 2026-07-12: The edge remains distinct only while the regression controls
  for the common energy return, derives a separate non-jump realized-
  volatility innovation, and preserves the source's high-minus-low direction.
