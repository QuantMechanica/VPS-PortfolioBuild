# QM5_13131_energy-kurt-rank - Strategy Spec

**EA ID:** QM5_13131
**Slug:** `energy-kurt-rank`
**Strategy ID:** `HOLLSTEIN-MAX-2021_XTI_XNG_S02`
**Source:** Hollstein, Prokopczuk, and Tharann (2021), DOI `10.1142/S2010139221500178`
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from `XTIUSD.DWX`. On the first host bar of a
new broker month it loads the most recent 253 completed D1 closes for XTI and
XNG, computes exactly 252 simple daily returns, and calculates each leg's
Pearson historical kurtosis using the source's sample-variance and fourth-
central-moment denominators.

It buys the higher-kurtosis leg and shorts the lower-kurtosis leg. The fixed
package risk is split equally, each leg receives a frozen `ATR(20) * 3.5` hard
stop, and the package closes at the next month transition, after 35 days, or
immediately on an orphan or invalid composition.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_lookback_d1` | 252 | locked | completed simple daily returns |
| `strategy_history_bars` | 320 | 280-380 | bounded retrieval/warm-up buffer |
| `strategy_atr_period_d1` | 20 | 14-30 | D1 hard-stop ATR |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | frozen stop multiple |
| `strategy_max_hold_days` | 35 | locked | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | 1000-2500 | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | 2000-4500 | XNG spread cap |
| `strategy_deviation_points` | 20 | 10-50 | basket order deviation |

The 252-return window, formula denominators, Pearson rather than excess
kurtosis, high-versus-low direction, monthly renewal, equal half-risk carrier,
and no same-month re-entry are locked.

## 3. Symbol Universe

- Logical symbol: `QM5_13131_XTI_XNG_HKURT_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1, magic `131310000`.
- Traded slot 1: `XNGUSD.DWX`, D1, magic `131310001`.
- No other symbol or timeframe is authorized.

## 4. Timeframe

The host and both signal legs use D1 bars. A signal forms only when the current
open host D1 bar and the immediately prior completed bar have different broker
month keys. The current D1 bar is excluded from the 252-return formation set.

## 5. Expected Behaviour

- Approximately 12 completed packages/year after warm-up; retire below five.
- Typical hold is one broker month, bounded by a 35-day stale guard.
- The carrier is opposite-side and equal-risk, not guaranteed beta or dollar
  neutral.
- Fourth-moment instability, XNG gaps, legging, and the narrow rank make risk
  high.
- Q09 alone may establish realized correlation to the portfolio book.

## 6. Source Citation And Evidence Boundary

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021), "Anomalies
in Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI https://doi.org/10.1142/S2010139221500178.

The paper ranks at least six collateralized commodity futures. Its full-sample
historical-kurtosis tercile spread is positive, but the directly relevant
two-portfolio spread and regression slope are insignificant, and the
post-financialization spread reverses sign and is insignificant. The EA
narrows the test to two continuous CFDs and uses simple close-to-close returns.
Q02 must reject any failure of that modern two-leg effect; no source performance
number is imported.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Backtest Q02+ | `RISK_FIXED` | 1000 per package, split 50/50 |
| Live | not authorized | none |

The EA calls `QM_LotsForRisk` and applies the 0.5 package share only after
framework sizing. It validates broker volume metadata and flattens a failed
two-leg entry. There is no TP, trail, break-even, partial close, scale-in,
grid, martingale, or pyramiding.

## 8. Four-Module Mapping

- **No-Trade:** exact host, locked dimensions, bounded history, arithmetic,
  spread, ATR, lot, magic, package, and monthly-attempt guards.
- **Entry:** prior-252-return Pearson-kurtosis rank, paired orders, equal fixed-
  risk allocation, and frozen hard stops.
- **Management:** next-month close, 35-day time stop, deal-history same-month
  suppression, composition validation, and orphan cleanup.
- **Close:** `QM_TM_ClosePosition` for package exits plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or
ML is authorized.
