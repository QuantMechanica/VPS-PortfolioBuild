# QM5_13145_energy-idmom - Strategy Spec

**EA ID:** QM5_13145
**Slug:** energy-idmom
**Strategy ID:** SHPAK-IDMOM-2017_XTI_XNG_S01
**Source:** Shpak, Human, and Nardon (2017/2018), *Idiosyncratic Momentum in Commodity Futures*
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from XTIUSD.DWX. At each broker-month
transition it reconstructs eleven completed monthly returns for XTI, XNG, XAU,
and XAG; forms a fixed equal-weight four-CFD market factor; and estimates each
energy leg's OLS beta to that factor.

Following source equation 3, the rank sums `asset_return - beta *
factor_return` without subtracting fitted alpha. The EA buys the higher-score
energy leg and shorts the lower. It splits one fixed-risk package equally,
places frozen ATR(20) times 3.5 hard stops, and closes at the next monthly
transition, after 35 days, or immediately on an orphan/invalid composition.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| strategy_ranking_months | 11 | locked | source-best formation period |
| strategy_history_bars | 420 | 380-500 | bounded D1 endpoint buffer |
| strategy_max_boundary_gap_days | 10 | 7-10 | endpoint freshness guard |
| strategy_atr_period_d1 | 20 | 14-30 | D1 hard-stop ATR |
| strategy_atr_sl_mult | 3.5 | 2.5-5.0 | frozen stop multiple |
| strategy_max_hold_days | 35 | locked | stale package guard |
| strategy_xti_max_spread_pts | 1500 | 1000-2500 | XTI spread cap |
| strategy_xng_max_spread_pts | 3000 | 2000-4500 | XNG spread cap |
| strategy_deviation_points | 20 | 10-50 | basket order deviation |

The window, factor membership/weights, beta estimator, alpha-not-subtracted
score, winner-minus-loser direction, monthly cadence, equal half-risk carrier,
and no same-month re-entry are locked.

## 3. Symbol Universe

- Logical symbol: QM5_13145_ENERGY_IDMOM_D1.
- Host/traded slot 0: XTIUSD.DWX, D1, magic 131450000.
- Traded slot 1: XNGUSD.DWX, D1, magic 131450001.
- Read-only factor members: XAUUSD.DWX and XAGUSD.DWX.
- No other symbol or timeframe is authorized.

## 4. Timeframe

The host and all four signal series use D1 bars. A signal forms only when the
framework D1-derived calendar key enters a new broker month and the immediately
prior host bar has a different month key. All eleven return observations end
at completed calendar-month boundaries; the current partial month never enters
the regression or rank.

## 5. Expected Behaviour

- Approximately twelve paired packages/year after warm-up; retire below five.
- Typical hold is one broker month, bounded by a 35-day stale guard.
- Opposite-side equal fixed-risk execution is not guaranteed dollar/beta
  neutrality. Q09 alone can establish realized book correlation.
- XNG gaps, legging, proxy-factor misspecification, CFD rolls, and the narrow
  rank make risk high.

## 6. Source Citation And Translation Boundary

Shpak, Iuliia; Human, Ben; and Nardon, Andrea (2017/2018), "Idiosyncratic
Momentum in Commodity Futures," *CBBA-Europe Review*, July 2018, pp. 56-85;
SSRN 3035397.

The source ranks 28 futures using market, term-structure, and size factors. The
EA uses only the price-native market component, represented by four registered
CFDs, and trades two energy legs. Missing curve/open-interest factors are not
invented. No source return, cost, significance, or correlation is imported.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Backtest Q02+ | RISK_FIXED | 1000 per package, split 50/50 |
| Live | not authorized | none |

There is no TP, trail, break-even, partial close, scale-in, grid, martingale,
pyramiding, external runtime feed, banned indicator, or ML.

## 8. Four-Module Mapping

- No-Trade: exact host, locked model, bounded history, endpoint freshness,
  factor variance, residual arithmetic, spread, ATR, lot, magic, package, and
  prior-attempt guards.
- Entry: eleven-month residual-return rank, paired orders, equal fixed risk,
  and frozen hard stops.
- Management: next-month close, 35-day time stop, restart-safe same-month
  suppression, composition validation, and orphan cleanup.
- Close: QM_TM_ClosePosition package exits plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, or ML is authorized.
