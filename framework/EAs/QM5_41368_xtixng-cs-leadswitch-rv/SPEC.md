# QM5_41368_xtixng-cs-leadswitch-rv - Strategy Spec

**EA ID:** QM5_41368  
**Slug:** `xtixng-cs-leadswitch-rv`  
**Strategy ID:** `AI-CODEX-XTIXNG-CS-LEADSWITCH-RV-20260906_S01`  
**Source:** `AI-CODEX-XTIXNG-CS-LEADSWITCH-RV-20260906`  
**Author:** Codex  
**Last revised:** 2026-09-06

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
the final synchronized XTI/XNG close pairs from the three immediately
preceding consecutive broker weeks. Each week must contain three to five
synchronized sessions. Compute the two consecutive weekly log-return pairs.

Both energy contracts must share a strict sign inside each week, while the
strict relative winner must switch between weeks. Fade the newest relative
winner for one broker week. Equality within `1e-10`, mixed signs inside either
week, zero, invalid endpoints, or late attachment consumes the week flat. The
package targets equal absolute notionals, shares one fixed-risk budget, and
carries frozen per-leg ATR stops.

## 2. Parameters

| Parameter | Value |
|---|---:|
| `strategy_history_bars_d1` | 40 |
| `strategy_min_sessions_per_week` | 3 |
| `strategy_max_sessions_per_week` | 5 |
| `strategy_signal_epsilon` | 1e-10 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_notional_ratio` | 1.0 |
| `strategy_max_notional_mismatch_pct` | 20.0 |
| `strategy_max_hold_days` | 10 |
| `strategy_xti_max_spread_points` | 1500 |
| `strategy_xng_max_spread_points` | 3000 |
| `qm_friday_close_enabled` | false |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host: exact `XTIUSD.DWX`, D1, slot 0.
- Companion: exact `XNGUSD.DWX`, D1, slot 1.
- Logical symbol: `QM5_41368_XTI_XNG_CS_LEADSWITCH_RV_D1`.
- The package is one two-leg research position; neither leg is standalone.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: two individual weekly return pairs from three synchronized
  completed-week endpoints.
- Trigger: both legs share a strict sign in both weeks and the relative-return
  difference changes strict sign beyond `1e-10`.
- Direction: sell the newest relative winner and buy the loser.
- Hold: first tick of the next broker week, with a ten-day stale repair.

## 5. Expected Behaviour

- Approximately five to twelve completed packages per full post-warm-up year;
  Q02 retires below five.
- Symmetric opposed-leg oil/gas reversion after common-direction leadership
  rotates.
- One fixed-risk package and one consumed attempt per broker week.
- Equal notional does not prove neutrality or decorrelation; Q09 alone owns
  realized portfolio correlation.

## 6. Source Citation

Fuertes, Miffre, and Rallis (*Journal of Banking & Finance*, 2010, DOI
`10.1016/j.jbankfin.2010.04.009`) support commodity relative-return research.
Villar/Joutz (U.S. EIA, 2006) and Ramberg/Parsons (*The Energy Journal*, 2012,
DOI `10.5547/01956574.33.2.2`) support a weak, time-varying oil/gas
relationship and preserve adverse instability. The exact two-week leader-
switch fade is an untested QM translation; no source result transfers.

Canonical packet:
`strategy-seeds/sources/AI-CODEX-XTIXNG-CS-LEADSWITCH-RV-20260906/source.md`.

## 7. Risk Model And Scope

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes and Friday close are OFF. Each leg uses a
frozen `3.5*ATR(20,D1)` hard stop, with lots rounded down under the one-package
risk cap.

No live/demo/shadow/stress/optimization setfile, manual backtest, AutoTrading,
`T_Live`, deploy/live manifest, portfolio-gate change, portfolio admission,
correlation waiver, external feed, retry, scale-in, grid, pyramid, target,
trail, break-even move, or partial exit is authorized.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-09-06 | approved build identity |
