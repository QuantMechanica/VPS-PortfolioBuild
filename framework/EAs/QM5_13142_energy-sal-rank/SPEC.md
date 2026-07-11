# QM5_13142_energy-sal-rank - Strategy Spec

**EA ID:** QM5_13142
**Slug:** `energy-sal-rank`
**Strategy ID:** `HE-SALIENCE-2025_XTI_XNG_S01`
**Source:** He et al. (2025), DOI 10.13140/RG.2.2.26815.83364
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from `XTIUSD.DWX`. On the first host bar of
each broker month, it selects synchronized simple returns from the immediately
prior complete broker-calendar month for XTI, XNG, XAU, and XAG and forms an
equal-weight four-CFD reference payoff.

For each energy leg, it calculates source-defined daily payoff salience with
`theta=0.1`, ranks dates from most to least salient, normalizes `delta=0.7`
rank weights to mean one, and calculates the population covariance of weights
and returns. It buys the higher-ST energy leg and shorts the lower-ST leg.
Per-leg ATR risk weights target equal dollar notional after stop translation.
The package closes at the next month transition, after 40 days, or immediately
when an orphan or invalid composition is observed.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_formation_months` | 1 | locked | immediately prior completed month |
| `strategy_history_bars` | 80 | 60, 80, 100 | bounded D1 retrieval buffer |
| `strategy_min_return_observations` | 15 | 15, 18, 20 | synchronized return floor |
| `strategy_salience_theta` | 0.1 | locked | source salience denominator constant |
| `strategy_salience_delta` | 0.7 | locked | source probability-distortion constant |
| `strategy_atr_period_d1` | 20 | 14-30 | D1 hard-stop ATR |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | frozen stop multiple |
| `strategy_max_notional_mismatch_pct` | 20.0 | 10-30 | rounded notional mismatch cap |
| `strategy_max_hold_days` | 40 | locked | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | 1000-2500 | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | 2000-4500 | XNG spread cap |
| `strategy_deviation_points` | 20 | 10-50 | basket order deviation |

The one-month window, simple returns, four-CFD equal-weight reference,
theta/delta, date-ranking rule, population covariance, high-ST direction,
equal-notional target, monthly renewal, and no same-month re-entry are locked.

## 3. Symbol Universe

- Logical symbol: `QM5_13142_XTI_XNG_SAL_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1, magic `131420000`.
- Traded slot 1: `XNGUSD.DWX`, D1, magic `131420001`.
- Read-only reference members: `XAUUSD.DWX` and `XAGUSD.DWX`, D1.
- No metal order, standalone leg, different symbol, or timeframe is authorized.

## 4. Timeframe

The host and all reference observations use D1. A signal is evaluated only
when the current XTI host bar enters a new broker month and the immediately
prior completed host bar has a different month key. Current-month and open-bar
data are excluded.

## 5. Expected Behaviour

- Approximately 12 completed packages/year after warm-up; retire below five.
- Typical hold is one broker month, bounded by a 40-day stale guard.
- The carrier is opposite-side and approximately equal-notional, not proven
  beta neutral, factor neutral, or decorrelated from the certified book.
- XNG gaps, CFD rolls, preprint uncertainty, reference endogeneity, two-name
  rank breadth, and legging make the initial risk classification high.

## 6. Source Citation And Evidence Boundary

He, Zhongda; Jia, Yuecheng; Shen, Mi; and Yang, Yuqing (2025), "Salience
Theory and the Returns of Commodity Futures," author-uploaded preprint dated
2025-02-03, DOI https://doi.org/10.13140/RG.2.2.26815.83364.

The source ranks a broad futures universe. This EA narrows the test to two
continuous energy CFDs and substitutes a fixed four-CFD equal-weight reference
payoff. Q02 is therefore a strict proxy-carrier falsification. No source
performance, cost, drawdown, or correlation statistic is imported.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Backtest Q02+ | RISK_FIXED | 1000 per package |
| Live | not authorized | none |

The EA splits fixed stop-risk in proportion to each leg's stop distance as a
fraction of entry price, targeting equal dollar notional. It rejects more than
20% post-rounding notional mismatch and flattens a failed two-leg entry. There
is no TP, trail, break-even, partial close, scale-in, grid, martingale, or
pyramiding.

## 8. Four-Module Mapping

- No-Trade: exact host, locked estimator, bounded synchronized history,
  prior-month coverage, observation floor, rank normalization, spread, ATR,
  lot, notional, magic, package, and prior-attempt guards.
- Entry: monthly high/low ST rank, equal-notional paired sizing, and frozen
  hard stops.
- Management: next-month close, 40-day time stop, deal-history same-month
  suppression, composition validation, and orphan cleanup.
- Close: framework package-close helper plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or
ML is authorized.
