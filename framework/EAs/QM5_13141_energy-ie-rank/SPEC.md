# QM5_13141_energy-ie-rank - Strategy Spec

**EA ID:** QM5_13141
**Slug:** `energy-ie-rank`
**Strategy ID:** `HAN-IE-2023_XTI_XNG_S01`
**Source:** Han et al. (2023), DOI 10.1111/jfir.12339
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from `XTIUSD.DWX`. On the first host bar of
each broker month, it selects synchronized simple returns from exactly the six
completed broker-calendar months. It forms an equal-weight XTI/XNG/XAU/XAG
factor and separately regresses XTI and XNG on an intercept, that factor, and
the squared factor.

For each leg, IE is the empirical share of centered residuals at or above
`+0.5` population standard deviations minus the share at or below `-0.5`.
The EA buys the lower-IE energy leg and shorts the higher-IE leg. Per-leg ATR
risk weights target equal dollar notional after stop translation. The package
closes at the next month transition, after 40 days, or immediately when an
orphan or invalid composition is observed.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_lookback_months` | 6 | locked | completed calendar-month window |
| `strategy_history_bars` | 220 | 180, 220, 280 | bounded D1 retrieval buffer |
| `strategy_min_return_observations` | 100 | 90, 100, 110 | common-return data floor |
| `strategy_tail_threshold_sigma` | 0.5 | locked | inclusive IE tail boundary |
| `strategy_atr_period_d1` | 20 | 14-30 | D1 hard-stop ATR |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | frozen stop multiple |
| `strategy_max_notional_mismatch_pct` | 20.0 | 10-30 | rounded notional mismatch cap |
| `strategy_max_hold_days` | 40 | locked | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | 1000-2500 | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | 2000-4500 | XNG spread cap |
| `strategy_deviation_points` | 20 | 10-50 | basket order deviation |

The six-month window, simple returns, four-CFD equal-weight factor, quadratic
OLS, population residual standardization, inclusive half-sigma counts,
low-IE direction, equal-notional target, monthly renewal, and no same-month
re-entry are locked.

## 3. Symbol Universe

- Logical symbol: `QM5_13141_XTI_XNG_IE_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1, magic `131410000`.
- Traded slot 1: `XNGUSD.DWX`, D1, magic `131410001`.
- Read-only factor members: `XAUUSD.DWX` and `XAGUSD.DWX`, D1.
- No metal order, standalone leg, different symbol, or timeframe is authorized.

## 4. Timeframe

The host and all factor observations use D1. A signal is evaluated only when
the current XTI host bar enters a new broker month and the immediately prior
completed host bar has a different month key. Current-month and open-bar data
are excluded.

## 5. Expected Behaviour

- Approximately 12 completed packages/year after warm-up; retire below five.
- Typical hold is one broker month, bounded by a 40-day stale guard.
- The carrier is opposite-side and approximately equal-notional, not proven
  beta neutral, factor neutral, or decorrelated from the certified book.
- XNG gaps, CFD rolls, factor endogeneity, two-name rank breadth, and legging
  make the initial risk classification high.

## 6. Source Citation And Evidence Boundary

Han, Yufeng; Mo, Xuan; Su, Zhi; and Zhu, Yifeng (2023), "Is idiosyncratic
asymmetry priced in commodity futures?", *Journal of Financial Research*
46(3), 875-898, DOI https://doi.org/10.1111/jfir.12339.

The source ranks 27 futures against the S&P GSCI. This EA narrows the test to
two continuous energy CFDs and substitutes a fixed four-CFD equal-weight
factor. Q02 is therefore a strict proxy-carrier falsification. No source
performance, cost, drawdown, or correlation statistic is imported.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Backtest Q02+ | RISK_FIXED | 1000 per package |
| Live | not authorized | none |

The EA splits the fixed stop-risk in proportion to each leg's stop distance as
a fraction of entry price, targeting equal dollar notional. It rejects more
than 20% post-rounding notional mismatch and flattens a failed two-leg entry.
There is no TP, trail, break-even, partial close, scale-in, grid, martingale,
or pyramiding.

## 8. Four-Module Mapping

- No-Trade: exact host, locked estimator, bounded synchronized history, six
  month coverage, observation floor, matrix condition, residual variance,
  spread, ATR, lot, notional, magic, package, and prior-attempt guards.
- Entry: monthly low/high IE rank, equal-notional paired sizing, and frozen
  hard stops.
- Management: next-month close, 40-day time stop, deal-history same-month
  suppression, composition validation, and orphan cleanup.
- Close: framework package-close helper plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or
ML is authorized.
