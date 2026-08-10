# QM5_20275_gsr-runfade — Strategy Spec

**EA ID:** QM5_20275

**Slug:** gsr-runfade

**Strategy ID:** SCHWEIKERT-CME-GSR-RUNFADE-2026_S04

**Source:** SCHWEIKERT-CME-GSR-RUN-2026

**Last revised:** 2026-08-11

## 1. Strategy Logic

Align seven completed D1 closes for `XAUUSD.DWX` and `XAGUSD.DWX` and form
`r[k]=ln(XAU[k])-ln(XAG[k])`, newest completed shift `k=1`. The six
chronological relative returns are `d[k]=r[k]-r[k+1]`.

A fresh upper run has `d[1..5]>0` and `d[6]<=0`; fade it with SELL XAU / BUY
XAG. A fresh lower run has `d[1..5]<0` and `d[6]>=0`; fade it with BUY XAU /
SELL XAG. Close on the first completed relative return against the original
run, invalid package/state, or after twelve calendar days.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `strategy_run_length_d1` | 5 | newest strict same-sign returns |
| `strategy_atr_period_d1` | 20 | completed-D1 ATR horizon |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg hard stop |
| `strategy_max_hold_days` | 12 | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 3000 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | paired-order deviation |

Every value is locked. There is no authorized parameter sweep.

## 3. Symbol Universe

The logical basket `QM5_20275_XAU_XAG_RUNFADE_D1` is fixed to
`XAUUSD.DWX` slot 0 / magic `202750000` and `XAGUSD.DWX` slot 1 / magic
`202750001`. `XAUUSD.DWX` is the D1 tester host. Standalone leg results are
invalid.

## 4. Timeframe

D1 only. All event and exit values use completed synchronized bars. Entry and
counter-return evaluation occur once per new host D1 bar.

## 5. Expected Behaviour

Expected cadence is approximately eight completed packages per full post-
warm-up year under a symmetric independent-sign reference. Q02 must
demonstrate at least five packages/year and valid two-leg execution or retire
the candidate. The package seeks relative-value exposure but claims neither
neutrality nor decorrelation.

## 6. Source Citation

Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; CME
Group, "Gold & Silver Ratio Spread." The bounded extraction is
`strategy-seeds/sources/SCHWEIKERT-CME-GSR-RUN-2026/source.md`.

The sources support the carrier, not the run event, parameters, CFD
equivalence, efficacy, neutrality, or portfolio fit.

## 7. Risk Model

Q02-Q10 use one aggregate `RISK_FIXED=1000` budget with `RISK_PERCENT=0` and
`PORTFOLIO_WEIGHT=1`. Each leg receives half the cash stop-risk after
independent `3.5*ATR(20,D1)` sizing. The EA closes orphan, duplicate,
same-side, wrong-side, or stopless packages immediately. Friday close is
disabled. No live setfile or live authorization exists.

## Framework Alignment

- no_trade: exact host/slot, framework contract, and locked inputs.
- trade_entry: synchronized ratios, exact fresh five-return event, consumed-
  event ledger, spreads, ATR sizing, and paired open.
- trade_management: package repair, first-counter-return close, invalid-state
  close, and twelve-day stale close.
- trade_close: package helper, broker hard stops, and framework kill switch.

## 8. Q01 Validation

Strict compilation passed with zero errors and zero warnings. The targeted
framework build check passed with zero failures and zero warnings, and the P1
artifact validator confirmed the EA directory and EX5 binary. No manual smoke
or backtest was run.

## 9. Q02 Handoff

One current-binary logical-basket Q02 row was enqueued at
`2026-08-10T23:14:52+00:00`: work item
`2384e96c-5240-4c0c-8829-c2fab47702b3`, attempt 0, no verdict, and
`priority_track=true`. Immediate readback was pending and unclaimed. The
binding pre-enqueue sample at `2026-08-10T23:14:38+00:00` found six executing
T1-T10 factory terminals against the ceiling of seven. This mission ran no
dispatch tick or manual backtest.
