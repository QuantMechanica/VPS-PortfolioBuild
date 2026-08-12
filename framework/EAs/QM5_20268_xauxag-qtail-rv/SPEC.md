# QM5_20268_xauxag-qtail-rv — Strategy Spec

**EA ID:** QM5_20268

**Slug:** xauxag-qtail-rv

**Strategy ID:** SCHWEIKERT-CME-XAUXAG-QTAILRV-2026_S03

**Source:** SCHWEIKERT-CME-XAUXAG-QTAIL-2026

**Last revised:** 2026-08-09

## 1. Strategy Logic

Align 129 completed D1 closes for `XAUUSD.DWX` and `XAGUSD.DWX` and form
`ln(XAU)-ln(XAG)`. Sort only shifts 4 through 129. The frozen 126-observation
reference uses zero-based order-statistic indexes 12 and 113 for its nearest-
rank outer deciles. If shift 3 was within the decile band and shifts 2 and 1
both close strictly beyond the same tail, fade the ratio with opposite legs.

Close through the median of the newest twenty-one synchronized ratios, on
invalid state/package composition, or after thirty-five calendar days.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `strategy_reference_bars_d1` | 126 | frozen pre-event ratios |
| `strategy_lower_index` | 12 | zero-based tenth-percentile index |
| `strategy_upper_index` | 113 | zero-based ninetieth-percentile index |
| `strategy_exit_median_bars_d1` | 21 | rolling convergence center |
| `strategy_quantile_epsilon` | 1e-12 | minimum ordered-boundary width |
| `strategy_atr_period_d1` | 20 | completed-D1 ATR horizon |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg hard stop |
| `strategy_max_hold_days` | 35 | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 3000 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | order deviation |

Every value is locked. There is no authorized parameter sweep.

## 3. Symbol Universe

The logical basket `QM5_20268_XAU_XAG_QTAILRV_D1` is fixed to
`XAUUSD.DWX` slot 0 / magic `202680000` and `XAGUSD.DWX` slot 1 / magic
`202680001`. `XAUUSD.DWX` is the D1 tester host. Standalone leg results are
invalid.

## 4. Timeframe

D1 only. All signal and exit values use completed synchronized bars. Entry and
convergence evaluation occur once per new host D1 bar.

## 5. Expected Behaviour

Expected cadence is five to twelve completed packages per full post-warm-up
year. Q02 must demonstrate at least five packages/year and valid two-leg
execution or retire the candidate. The package seeks relative-value exposure
but claims neither neutrality nor decorrelation.

## 6. Source Citation

Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; CME
Group, "Gold & Silver Ratio Spread." The bounded extraction is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-QTAIL-2026/source.md`.

The sources support the carrier, not the empirical-tail event, parameters,
CFD equivalence, efficacy, neutrality, or portfolio fit.

## 7. Risk Model

Q02-Q10 use one aggregate `RISK_FIXED=1000` budget with `RISK_PERCENT=0` and
`PORTFOLIO_WEIGHT=1`. Each leg receives half the cash stop-risk after
independent `3.5*ATR(20,D1)` sizing. The EA closes orphan, duplicate,
same-side, wrong-side, or stopless packages immediately. Friday close is
disabled. No live setfile or live authorization exists.

## Framework Alignment

- no_trade: exact host/slot, framework contract, and locked inputs.
- trade_entry: synchronized ratios, frozen empirical deciles, ordered two-hit
  event, consumed-bar ledger, spreads, ATR sizing, and paired open.
- trade_management: package repair, rolling-median convergence, invalid-state
  close, and thirty-five-day stale close.
- trade_close: package helper, broker hard stops, and framework kill switch.
