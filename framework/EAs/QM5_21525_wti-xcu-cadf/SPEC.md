# QM5_21525_wti-xcu-cadf - Strategy Spec

**EA ID:** QM5_21525
**Slug:** wti-xcu-cadf
**Strategy ID:** CHAN-EIA-USGS-WTI-XCU-CADF-2026_S01
**Sources:** Chan (2009); U.S. EIA; CME Group; U.S. Geological Survey
**Last revised:** 2026-08-15

## 1. Strategy Logic

The EA runs one D1 logical basket from `XTIUSD.DWX`. On each new host bar it
loads exactly 252 synchronized completed WTI and copper closes and fits:

```text
log(WTI) = alpha + beta * log(copper) + residual
delta(residual_t) = c + rho * residual_(t-1) + error
phi = 1 + rho
half_life = -log(2) / log(phi)
```

The OLS model requires beta in `[0.10,3.00]`. The simple residual CADF proxy
requires `rho<0`, `t_rho<=-3.043`, `0<phi<1`, and half-life in `[2,60]` D1
observations. Residual sigma is `sqrt(SSE/250)`. A fresh cross above `+1.0`
sells WTI and buys copper; a fresh cross below `-1.0` buys WTI and sells
copper. The package closes at `abs(z)<=0.5`, after 60 calendar days, or when
the model, synchronized data, or package becomes invalid.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| strategy_ols_lookback_d1 | 252 | synchronized completed observations |
| strategy_entry_z | 1.0 | fresh residual crossing boundary |
| strategy_exit_z | 0.5 | convergence boundary |
| strategy_cadf_t_max | -3.043 | simple CADF critical boundary |
| strategy_beta_min / max | 0.10 / 3.00 | positive copper-beta bounds |
| strategy_half_life_min_d1 / max_d1 | 2.0 / 60.0 | admissible mean-reversion speed |
| strategy_history_bars_d1 | 340 | bounded warm-up request |
| strategy_max_endpoint_gap_days | 10 | completed-endpoint freshness |
| strategy_atr_period_d1 / strategy_atr_sl_mult | 20 / 3.5 | frozen D1 hard stop |
| strategy_max_hold_days | 60 | stale-package guard |
| strategy_wti_max_spread_pts / strategy_xcu_max_spread_pts | 1500 / 1200 | entry spread caps |
| strategy_deviation_points | 20 | paired-order deviation |

The Q02 baseline also locks `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, both news axes OFF, legacy news OFF, Friday close OFF,
stress rejection zero, seed 42, host slot zero, and EA ID 21525.

## 3. Symbol Universe

- Logical symbol: `QM5_21525_WTI_XCU_CADF_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1, magic `215250000`.
- Companion/traded slot 1: `XCUUSD.DWX`, D1, magic `215250001`.

No other host or carrier is authorized.

## 4. Timeframe

- Host and both signal histories are locked to D1.
- The current bar is excluded. All 252 completed timestamps must match
  exactly, be strictly chronological, and end no more than ten days before
  the current host bar.
- Prices, logs, OLS/CADF arithmetic, standard errors, z-scores, quotes, ATR,
  stops, contract metadata, and volume steps must be positive/finite where
  applicable. Invalid state fails closed.

No other timeframe, estimator, or direction is authorized.

## 8. Entry And Lifecycle

- Positive fresh cross: sell WTI, then buy copper.
- Negative fresh cross: buy WTI, then sell copper.
- WTI receives relative stop-risk weight `1.0`; copper receives `abs(beta)`.
  Normalized shares split one aggregate fixed-risk package budget.
- Each leg receives a frozen `3.5 * ATR(20,D1)` broker hard stop. There is no
  TP, trail, break-even, partial close, retry, scale-in, grid, or martingale.
- The EA opens WTI first, then copper. A failed order, orphan, duplicate,
  same-side pair, wrong magic/symbol, missing stop, or invalid final package
  flattens every owned leg through framework helpers.
- Convergence and model validity are recalculated only on new WTI D1 bars;
  malformed-package repair and the 60-day time stop remain authoritative.

## 5. Expected Behaviour

The prior is five to twelve completed packages per full post-warm-up year.
Q02 must retire the candidate on zero trades, below five packages per year,
or nonpositive governed economics. Q09 alone can establish realized
correlation with the certified book.

Expected behavior is an episodic, symmetric relative-value package with no
position when the rolling relationship fails its CADF or half-life gates.
Opposite legs and beta-weighted stop risk do not prove dollar, beta, factor,
market, or portfolio neutrality.

## 6. Source Citation

Chan supplies the OLS/CADF pair-trading method, standardized residual fade,
mean-band exit, and half-life discipline, but tests GLD/GDX rather than
WTI/copper. EIA, CME, and USGS establish the distinct physical carrier
contexts only. This Darwinex CFD implementation transfers no coefficient,
efficacy, density, cost, neutrality, or correlation claim.

Primary citations are Ernest P. Chan, *Quantitative Trading* (Wiley, 2009),
Examples 3.6, 7.2, 7.3, and 7.5; U.S. EIA, "What drives crude oil prices:
Spot Prices"; CME Group, "Copper Futures"; and U.S. Geological Survey,
"Copper Statistics and Information." The governed composite packet is
`strategy-seeds/sources/CHAN-EIA-USGS-WTI-XCU-CADF-2026/source.md`.

## 7. Risk Model

The Q02 set uses exactly one aggregate `RISK_FIXED=1000` budget,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. WTI receives relative weight
`1.0` and copper receives `abs(beta)`; each normalized share is independently
sized to its frozen `3.5 * ATR(20,D1)` hard stop. Signal magnitude never
changes package risk. There is no take-profit, leverage escalation, averaging,
grid, martingale, scale-in, or pyramid.

Residual instability, CFD/futures basis, USD and broad-growth exposure,
commodity gaps, roll/financing, legging, lot granularity, and asynchronous
hard-stop outcomes remain material risks.

## 9. Four-Module Mapping

- No-Trade: exact host/D1/ID/slot and locked risk/news/Friday/stress/strategy
  contract, synchronized data, OLS/CADF, crossing, spread, ATR, and magic
  guards.
- Entry: fresh qualified crossing, correct opposite directions, aggregate
  fixed-risk split, hard stops, ordered two-leg open, and atomic rollback.
- Management: validate package composition; never mutate stops or add risk.
- Close: convergence, invalid model/data/package, or 60-day expiry through
  framework close helpers; broker hard stops remain independent.

## 10. Safety Boundary

This build authorizes one `RISK_FIXED` backtest setfile and one paced Q02
enqueue only. It does not authorize a manual tester run, live/demo/shadow
artifact, AutoTrading, `T_Live`, deploy or live manifest, portfolio-gate
change, portfolio admission, or correlation waiver.

## 11. Build History

| Version | Date | Event |
|---|---|---|
| v1 | 2026-08-15 | Initial WTI/copper CADF residual-reversion build |
