# QM5_41062_xauxag-wgap-fade - Strategy Spec

EA ID: `QM5_41062`

Slug: `xauxag-wgap-fade`

Strategy ID: `BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026_S01`

Source: `BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026`

Author: Codex

Last revised: 2026-08-20

## 1. Strategy Logic

On the first executable tick of a genuine synchronized XAU/XAG broker-Monday
D1 bar, compute each metal's log gap from the immediately prior synchronized
Friday close to the current Monday open. Trade only when the component gaps
have strictly opposite signs, fading the resulting ratio dislocation: sell
the metal that gapped up and buy the metal that gapped down.

One restart-safe attempt is consumed per broker Monday. The two legs target
equal absolute USD notionals, share one fixed-risk budget, carry frozen
`3.0 * ATR(20,D1)` hard stops, and close together at the next synchronized D1
boundary.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-Monday-D1 execution window |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.0 | frozen per-leg hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal absolute XAU/XAG entry notionals |
| `strategy_max_notional_mismatch_pct` | 20.0 | lot-step mismatch ceiling |
| `strategy_max_hold_days` | 4 | stale-package repair |
| `strategy_xau_max_spread_points` | 1500 | XAU entry cost guard |
| `strategy_xag_max_spread_points` | 500 | XAG entry cost guard |
| `qm_friday_close_enabled` | true | emergency framework guard |
| `qm_friday_close_hour_broker` | 21 | explicit broker close hour |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host: exact `XAUUSD.DWX`, D1, slot 0, magic `410620000`.
- Companion: exact `XAGUSD.DWX`, D1, slot 1, magic `410620001`.
- Both legs are traded as one logical equal-notional package.
- No alias, external market series, fitted beta, or one-leg fallback exists.

## 4. Timeframe

- Signal and execution timeframe: synchronized D1.
- Formation: exactly the prior Friday close and current Monday open.
- Trigger: strict sign opposition between the two component log gaps.
- Hold: first synchronized later D1 boundary, with a four-day stale repair.

## 5. Expected Behaviour

- Approximately five to twenty completed packages per full post-warm-up year.
- Two-sided market-neutral ratio-dislocation fade, not outright metal beta.
- One combined fixed-risk package and one consumed attempt per broker Monday.
- Q02 retires below five completed packages per full year.

## 6. Source Citation

Borowski, K. and Lukasik, M. (2017), "Analysis of Selected Seasonality Effects
in the Following Metal Markets," *Journal of Management and Financial
Sciences* 27, 59-86; Lucey, B. M. and Tully, E. (2006), "Seasonality, risk and
return in daily COMEX gold and silver data 1982-2002," *Applied Financial
Economics* 16(4), 319-333; Schweikert, K. (2018), "Are gold and silver
cointegrated?" *Journal of Banking & Finance* 88, 44-51.

Canonical bounded source packet:
`strategy-seeds/sources/BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026/source.md`.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` for the
complete package. Each leg receives at most half the cash-stop budget before
equal-notional down-rounding. Both news axes are OFF. Framework Friday close
is enabled only as an emergency guard; the ordinary exit is the next D1 bar.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation claim,
correlation waiver, portfolio-gate change, external feed, retry, scale-in,
grid, martingale, pyramid, target, trail, break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-20 | approved build-directory identity | source approval `fec22cf8d`; deterministic registry allocation |
