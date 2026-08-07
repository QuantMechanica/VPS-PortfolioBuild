# QM5_20265_xauxag-fail-rv — Strategy Spec

**EA ID:** QM5_20265

**Slug:** xauxag-fail-rv

**Strategy ID:** SCHWEIKERT-CME-XAUXAG-FAILRV-2026_S02

**Source:** SCHWEIKERT-CME-XAUXAG-FAIL-2026

**Last revised:** 2026-08-07

## 1. Strategy Logic

Align sixty-two completed D1 closes for `XAUUSD.DWX` and `XAGUSD.DWX` and
form `ln(XAU)-ln(XAG)`. Ratios at shifts 3 through 62 define a sixty-
observation range that predates both event bars. If shift 2 closed above that
range and shift 1 returned strictly inside, sell XAU and buy XAG. If shift 2
closed below and shift 1 returned strictly inside, buy XAU and sell XAG.

Close a short-ratio package when the newest completed ratio is at or below the
arithmetic mean of the newest twenty synchronized completed ratios. Close a
long-ratio package when it is at or above that mean. Invalid package/state or
thirty elapsed calendar days also closes both legs.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `strategy_channel_bars_d1` | 60 | pre-event ratio range |
| `strategy_exit_mean_bars_d1` | 20 | completed-ratio convergence center |
| `strategy_range_epsilon` | 1e-12 | invalid range-width floor |
| `strategy_atr_period_d1` | 20 | completed-D1 ATR horizon |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg hard stop |
| `strategy_max_hold_days` | 30 | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 3000 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | order deviation |

Every value is locked. There is no authorized parameter sweep.

## 3. Symbol Universe

The logical basket `QM5_20265_XAU_XAG_FAILRV_D1` is fixed to
`XAUUSD.DWX` slot 0 / magic `202650000` and `XAGUSD.DWX` slot 1 / magic
`202650001`. `XAUUSD.DWX` is the D1 tester host. Both legs are evaluated as
one package; standalone leg results are invalid.

## 4. Timeframe

D1 only. All signal values begin at completed shift 1. The sixty channel
values begin at shift 3, so neither event bar can contaminate the range.
Entry and convergence evaluation occur only once per new host D1 bar.

## 5. Expected Behaviour

Expected cadence is five to fifteen completed packages per full post-warm-up
year after sixty-two completed D1 bars, held for days to weeks. Q02 must
demonstrate at least five packages/year and valid two-leg execution or retire
the candidate. The package seeks structural relative-value exposure but
claims neither neutrality nor decorrelation.

## 6. Source Citation

Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; CME
Group, "Gold & Silver Ratio Spread." The bounded approved extraction is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-FAIL-2026/source.md`.

The sources support the relative-value carrier, not the failed-break rule,
locked parameters, CFD equivalence, efficacy, neutrality, or portfolio fit.

## 7. Risk Model

Q02-Q10 use one aggregate `RISK_FIXED=1000` budget with
`RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`. Each leg receives half the cash
risk after independent `3.5*ATR(20,D1)` sizing and a frozen broker hard stop.
The EA closes orphan, duplicate, wrong-side, or stopless packages immediately.
Friday close is disabled for multi-day convergence. No live setfile or live
authorization exists.

## Framework Alignment

- no_trade: exact host/slot, fixed framework inputs, locked strategy inputs,
  and native news/Friday/kill-switch orchestration.
- trade_entry: synchronized ratio load, uncontaminated pre-event channel,
  ordered failed-break re-entry, event ledger, spread/quote/ATR sizing, and
  atomic two-leg open.
- trade_management: package/stop repair, completed-ratio mean convergence,
  invalid-state close, and thirty-day stale close.
- trade_close: package close helper plus per-leg broker hard stops and
  framework kill switch.
