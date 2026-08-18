# QM5_41058_xng-wflow-agree - Strategy Spec

EA ID: `QM5_41058`

Slug: `xng-wflow-agree`

Strategy ID: `WILLIAMS-MOP-XNG-WFLOW-2026_S01`

Source: `WILLIAMS-MOP-XNG-WFLOW-2026`

Author: Codex

Last revised: 2026-08-18

## 1. Strategy Logic

On the first executable `XNGUSD.DWX` D1 tick of a genuine normalized broker
Monday, reconstruct the exact completed prior Monday-through-Friday week plus
the preceding Friday close anchor. Sum the five completed close-to-open log
returns separately from the five completed open-to-close log returns and
reconcile their total to the completed weekly endpoint.

Buy only when both component sums are strictly positive and sell only when
both are strictly negative. Opposition, exact zero, failed reconciliation,
invalid uniform label normalization, a holiday-shifted week, late attachment,
or a consumed Monday remains flat.

One slot-0 XNG position carries a frozen `3.0 * ATR(20,D1)` hard stop, no
target, and framework Friday close at broker hour 21. A later-week boundary
and eight-calendar-day guard repair stale exposure.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | restart-safe Monday boundary |
| `strategy_reconcile_tolerance` | 1e-10 | component-to-week endpoint equality |
| `strategy_atr_period` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.0 | frozen hard-stop distance |
| `strategy_max_hold_days` | 8 | stale-position guard |
| `strategy_max_spread_points` | 3000 | XNG entry cost guard |
| `qm_friday_close_hour_broker` | 21 | ordinary weekly exit |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XNGUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `410580000`.
- No companion, read-only symbol, alias, or external market series.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Decision cadence: one consumed attempt per eligible normalized broker
  Monday.
- Formation: exact completed prior Monday-through-Friday week plus preceding
  Friday anchor.
- Hold: next Monday through broker Friday hour 21, with eight-day stale
  repair.

## 5. Expected Behaviour

- Approximately 15-30 completed positions per full post-warm-up year after
  strict component agreement and holiday exclusions.
- Symmetric weekly continuation; opposition and exact zero remain flat.
- One fixed-risk position at a time and no same-week retry.
- Q02 retires below five completed positions per full year.

## 6. Source Citation

Williams, Larry R. (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
Trading; and Moskowitz, Tobias J., Ooi, Yao Hua, and Pedersen, Lasse Heje
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/WILLIAMS-MOP-XNG-WFLOW-2026/source.md`.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses the frozen completed-bar ATR stop through the V5 risk
helper. Signal magnitude never scales risk. Both news axes are OFF. Friday
close is enabled at broker hour 21. The kill switch, broker hard stop,
malformed-state repair, later-week repair, and stale guard remain active.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, neutrality claim,
correlation waiver, portfolio-gate change, external feed, retry, scale-in,
grid, martingale, pyramid, target, trail, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | approved build directory identity | source `929a14cae`; registry `c32cc25b8`; magic `b2ae5243b`; G0/card `8a82c7968` |
| v1-build | 2026-08-18 | deterministic V5 implementation | exact-week XNG flow agreement with endpoint reconciliation |
