# QM5_20263_xauxag-mad-rv — Strategy Spec

**EA ID:** QM5_20263

**Slug:** xauxag-mad-rv

**Source:** SCHWEIKERT-CME-XAUXAG-MAD-2026

**Last revised:** 2026-08-07

## 1. Strategy Logic

Align 64 completed D1 closes for `XAUUSD.DWX` and `XAGUSD.DWX`. For the
current shifts 1-63 and prior shifts 2-64 independently, compute the
gold-minus-silver log ratio's median, median absolute deviation, and robust
score `0.6744897501960817*(latest-median)/MAD`. A fresh crossing above +2.0
sells XAU and buys XAG; a fresh crossing below -2.0 buys XAU and sells XAG.
Close after convergence inside +/-0.5, invalid package/state, or 45 days.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `strategy_ratio_window_d1` | 63 | odd completed-D1 robust window |
| `strategy_mad_scale` | 0.6744897501960817 | fixed normal-consistency factor |
| `strategy_entry_robust_z` | 2.0 | fresh-cross entry threshold |
| `strategy_exit_robust_z` | 0.5 | convergence threshold |
| `strategy_mad_epsilon` | 1e-12 | invalid MAD floor |
| `strategy_atr_period_d1` | 20 | completed-D1 ATR horizon |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg hard stop |
| `strategy_max_hold_days` | 45 | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 3000 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | order deviation |

Every value is locked. There is no authorized parameter sweep.

## 3. Symbol Universe

The logical basket `QM5_20263_XAU_XAG_MADRV_D1` is fixed to
`XAUUSD.DWX` slot 0 / magic `202630000` and `XAGUSD.DWX` slot 1 / magic
`202630001`. `XAUUSD.DWX` is the D1 tester host. Both legs are evaluated as
one package; standalone leg results are invalid.

## 4. Timeframe

D1 only. Signal windows begin at shift 1, so the forming bar is excluded.
The current and prior windows have independent center and scale estimates.
Entry evaluation occurs once per new host D1 bar.

## 5. Expected Behaviour

Expected cadence is 5-12 completed packages/year after 64 completed D1 bars,
held for days to weeks. Q02 must demonstrate at least five packages/year and
valid two-leg execution or retire the candidate. The package seeks robust
relative-value exposure but claims neither neutrality nor decorrelation.

## 6. Source Citation

Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; CME
Group, "Gold & Silver Ratio Spread." The bounded extraction is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MAD-2026/source.md`.

## 7. Risk Model

Q02-Q10 use one aggregate `RISK_FIXED=1000` budget with
`RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`. Each leg receives half the cash
risk after independent `3.5*ATR(20,D1)` sizing and a frozen broker hard stop.
The EA closes orphan, duplicate, wrong-side, or stopless packages immediately.
Friday close is disabled for multi-day convergence. No live setfile or live
authorization exists.
