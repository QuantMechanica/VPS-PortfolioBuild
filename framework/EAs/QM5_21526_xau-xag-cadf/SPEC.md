# QM5_21526_xau-xag-cadf - Strategy Spec

**EA ID:** QM5_21526  
**Slug:** xau-xag-cadf  
**Strategy ID:** CHAN-SCHWEIKERT-XAUXAG-CADF-2026_S01  
**Sources:** Chan (2009); Schweikert (2018); Yaya, Vo, and Olayinka
(2021); CME Group  
**Last revised:** 2026-08-15

## 1. Strategy Logic

The EA runs one D1 logical gold/silver basket from `XAUUSD.DWX`. For each
broker calendar year it reconstructs the first host D1 bar, selects exactly
252 synchronized completed observations strictly before that anchor, and
fits:

```text
log(XAU_t) = alpha + beta*log(XAG_t) + residual_t
delta(residual_t) = c + rho*residual_(t-1)
                    + psi*delta(residual_(t-1)) + error_t
delta(residual_t) = theta*(residual_(t-1) - residual_mean) + noise_t
half_life = -log(2) / theta
```

The annual state requires beta in `[0.10,3.00]`, the one-lag CADF
`t_rho <= -3.343`, negative theta, and fitted half-life in `[2,30]`. Alpha,
beta, residual mean, sample standard deviation, CADF statistic, theta, and
half-life are frozen through the year. Restart reconstructs the same anchor;
there is no sliding intrayear fit.

A fresh z-score cross above `+1.0` sells gold and buys silver. A fresh cross
below `-1.0` buys gold and sells silver. The package closes at
`abs(z) <= 0.5`, after `ceil(fitted_half_life)` calendar days, at annual
rollover, or when data, model, or package state becomes invalid.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| strategy_training_bars | 252 | exact synchronized pre-year formation observations |
| strategy_cadf_critical | -3.343 | governed 5% two-variable one-lag boundary |
| strategy_entry_z / strategy_exit_z | 1.0 / 0.5 | fresh excursion and convergence boundaries |
| strategy_beta_min / max | 0.10 / 3.00 | positive hedge-ratio bounds |
| strategy_half_life_min / max | 2.0 / 30.0 | admissible fitted speed and time-stop basis |
| strategy_history_bars_d1 | 900 | bounded annual reconstruction buffer |
| strategy_max_endpoint_gap_days | 10 | completed synchronized endpoint freshness |
| strategy_atr_period_d1 / strategy_atr_sl_mult | 20 / 3.5 | frozen D1 hard stops |
| strategy_xau_max_spread_points | 1500 | gold entry spread cap |
| strategy_xag_max_spread_points | 1500 | silver entry spread cap |
| strategy_deviation_points | 20 | paired-order deviation |

The Q02 baseline also locks `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, seed 42, host slot zero, both news axes OFF, legacy news
OFF, Friday close OFF, and stress rejection zero.

## 3. Symbol Universe

- Logical symbol: `QM5_21526_XAU_XAG_CADF_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `215260000`.
- Companion/traded slot 1: `XAGUSD.DWX`, D1, magic `215260001`.

No other host, symbol, carrier, or magic is authorized.

## 4. Timeframe And Data Contract

The host and both signal histories are D1. The current bar is excluded from
signals. Formation and signal timestamps must match exactly across both legs,
be strictly chronological, contain positive finite closes, and use no signal
observation in the training sample. The newest completed synchronized signal
may be no more than ten calendar days behind the current host bar.

The annual anchor is the earliest host D1 timestamp in the current broker
year. Exactly the nearest 252 synchronized observations before it form the
model. An available but statistically rejected formation sample is frozen as
rejected for the year; only genuinely unavailable history may be retried on a
later D1 bar.

## 5. Expected Behaviour

The prior is eight to twenty completed packages per full post-warm-up year.
Q02 must retire on zero trades, fewer than five packages/year, or nonpositive
governed economics. Expected exposure is episodic opposing precious-metal
legs, not a second outright-gold trend stream.

Opposite directions and beta-weighted stop risk do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Only the unchanged later
portfolio-correlation gate may establish realized diversification.

## 6. Source Citation

Chan supplies the OLS/CADF frozen-training pair-trading method, standardized
residual fade, mean-band exit, and fitted half-life discipline. Schweikert and
Yaya, Vo, and Olayinka support only a state-dependent long-run gold/silver
relationship; CME supports only the intermarket carrier. None tests this
Darwinex CFD implementation or transfers a coefficient, performance,
density, cost, neutrality, or correlation claim.

The governed composite packet is
`strategy-seeds/sources/CHAN-SCHWEIKERT-XAUXAG-CADF-2026/source.md` and the
approved execution contract is
`strategy-seeds/cards/approved/QM5_21526_xau-xag-cadf_card.md`.

## 7. Risk Model

One package receives exactly one aggregate `RISK_FIXED=1000` budget. Gold's
relative stop-risk weight is `1.0`; silver's is `abs(beta)`. Normalized shares
are sized independently to frozen `3.5*ATR(20,D1)` broker hard stops. There is
no take-profit, trailing stop, break-even, partial close, scale-in, grid,
martingale, pyramid, or risk escalation.

Residual instability, CFD/futures basis, contract-size mismatch, gaps,
financing, legging, lot granularity, asymmetric hard-stop execution, and
continued correlation with the incumbent XAU sleeve remain material risks.

## 8. Entry And Lifecycle

- A positive fresh residual cross opens SELL XAU, then BUY XAG.
- A negative fresh residual cross opens BUY XAU, then SELL XAG.
- The completed signal timestamp is persisted before deal-history, spread,
  quote, ATR, sizing, or order gates. A failure or restart cannot retry it.
- The terminal marker is backed by exact signal tags in entry-deal history.
  Tester initialization removes a marker from the future of a restarted
  historical run.
- The EA retains a package only when exactly one correctly directed position
  with a valid hard stop exists in each registered slot. Any partial or
  malformed package is flattened through framework close helpers.

## 9. Four-Module Mapping

- No-Trade: exact host/D1/ID/slot, locked inputs, risk/news/Friday/stress
  contract, registered magics, and basket-scope guards.
- Entry: annual reconstruction, OLS/CADF/OU admission, frozen z-score fresh
  crossing, consumed-signal state, spread/quote/ATR checks, aggregate fixed
  risk split, hard stops, ordered leg opening, and rollback.
- Management: no stop or size mutation; package integrity is checked by the
  close path on every tick.
- Close: orphan/malformed repair, annual rollover, invalid model/data,
  convergence, and fitted time stop; broker hard stops remain authoritative.

## 10. Safety Boundary

This build authorizes one fixed-risk backtest setfile and one paced Q02
enqueue only. It does not authorize a manual tester run, live/demo/shadow/
stress/optimization setfile, AutoTrading, `T_Live`, deploy or live manifest,
portfolio-gate change, portfolio admission, or correlation waiver.

## 11. Build History

| Version | Date | Event |
|---|---|---|
| v1 | 2026-08-15 | Initial annual-frozen XAU/XAG CADF residual-reversion build |

