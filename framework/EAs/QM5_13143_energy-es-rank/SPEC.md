# QM5_13143_energy-es-rank - Strategy Spec

**EA ID:** QM5_13143
**Slug:** energy-es-rank
**Strategy ID:** YIYI-ES-2025_XTI_XNG_S02
**Source:** Qin et al. (2025), DOI 10.1002/fut.22559
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from XTIUSD.DWX. On the first host bar of
each broker month, it reads simple daily returns whose ending dates belong to
the prior twelve completed broker calendar months. For each leg it sorts those
returns and averages the lowest ceil(N times 0.05) observations.

It buys the higher expected-shortfall leg, whose lower tail is less negative,
and shorts the lower expected-shortfall leg. Fixed package risk is split
equally, both legs receive frozen ATR(20) times 3.5 hard stops, and the package
closes at the next monthly transition, after 40 days, or immediately on an
orphan or invalid composition.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| strategy_es_window_months | 12 | locked | completed calendar-month window |
| strategy_tail_probability | 0.05 | locked | source lower-tail probability |
| strategy_history_bars | 400 | 350-500 | bounded D1 retrieval buffer |
| strategy_min_daily_observations | 220 | 200-240 | data-sufficiency floor |
| strategy_atr_period_d1 | 20 | 14-30 | D1 hard-stop ATR |
| strategy_atr_sl_mult | 3.5 | 2.5-5.0 | frozen stop multiple |
| strategy_max_hold_days | 40 | locked | stale package guard |
| strategy_xti_max_spread_pts | 1500 | 1000-2500 | XTI spread cap |
| strategy_xng_max_spread_pts | 3000 | 2000-4500 | XNG spread cap |
| strategy_deviation_points | 20 | 10-50 | basket order deviation |

The twelve-month window, simple returns, 5% lower-tail mean, ceiling count,
high-versus-low direction, monthly cadence, equal half-risk carrier, and no
same-month re-entry are locked.

## 3. Symbol Universe

- Logical symbol: QM5_13143_XTI_XNG_ES_D1.
- Host/traded slot 0: XTIUSD.DWX, D1, magic 131430000.
- Traded slot 1: XNGUSD.DWX, D1, magic 131430001.
- No other symbol or timeframe is authorized.

## 4. Timeframe

The host and both signal legs use D1 bars. A signal forms only when the current
host bar enters a new broker calendar month and the immediately prior host bar
has a different month key. Current-month data is excluded.

## 5. Expected Behaviour

- Approximately twelve completed packages/year after warm-up; retire below
  five packages/year.
- Typical hold is one broker month, bounded by a 40-day stale guard.
- The carrier is opposite-side and equal fixed-risk, not guaranteed dollar or
  beta neutral.
- XNG gaps, legging, tail-estimator instability, and the narrow rank make risk
  high.
- Later portfolio gates alone may establish realized book correlation.

## 6. Source Citation And Evidence Boundary

Qin, Yiyi; Cai, Jun; Zhu, Jie; and Webb, Robert (2025), "Commodity Futures
Characteristics and Asset Pricing Models," Journal of Futures Markets 45(3),
176-207, DOI https://doi.org/10.1002/fut.22559.

The source ranks 34 commodity futures. The EA narrows the test to two
continuous CFDs, uses broker D1 returns rather than collateralized
futures-index excess returns, and adds implementation risk controls. The
source's full-sample one-way ES hedge t-statistic is weak; no source
performance or correlation statistic is imported. The IPCA model is excluded.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Backtest Q02+ | RISK_FIXED | 1000 per package, split 50/50 |
| Live | not authorized | none |

The EA calls QM_LotsForRisk and applies the 0.5 package share after framework
sizing. It validates broker volume metadata and flattens a failed two-leg
entry. There is no TP, trail, break-even, partial close, scale-in, grid,
martingale, or pyramiding.

## 8. Four-Module Mapping

- No-Trade: exact host, locked formula, bounded history, expected-month
  coverage, observation count, tail count, arithmetic, spread, ATR, lot,
  magic, package, and prior-attempt guards.
- Entry: prior-twelve-month expected-shortfall rank, paired orders, equal
  fixed-risk allocation, and frozen hard stops.
- Management: next-month close, 40-day time stop, deal-history same-month
  suppression, composition validation, and orphan cleanup.
- Close: QM_TM_ClosePosition for package exits plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or
ML is authorized.
