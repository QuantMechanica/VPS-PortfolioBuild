# QM5_13062_audcad-eurusd-coint - Strategy Spec

**EA ID:** QM5_13062
**Slug:** audcad-eurusd-coint
**Source:** QM-COINT-SCREEN-EXT-2026-07-06_AUDCAD-EURUSD plus Chan cointegration pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-07-08

---

## 1. Strategy Logic

The EA trades the AUDCAD.DWX and EURUSD.DWX D1 cointegration spread. It
computes `S = ln(AUDCAD) - beta * ln(EURUSD)` with beta defaulting to
`0.5301`, then calculates a 60-bar rolling z-score of that spread.

It opens a short-spread package when z is above +2.0 and a long-spread package
when z is below -2.0. Because beta is positive, the second-leg hedge direction is
sign-aware: long spread means long AUDCAD and short EURUSD; short spread means
short AUDCAD and long EURUSD. Each leg carries a 2.0 * ATR(20, D1) protective
stop.

The extended FX cointegration screen labels AUDCAD/EURUSD as the only unbuilt
formal survivor in the 2026-07-06 run. It passed both half-sample ADF tests,
kept hedge sign stable, produced 43 rolling-z excursions across the scan window,
and had a 51.4 day half-life. The reason this route is high risk is also
explicit: the v3 fixed-hedge mechanics were positive in DEV but negative OOS
with OOS net Sharpe -0.39 and OOS return -4.94%.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_z_lookback_d1 | 60 | 20+ | D1 bars used for rolling spread mean and standard deviation |
| strategy_beta | 0.5301 | non-zero | Hedge coefficient in `ln(AUDCAD) - beta * ln(EURUSD)` |
| strategy_entry_z | 2.0 | >0 | Absolute z-score threshold for opening a spread package |
| strategy_exit_z | 0.5 | >=0 | Absolute z-score threshold for closing the open package |
| strategy_atr_period_d1 | 20 | 2+ | D1 ATR period for per-leg hard stop distance |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for each leg's hard stop |
| strategy_deviation_points | 20 | 0+ | Broker deviation points for market leg entries |

---

## 3. Symbol Universe

**Designed for:**
- AUDCAD.DWX - leg 1 of the fixed AUDCAD/EURUSD spread and the spread numerator.
- EURUSD.DWX - leg 2 of the fixed AUDCAD/EURUSD spread and the beta-weighted spread denominator.

**History/conversion dependency:**
- USDCAD.DWX - CAD profit-currency conversion support for USD tester accounting.

**Explicitly not for:**
- Other `.DWX` symbols. This card is a fixed two-leg FX basket, not a portable multi-pair strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / logical basket | 4-8 |
| Typical hold time | weeks to months |
| Expected drawdown profile | high; Q02/Q04/Q05 must judge whether this residual is tradable after cost |
| Regime preference | commodity-bloc AUD/CAD residual versus broad EUR/USD risk-dollar exposure |
| Win rate target | medium |

---

## 6. Source Citation

Primary method source:
- Chan, Ernest P. (2009). *Quantitative Trading*. Wiley. Chapter 7, stationarity and cointegration pair trading; examples 3.6, 7.2, 7.5 as extracted in `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.

Pair-selection source:
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `D:/QM/strategy_farm/artifacts/research/coint_screen_ext_20260706/results_full.csv`
- `D:/QM/strategy_farm/artifacts/research/coint_screen_ext_20260706/survivors.json`

Screen excerpt for this candidate:

| pair | half ADF t1 | half ADF t2 | rolling z excursions | half-life | hedge | OOS net Sharpe | OOS ret | OOS state changes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| AUDCAD~EURUSD | -3.337 | -3.683 | 43 | 51.4d | 0.5301 | -0.39 | -4.94% | 20 |

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | USD 1,000 per basket trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

Q02 tester note: the manifest pins `tester_currency=USD` and
`tester_deposit=100000`. The logical basket backtest setfile uses the canonical
`RISK_FIXED=1000`, with `RISK_PERCENT=0`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Initial extended-screen FX cointegration basket build | Built from the 13058 two-leg basket pattern with sign-aware positive-beta leg direction |

