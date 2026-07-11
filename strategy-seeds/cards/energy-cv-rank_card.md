---
strategy_id: SZYMANOWSKA-CV-2014_XTI_XNG_S01
source_id: SZYMANOWSKA-CV-2014
ea_id: QM5_13139
slug: energy-cv-rank
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citations:
  - type: paper
    citation: "Szymanowska, Marta; de Roon, Frans; Nijman, Theo; and van den Goorbergh, Rob (2014). An Anatomy of Commodity Futures Risk Premia. The Journal of Finance 69(1), 453-482."
    location: "Complete 45-page paper; especially the data and portfolio-construction sections, PDF p. 20, Appendix B PDF p. 30, and Table III PDF p. 40; DOI https://doi.org/10.1111/jofi.12096"
    quality_tier: A
    role: primary
strategy_type_flags: [atr-hard-stop, time-stop, symmetric-long-short]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13139_XTI_XNG_CV_D1
period: D1
expected_trade_frequency: "One XTI/XNG CV package every two broker months after 37 completed month-end closes; approximately 6 packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.03
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Falsify a 36-month coefficient-of-variation risk premium in a two-leg energy carrier. The source's broad futures cross-section, maturity decomposition, and pre-2011 sample do not establish efficacy or orthogonality for two continuous CFDs."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, low_frequency, narrow_cross_section]
g0_approval_reasoning: "OWNER mission-directed G0 approval on 2026-07-11: complete peer-reviewed primary-source review; exact prior-36-month normalized-variance rank, bimonthly paired hold, equal fixed risk, ATR hard stops, restart-safe no-reentry; native registered XTI/XNG D1 data; no ML/banned/external/grid/martingale logic. Manual dedup review CLEAN before atomic QM5_13139 allocation. The two-CFD carrier and absent futures-maturity decomposition remain binding Q02 kill risks."
---

# XTI/XNG Bimonthly Coefficient-of-Variation Rank

## Hypothesis

Commodity futures with high trailing spot-price risk relative to their average
return may command a risk premium. This card translates the source's
coefficient-of-variation characteristic to a symmetric energy package: buy the
higher 36-month CV leg and short the lower CV leg for two broker months.

The edge is structural and low frequency. It is not a claim that XTI and XNG
are cointegrated, nor that their dollar notionals or betas are identical.
Equal fixed-risk legs reduce outright direction, while Q09 alone may determine
realized portfolio correlation after the strategy survives its own gates.

## Source And Evidence Boundary

The sole canonical source is Szymanowska, de Roon, Nijman, and van den
Goorbergh (2014), *The Journal of Finance* 69(1), DOI
`10.1111/jofi.12096`. The complete paper, appendices, and tables were reviewed
end to end. The paper:

- uses 21 commodity futures from seven sectors;
- forms four characteristic portfolios at a bimonthly cadence;
- defines CV from variance scaled by mean return over months `t-36` to `t-1`;
- links higher CV to higher expected futures returns; and
- decomposes returns across spot, term, and maturity components unavailable in
  a continuous-CFD carrier.

The source sample ends in 2010 and its result is a broad cross-sectional
futures result. No source return, alpha, drawdown, correlation, or cost result
is imported. The 2017+ Darwinex baseline is a new falsification test.

## Concept And Formula

On the first tradable `XTIUSD.DWX` D1 bar of each odd-numbered broker month,
reconstruct the most recent 37 completed month-end closes for both energy legs.
For leg `i`, calculate 36 monthly log returns and:

```text
r_i[m]       = log(month_close_i[m] / month_close_i[m-1])
mu_i         = sum(r_i[m]) / 36
variance_i   = sum((r_i[m] - mu_i)^2) / 35
CV_i         = variance_i / abs(mu_i)
```

The absolute denominator is the sign-safe implementation of a nonnegative
coefficient-of-variation risk measure. It prevents a negative average return
from reversing the source's risk rank. Direction is fixed:

- `CV_XTI > CV_XNG`: BUY XTI and SELL XNG.
- `CV_XTI < CV_XNG`: SELL XTI and BUY XNG.
- Numerical tie, `abs(mu) <= 1e-12`, nonpositive variance, invalid arithmetic,
  incomplete history, or a missing calendar month: remain flat.

January, March, May, July, September, and November are the deterministic
bimonthly anchor. This extends the source's March-start sample cadence without
adding a fitted calendar axis.

## Rules

### Markets And Timeframe

- Logical basket: `QM5_13139_XTI_XNG_CV_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Formation: 37 completed month-end closes and exactly 36 monthly log returns;
  the current D1 bar and current month are excluded.
- Rebalance: first tradable D1 bar of each odd-numbered broker month.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally across the legs.
- Runtime data: MT5-native D1 closes, ATR, spread, broker calendar, deal
  history, and position state only.

## 4. Entry Rules

- Require exact host `XTIUSD.DWX`, timeframe D1, and magic slot 0.
- Detect a qualifying month transition by comparing the current host D1 bar's
  month with the preceding completed host bar's month.
- Collect the last completed D1 close from each of 37 consecutive broker
  months for both legs; fail closed if any whole month is absent.
- Compute the locked formula and buy higher CV while shorting lower CV.
- Reject a numerical tie, missing/nonpositive close, nonpositive variance,
  near-zero mean, invalid arithmetic, incomplete history, invalid ATR/price/
  lot metadata, excess spread, existing package, or period already entered.
- Scan current positions and entry deals so restart or a stopped leg cannot
  create another package in the same two-month period.
- Split fixed package risk equally and attach a frozen
  `ATR(20) * 3.5` hard stop to each leg.
- If the second order fails, immediately flatten the first leg.

## 5. Exit Rules

- Close both legs on the first tradable D1 bar of the next qualifying odd
  month before evaluating a replacement package.
- Close both legs after `strategy_max_hold_days=70` as a stale guard.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the bimonthly source hold.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Parameter, history, calendar-continuity, arithmetic, spread, ATR, lot,
  period-attempt, magic, and composition checks fail closed.
- News compliance gates new entries for both symbols; lifecycle management and
  orphan repair remain active. The Q02 structural setfile disables news axes.

## 7. Trade Management Rules

- Exactly two opposite-side legs with equal fixed-risk shares.
- Close both legs together at the bimonthly reset or 70-day stale limit, and
  flatten any orphan or invalid composition on the next tick.
- No TP, trail, break-even, partial close, scale-in, grid, martingale,
  pyramiding, external feed, adaptive PnL fit, banned indicator, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_cv_window_months` | 36 | [36] | source-aligned completed monthly-return count |
| `strategy_history_bars` | 1200 | [1000, 1200, 1400] | bounded D1 retrieval buffer only |
| `strategy_rebalance_month_parity` | 1 | [1] | locked odd-month bimonthly anchor |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 70 | [70] | stale guard around bimonthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG entry spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The 36-return window, sample-variance denominator, absolute-mean scaling,
high-minus-low direction, odd-month renewal, equal half-risk carrier, and no
same-period re-entry are locked. A standard-deviation numerator, signed mean,
shorter window, monthly renewal, momentum overlay, or direction flip requires
a new card.

## Author Claim

"high spot price volatility ... induces high expected futures returns"
(PDF p. 20).

This bounded claim motivates a queue candidate; it does not validate a
two-CFD energy translation.

## Risk

- `expected_pf: 1.03` is a low queue-ordering prior, not evidence.
- `expected_dd_pct: 25.0` reflects XNG gaps, legging, near-zero-mean
  instability, narrow ranking, continuous-CFD basis, and long holds.
- Expected frequency is six packages/year after warm-up, only one above the
  binding Q02 minimum of five; missed data or filters can kill density.
- Source returns depend on a broad futures cross-section and maturity
  decomposition that this carrier cannot reproduce.
- `risk_class: high`; `ml_required: false`.

## Strategy Allowability Check

- [x] Mechanical structural normalized-variance risk-premium thesis.
- [x] Peer-reviewed primary source, DOI, open full text, and complete review.
- [x] No ML, banned indicator, external runtime feed, futures curve, volume,
  grid, martingale, pyramiding, or adaptive PnL fitting.
- [x] D1/bimonthly expected density is six packages/year, above the Q02 floor.
- [x] Backtests use `RISK_FIXED`; no live setfile is authorized.
- [x] Friday-close exception is source-aligned and documented.
- [x] Manual repository dedup review was clean before atomic allocation.

## Non-Duplicate Decision

- `QM5_13123_energy-val-rank`: 54-66 month price-ratio value, not normalized
  monthly variance.
- `QM5_13132_energy-bab`: market beta, not a first/second-moment ratio.
- `QM5_13133_energy-ivol`: daily OLS residual risk versus a four-commodity
  factor, not total monthly variance divided by mean.
- `QM5_13118`, `QM5_13129`, `QM5_13131`: third moment, signed semivariance,
  and fourth moment; CV uses only mean and sample variance.
- `QM5_13134_energy-vr-mom`: daily autocorrelation regime on WTI alone, not a
  two-leg cross-sectional level rank.
- `QM5_12567_cum-rsi2-commodity`: short-horizon long-only RSI pullback, not a
  bimonthly symmetric structural basket.

The dedup tool's only candidate was the lexical `energy-val-rank` match.
Manual mechanic review verdict: `CLEAN_AFTER_MANUAL_REVIEW`.

## Framework Alignment

- no_trade: exact host/slot, locked formula and calendar, bounded history,
  arithmetic, spread, ATR, lot, period-attempt, magic, and package guards.
- trade_entry: completed-month CV rank, paired orders, equal fixed-risk
  allocation, and frozen ATR stops.
- trade_management: next-period reset, 70-day stale close, restart-safe deal
  scan, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

No `T_Live`, AutoTrading setting, live setfile, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial bimonthly XTI/XNG CV basket | Q02 | ENQUEUED |

## Lessons Captured

- 2026-07-11: A broad futures characteristic can seed a strict two-CFD
  falsification, but its cross-sectional breadth and maturity decomposition
  must remain explicit kill risks rather than inherited evidence.
