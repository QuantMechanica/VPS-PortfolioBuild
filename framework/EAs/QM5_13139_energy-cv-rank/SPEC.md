# QM5_13139_energy-cv-rank - Strategy Spec

**EA ID:** QM5_13139
**Slug:** `energy-cv-rank`
**Strategy ID:** `SZYMANOWSKA-CV-2014_XTI_XNG_S01`
**Source:** Szymanowska et al. (2014), DOI `10.1111/jofi.12096`
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from `XTIUSD.DWX`. On the first host bar of
each odd-numbered broker month, it reconstructs 37 completed consecutive
month-end closes for XTI and XNG, computes exactly 36 monthly log returns, and
calculates each leg's sample variance divided by absolute mean return.

It buys the higher-CV leg and shorts the lower-CV leg. Fixed package risk is
split equally, each leg receives a frozen `ATR(20) * 3.5` hard stop, and the
package closes at the next odd-month transition, after 70 days, or immediately
on an orphan or invalid composition.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_cv_window_months` | 36 | locked | completed monthly log returns |
| `strategy_history_bars` | 1200 | 1000-1400 | bounded retrieval/warm-up buffer |
| `strategy_rebalance_month_parity` | 1 | locked | January/March/May/July/September/November |
| `strategy_atr_period_d1` | 20 | 14-30 | D1 hard-stop ATR |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | frozen stop multiple |
| `strategy_max_hold_days` | 70 | locked | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | 1000-2500 | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | 2000-4500 | XNG spread cap |
| `strategy_deviation_points` | 20 | 10-50 | basket order deviation |

The 36-return window, sample-variance denominator, absolute-mean scaling,
high-versus-low direction, odd-month cadence, equal half-risk carrier, and no
same-period re-entry are locked.

## 3. Symbol Universe

- Logical symbol: `QM5_13139_XTI_XNG_CV_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1, magic `131390000`.
- Traded slot 1: `XNGUSD.DWX`, D1, magic `131390001`.
- No other symbol or timeframe is authorized.

## 4. Timeframe

The host and both signal legs use D1 bars. A signal forms only when the current
host bar enters an odd-numbered broker month and the immediately prior
completed bar has a different month key. Current-month data is excluded from
the 36-return formation set.

## 5. Expected Behaviour

- Approximately six completed packages/year after warm-up; retire below five.
- Typical hold is two broker months, bounded by a 70-day stale guard.
- The carrier is opposite-side and equal-risk, not guaranteed beta or dollar
  neutral.
- Near-zero means, XNG gaps, legging, and the narrow rank make risk high.
- Q09 alone may establish realized correlation to the portfolio book.

## 6. Source Citation And Evidence Boundary

Szymanowska, Marta; de Roon, Frans; Nijman, Theo; and van den Goorbergh, Rob
(2014), "An Anatomy of Commodity Futures Risk Premia," *The Journal of
Finance* 69(1), 453-482, DOI https://doi.org/10.1111/jofi.12096.

The source ranks 21 collateralized commodity futures across four portfolios
and multiple maturities in a sample ending in 2010. The EA narrows the test to
two continuous CFDs and cannot reproduce spot/term/maturity decomposition.
Q02 must independently validate density and efficacy; no source performance or
correlation statistic is imported.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Backtest Q02+ | `RISK_FIXED` | 1000 per package, split 50/50 |
| Live | not authorized | none |

The EA calls `QM_LotsForRisk` and applies the 0.5 package share after framework
sizing. It validates broker volume metadata and flattens a failed two-leg
entry. There is no TP, trail, break-even, partial close, scale-in, grid,
martingale, or pyramiding.

## 8. Four-Module Mapping

- **No-Trade:** exact host, locked formula/calendar, bounded history,
  arithmetic, spread, ATR, lot, magic, package, and period-attempt guards.
- **Entry:** prior-36-month CV rank, paired orders, equal fixed-risk allocation,
  and frozen hard stops.
- **Management:** next-period close, 70-day time stop, deal-history same-period
  suppression, composition validation, and orphan cleanup.
- **Close:** `QM_TM_ClosePosition` for package exits plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or
ML is authorized.
