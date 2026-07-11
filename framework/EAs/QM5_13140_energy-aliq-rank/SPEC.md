# QM5_13140_energy-aliq-rank - Strategy Spec

**EA ID:** QM5_13140
**Slug:** energy-aliq-rank
**Strategy ID:** YIYI-ALIQ-2025_XTI_XNG_S01
**Source:** Qin et al. (2025), DOI 10.1002/fut.22559
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from XTIUSD.DWX. On the first host bar of
each broker calendar month, it reads completed D1 bars belonging to the prior
12 calendar months and calculates each leg's mean absolute log return divided
by same-day tick volume, scaled by 1,000,000.

It buys the higher-ALIq leg and shorts the lower-ALIq leg. Fixed package risk
is split equally, each leg receives a frozen ATR(20) times 3.5 hard stop, and
the package closes at the next monthly transition, after 40 days, or
immediately on an orphan or invalid composition.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| strategy_aliq_window_months | 12 | locked | completed calendar-month window |
| strategy_history_bars | 400 | 350-500 | bounded D1 retrieval buffer |
| strategy_min_daily_observations | 220 | 200-240 | data-sufficiency floor |
| strategy_atr_period_d1 | 20 | 14-30 | D1 hard-stop ATR |
| strategy_atr_sl_mult | 3.5 | 2.5-5.0 | frozen stop multiple |
| strategy_max_hold_days | 40 | locked | stale package guard |
| strategy_xti_max_spread_pts | 1500 | 1000-2500 | XTI spread cap |
| strategy_xng_max_spread_pts | 3000 | 2000-4500 | XNG spread cap |
| strategy_deviation_points | 20 | 10-50 | basket order deviation |

The 12-month window, daily absolute log-return-per-tick-volume transform,
1,000,000 scale, arithmetic mean, high-versus-low direction, monthly cadence,
equal half-risk carrier, and no same-month re-entry are locked.

## 3. Symbol Universe

- Logical symbol: QM5_13140_XTI_XNG_ALIQ_D1.
- Host/traded slot 0: XTIUSD.DWX, D1, magic 131400000.
- Traded slot 1: XNGUSD.DWX, D1, magic 131400001.
- No other symbol or timeframe is authorized.

## 4. Timeframe

The host and both signal legs use D1 bars. A signal forms only when the current
host bar enters a new broker calendar month and the immediately prior
completed host bar has a different month key. Current-month data is excluded.

## 5. Expected Behaviour

- Approximately 12 completed packages/year after warm-up; retire below five.
- Typical hold is one broker month, bounded by a 40-day stale guard.
- The carrier is opposite-side and equal-risk, not guaranteed beta or dollar
  neutral.
- XNG gaps, legging, proxy instability, and the narrow rank make risk high.
- Later portfolio gates alone may establish realized book correlation.

## 6. Source Citation And Evidence Boundary

Qin, Yiyi; Cai, Jun; Zhu, Jie; and Webb, Robert (2025), "Commodity Futures
Characteristics and Asset Pricing Models," Journal of Futures Markets 45(3),
176-207, DOI https://doi.org/10.1002/fut.22559.

The source ranks 34 commodity futures and uses daily dollar volume. The EA
narrows the test to two continuous CFDs and substitutes MT5 tick volume as an
activity proxy. It excludes the source's IPCA model. Q02 must independently
validate density and efficacy; no source performance or correlation statistic
is imported.

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

- No-Trade: exact host, locked formula, bounded history, expected months,
  observation count, arithmetic, spread, ATR, lot, magic, package, and
  prior-attempt guards.
- Entry: prior-12-month ALIQ rank, paired orders, equal fixed-risk allocation,
  and frozen hard stops.
- Management: next-month close, 40-day time stop, deal-history same-month
  suppression, composition validation, and orphan cleanup.
- Close: QM_TM_ClosePosition for package exits plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or
ML is authorized.
