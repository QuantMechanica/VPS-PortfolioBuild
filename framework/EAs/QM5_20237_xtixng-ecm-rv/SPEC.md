# QM5_20237_xtixng-ecm-rv - Strategy Spec

**EA ID:** QM5_20237  
**Slug:** xtixng-ecm-rv  
**Strategy ID:** VILLAR-RAMBERG-OILGAS-2026_S01  
**Sources:** Villar and Joutz (2006); Ramberg and Parsons (2012)  
**Last revised:** 2026-08-06

## 1. Strategy Logic

The EA runs one D1 logical basket from `XTIUSD.DWX`. On each new host bar it
loads exactly 252 synchronized completed closes and fits, with native closed-
form arithmetic, the trend-augmented regression:

```text
log(XNG) = alpha + beta * log(XTI) + gamma * chronological_time + residual
```

The determinant must exceed `1e-10 * Sxx * Suu`, beta must remain in
`[0.10, 2.00]`, and absolute daily trend must not exceed `0.01`. Residual
sigma uses 249 regression degrees of freedom. A fresh crossing above +2 buys
XTI and sells XNG; a fresh crossing below -2 sells XTI and buys XNG. The
package closes when absolute z is at most 0.5, the model or package becomes
invalid, or the oldest leg reaches 60 calendar days.

This is a structural CFD proxy for an oil/gas long-run relation. It does not
inherit source coefficients, performance, half-life, or stability.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| strategy_ols_lookback_d1 | 252 | locked | synchronized completed observations |
| strategy_entry_z | 2.0 | locked | residual crossing boundary |
| strategy_exit_z | 0.5 | locked | convergence boundary |
| strategy_beta_min | 0.10 | locked | positive oil-beta floor |
| strategy_beta_max | 2.00 | locked | positive oil-beta ceiling |
| strategy_trend_abs_max | 0.01 | locked | daily log-drift cap |
| strategy_history_bars | 300 | 280, 300, 360 | bounded warm-up buffer |
| strategy_max_endpoint_gap_days | 10 | 7, 10 | completed-endpoint freshness |
| strategy_atr_period_d1 | 20 | 14, 20, 30 | D1 hard-stop ATR |
| strategy_atr_sl_mult | 3.5 | 2.5, 3.5, 5.0 | frozen stop multiple |
| strategy_max_hold_days | 60 | locked | stale package guard |
| strategy_xti_max_spread_pts | 1000 | 750, 1000, 1500 | XTI entry spread cap |
| strategy_xng_max_spread_pts | 3000 | 2000, 3000, 4500 | XNG entry spread cap |
| strategy_deviation_points | 20 | 10, 20, 50 | paired-order deviation |

## 3. Symbol Universe And Timeframe

- Logical symbol: `QM5_20237_XTI_XNG_ECM_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1, magic `202370000`.
- Traded slot 1: `XNGUSD.DWX`, D1, magic `202370001`.
- Current bars are excluded. All completed timestamps must match exactly and
  the latest completed endpoint must be fresh.

No other carrier or timeframe is authorized.

## 4. Entry And Lifecycle

- `z_now > 2.0` and `z_prev <= 2.0`: buy XTI, sell XNG.
- `z_now < -2.0` and `z_prev >= -2.0`: sell XTI, buy XNG.
- An already-extreme residual does not re-enter; crossings are derived only
  from the latest two completed observations.
- XTI receives frozen relative stop-risk weight `abs(beta)` and XNG receives
  unit weight. The two shares sum to one aggregate `RISK_FIXED` budget.
- Each leg receives a frozen `3.5 * ATR(20,D1)` broker hard stop. There is no
  TP, trailing stop, break-even, partial close, scale-in, grid, or martingale.
- A failed second leg, orphan, same-side pair, missing stop, invalid model,
  stale endpoint, convergence, or 60-day time stop flattens the package.
- Friday close is disabled so multiweek convergence can complete.

## 5. Expected Behaviour And Kill Rules

The prior is roughly 5-12 completed packages per year after warm-up. Q02 must
retire the candidate below five packages per year, on a zero-trade baseline,
or if economic viability fails. The implementation is opposite-side and
beta-weighted at stop risk, but that does not prove dollar, factor, portfolio,
or market neutrality. Portfolio correlation remains a later empirical gate.

## 6. Evidence Boundary

Villar and Joutz (U.S. EIA, 2006) model a long-run WTI/Henry Hub log-price
relation with a deterministic trend and report oil as weakly exogenous in
their sample. Ramberg and Parsons (*The Energy Journal*, 2012) find a weak,
regime-shifting tie and emphasize that much gas-price variation remains
unexplained. Modern EIA evidence of little daily return correlation is
explicit adverse context. Those sources motivate the falsifiable structure;
they do not validate this CFD implementation.

## 7. Four-Module Mapping

- No-Trade: exact host/timeframe/ID/slot, authorized contract, synchronized
  completed history, endpoint freshness, finite regression, determinant,
  beta/trend/sigma, spread, ATR, volume, and magic guards.
- Entry: fresh residual boundary crossing, opposite paired orders, frozen
  beta/unit risk shares, hard stops, and atomic rollback.
- Management: package composition and hard-stop validation; no discretionary
  stop mutation.
- Close: convergence, invalid model/data, orphan repair, or 60-day time stop
  via framework close calls; broker hard stops remain independent.

## 8. Safety Boundary

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live setfile, T_Live
change, AutoTrading action, deploy manifest, portfolio-gate edit, admission
artifact, external runtime data, banned indicator, or ML is authorized.

## 9. Build History

| Version | Date | Event |
|---|---|---|
| v1 | 2026-08-06 | Initial approved XTI/XNG error-correction basket build |
| v1.1 | 2026-08-06 | Strict compile and full V5 build check PASS with zero warnings |
