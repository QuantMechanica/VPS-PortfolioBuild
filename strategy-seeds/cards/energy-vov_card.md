---
strategy_id: HOLLSTEIN-VOV-2021_XTI_XNG_S01
source_id: HOLLSTEIN-VOV-2021
ea_id: QM5_13146
slug: energy-vov
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citations:
  - type: peer_reviewed_paper
    citation: "Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), 2150017."
    location: "Complete 57-page accepted manuscript and online appendix; especially pp. 5-9, p. 16, Appendix B p. 29, Table 4 Panel D, and Online Appendix Tables A1, A3-A5; DOI https://doi.org/10.1142/S2010139221500178; https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf"
    quality_tier: A
    role: primary
strategy_type_flags: [vol-regime-gate, atr-hard-stop, time-stop, symmetric-long-short]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13146_XTI_XNG_VOV_D1
period: D1
expected_trade_frequency: "One XTI/XNG realized-volatility-of-volatility package per broker calendar month after 273 completed D1 closes; approximately 12 completed packages/year before Q02 validation."
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
review_focus: "Falsify whether an OHLC-only realized-VoV proxy preserves the source's low-minus-high commodity premium in a paired XTI/XNG carrier. It is not implied VoV, a directional high-volatility fade, raw volatility rank, momentum, ratio reversion, or the incumbent XNG RSI pullback. Realized book orthogonality remains unclaimed until Q09."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, implied_realized_proxy, low_frequency, narrow_cross_section]
g0_approval_reasoning: "APPROVED under the OWNER commodity-sleeve mission: R1 one peer-reviewed source with complete institutional text; R2 locked nested 20-D1 realized-volatility and 252-sample VoV estimator, low-minus-high monthly basket, hard stops, and lifecycle guards; R3 registered native XTI/XNG D1 data; R4 no ML, banned indicator, external runtime feed, grid, martingale, or pyramiding. Canonical exact dedup and manual mechanic review are clean. The implied-to-realized proxy, two-name rank, continuous-CFD basis, and source's weaker modern evidence are binding Q02 kill risks."
---

# XTI/XNG Monthly Realized Volatility-of-Volatility Rank

## Hypothesis

Uncertainty about a commodity's risk can itself be priced. The source finds
that commodities with high option-implied volatility-of-volatility
underperform low-VoV commodities. This card tests a price-native energy
carrier: buy the XTI/XNG leg whose rolling realized volatility is more stable
and short the leg whose rolling realized volatility is less stable.

Opposite directions and equal fixed-risk halves reduce common energy
direction. They do not guarantee dollar, beta, volatility, factor, or realized
market neutrality. Q09 alone may establish correlation to the certified
XAU/SP500/NDX/XNG book after the strategy survives its own gates.

## Source And Evidence Boundary

The sole canonical source is Hollstein, Prokopczuk, and Tharann (2021),
*Quarterly Journal of Finance* 11(4), article 2150017. The complete accepted
manuscript and online appendix were read end to end. It studies 26 commodity
futures, explicitly includes WTI and natural gas, forms monthly cross-sectional
portfolios, and defines VoV as the standard deviation of 252 daily implied-
volatility observations divided by their mean.

The paper's high-minus-low VoV portfolio is negative, including in its
two-portfolio robustness test. Its signal depends on commodity option prices.
Darwinex CFD runtime has no option chain, so this card uses rolling realized
volatility only. This is a disclosed proxy falsification, not a replication.
No source return, alpha, significance, drawdown, cost, or correlation value is
imported into the QM prior.

## Concept And Formula

On the first tradable D1 host bar of broker month t, load 273 completed D1
closes for each energy leg. For each of 252 overlapping endpoints d, calculate
20-return annualized realized volatility:

```text
r[d,k] = log(close[d+k] / close[d+k+1]), k=0..19
rv[d]  = sample_std(r[d,0..19]) * sqrt(252)
```

Apply the source's dispersion-over-mean transform to the resulting 252
realized-volatility estimates:

```text
mean_rv      = average(rv[d], d=0..251)
realized_vov = sqrt(sum((rv[d] - mean_rv)^2) / 252) / mean_rv
```

- `realized_vov_XTI < realized_vov_XNG`: BUY XTI and SELL XNG.
- `realized_vov_XTI > realized_vov_XNG`: SELL XTI and BUY XNG.
- Numerical tie, nonpositive mean/RV variance, missing/stale endpoint, invalid
  arithmetic, or insufficient history: remain flat.

## Markets And Timeframe

- Logical basket: `QM5_13146_XTI_XNG_VOV_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Formation: 252 overlapping realized-volatility samples, each based on 20
  completed D1 log returns; current D1 bars are excluded.
- Rebalance: first tradable D1 host bar of each broker month.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally across both traded legs.
- Runtime data: native MT5 D1 time/close, ATR, spread, broker calendar, deal
  history, position state, and contract metadata only.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Require exact host `XTIUSD.DWX`, timeframe D1, and magic slot 0.
- Detect the first tradable host D1 bar of each new broker month.
- For each leg, load at least 273 completed D1 closes; require the newest
  signal endpoint to predate the decision bar and be no more than ten calendar
  days old.
- Calculate exactly 252 overlapping annualized RV estimates from exactly 20
  log returns each, using sample variance with denominator 19.
- Calculate mean RV and the source-aligned population dispersion-over-mean VoV
  transform with denominator 252.
- Require every RV, mean RV, VoV variance, and final VoV to be positive and
  finite; reject a numerical XTI/XNG tie.
- Buy the lower realized-VoV leg and short the higher realized-VoV leg.
- Reject invalid history, prices, arithmetic, ATR/lot metadata, excess spread,
  existing package, or a broker month already entered.
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
- Locked nested estimator, exact host, bounded completed-bar history, endpoint
  freshness, arithmetic, spread, ATR, lot, month-attempt, magic, and package
  checks fail closed.
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
| `strategy_rv_window_d1` | 20 | [20] | locked completed-return count per RV sample |
| `strategy_vov_samples` | 252 | [252] | source-aligned one-year daily VoV sample count |
| `strategy_history_bars` | 320 | [300, 320, 400] | bounded completed-D1 retrieval buffer only |
| `strategy_max_endpoint_gap_days` | 10 | [7, 10] | completed-endpoint freshness guard |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 40 | [40] | stale guard around monthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The 20-return inner window, 252 overlapping RV samples, sample variance inside
RV, population dispersion across RV, division by mean RV, low-minus-high
direction, monthly renewal, equal half-risk package, and no same-month re-entry
are locked. Changing any requires a new card and full pipeline run.

## Author Claim

The paper reports "sizable premia for ... volatility-of-volatility" (accepted
manuscript abstract, p. 2). This short source claim motivates queue admission;
it does not validate the price-only proxy or two-CFD carrier.

## Initial Risk Profile And Kill Criteria

- `expected_pf: 1.02` is a low queue-ordering prior, not evidence.
- `expected_dd_pct: 30.0` reflects XNG gaps, legging, proxy risk, overlapping-
  window dependence, narrow ranks, continuous-CFD basis, and month holds.
- Expected density is twelve packages/year after warm-up. Retire below five
  completed packages/year under the binding Q02 economic floor.
- Fail Q02 on zero trades, invalid logical-basket accounting, nondeterminism,
  persistent orphan exposure, stale history, or risk mismatch.
- Do not switch to an RV percentile, add a directional stretch/mean-reversion
  trigger, shorten the nested windows, reverse direction, or relax package
  guards to rescue weak economics.
- The implied-to-realized substitution, two-name carrier, source endpoint,
  futures/CFD basis, gaps, legging, and costs are kill risks, never waivers.

## Strategy Allowability Check

- [x] Mechanical structural uncertainty-about-risk thesis.
- [x] One peer-reviewed primary source with DOI, complete institutional text,
      exact source formula, broad portfolio evidence, and robustness tests.
- [x] No banned indicator, ML, external runtime feed, options, grid,
      martingale, pyramiding, or adaptive PnL fitting.
- [x] D1/monthly expected density is twelve packages/year before Q02.
- [x] Backtests use RISK_FIXED; no live setfile is authorized.
- [x] Friday-close exception is source-aligned and documented.
- [x] Canonical dedup plus manual signal/input/window/direction review is clean.

## Non-Duplicate Decision

- `QM5_13046_xti-vrp-proxy`, `QM5_13051_xng-vrp-proxy`, and
  `QM5_13091_xbr-vrp-proxy`: directional high-RV stretch fades with SMA/reversal
  confirmation, not a monthly cross-sectional VoV rank.
- `QM5_13049`-`QM5_13050`, `QM5_13055`-`QM5_13056`, and
  `QM5_13101`-`QM5_13102`: one-week return signals gated by current RV level,
  not instability of the RV path.
- `QM5_13133_energy-ivol`: OLS residual-volatility level against a commodity
  factor, not rolling-volatility dispersion.
- `QM5_13139_energy-cv-rank`: 36 monthly return variance divided by mean
  return, not standard deviation of daily rolling RV divided by mean RV.
- `QM5_13129`, `QM5_13130`, `QM5_13131`, `QM5_13141`, and `QM5_13143`:
  signed semivariance, maximum return, kurtosis, idiosyncratic asymmetry, and
  expected shortfall use different distribution characteristics.
- `QM5_12567_cum-rsi2-commodity`: two-day long-only RSI pullback.

Pre-allocation canonical verdict: no exact duplicate across 4,032 registry
rows and 334 cards. The fuzzy same-source and `energy-*` matches were manually
resolved. Verdict: `CLEAN_AFTER_MANUAL_REVIEW`.

## Framework Alignment

- no_trade: exact host/slot, locked nested estimator, bounded completed-bar
  history, endpoint freshness, positive/finite arithmetic, spread, ATR, lot,
  month-attempt, magic, and package guards.
- trade_entry: monthly low-realized-VoV versus high-realized-VoV rank, paired
  orders, equal fixed-risk allocation, and frozen ATR hard stops.
- trade_management: next-month reset, 40-day stale close, restart-safe deal
  guard, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

No T_Live, AutoTrading setting, live setfile, deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial XTI/XNG realized-VoV rank proxy | Q02 | BUILDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-11 | APPROVED under OWNER commodity-sleeve mission; R1-R4 and dedup clean | this card |
| Q01 Build Validation | 2026-07-11 | PENDING | artifacts/qm5_13146_build_result.json |
| Q02 Baseline Screening | 2026-07-11 | PENDING | docs/ops/evidence/2026-07-11_qm5_13146_energy_vov_q02_enqueue.md |

## Lessons Captured

- 2026-07-11: VoV remains distinct only while the signal is dispersion across
  rolling volatility estimates; replacing it with current RV rank or an RV
  percentile would duplicate existing volatility-regime sleeves.
