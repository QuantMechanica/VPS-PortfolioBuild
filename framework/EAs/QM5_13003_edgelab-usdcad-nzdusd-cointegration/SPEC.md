# QM5_13003_edgelab-usdcad-nzdusd-cointegration - Strategy Spec

**EA ID:** QM5_13003
**Slug:** edgelab-usdcad-nzdusd-cointegration
**Source:** claude_cross_asset_discovery_2026-06-09 plus Chan cointegration pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-07-03

---

## 1. Strategy Logic

The EA trades the USDCAD.DWX and NZDUSD.DWX D1 cointegration spread. It
computes `S = ln(USDCAD) - beta * ln(NZDUSD)` with beta defaulting to
`-0.423070732289`, then calculates a 60-bar rolling z-score of that spread.

It opens a short-spread package when z is above +2.0 and a long-spread package
when z is below -2.0. Because beta is negative, the second-leg hedge direction is
sign-aware: long spread means long USDCAD and long NZDUSD; short spread means
short both legs. Each leg carries a 2.0 * ATR(20, D1) protective stop.

This is the next unbuilt strict row from a full rerun of the 66-pair scan that
includes negative hedge ratios. The original published positive-hedge scan only
certified QM5_12533 and QM5_12532. The full rerun measured USDCAD/NZDUSD with
DEV Sharpe 0.4613, OOS net Sharpe 1.1259, OOS return 4.6620%, 21 OOS state
changes, beta -0.423071, and 54.67-day half-life.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_z_lookback_d1 | 60 | 20+ | D1 bars used for rolling spread mean and standard deviation |
| strategy_beta | -0.423070732289 | non-zero | Hedge coefficient in `ln(USDCAD) - beta * ln(NZDUSD)` |
| strategy_entry_z | 2.0 | >0 | Absolute z-score threshold for opening a spread package |
| strategy_exit_z | 0.5 | >=0 | Absolute z-score threshold for closing the open package |
| strategy_atr_period_d1 | 20 | 2+ | D1 ATR period for per-leg hard stop distance |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for each leg's hard stop |
| strategy_deviation_points | 20 | 0+ | Broker deviation points for market leg entries |

---

## 3. Symbol Universe

**Designed for:**
- USDCAD.DWX - leg 1 of the fixed USDCAD/NZDUSD spread and the spread numerator.
- NZDUSD.DWX - leg 2 of the fixed USDCAD/NZDUSD spread and the beta-weighted spread denominator.

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
| Trades / year / logical basket | 6-10 |
| Typical hold time | days to weeks |
| Expected drawdown profile | high; Q02/Q04/Q05 must judge whether this residual is tradable after cost |
| Regime preference | USD/commodity-risk residual between CAD and NZD exposures |
| Win rate target | medium |

---

## 6. Source Citation

Primary method source:
- Chan, Ernest P. (2009). *Quantitative Trading*. Wiley. Chapter 7, stationarity and cointegration pair trading; examples 3.6, 7.2, 7.5 as extracted in `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.

Pair-selection source:
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`, rerun on `D:/QM/mt5/T_Export/MQL5/Files` D1 data with negative hedge ratios retained.

Rerun excerpt for this candidate:

| pair | DEV Sharpe | OOS net Sharpe | OOS ret | OOS state changes | hedge | half-life |
|---|---:|---:|---:|---:|---:|---:|
| USDCAD~NZDUSD | 0.4613 | 1.1259 | 4.6620% | 21 | -0.423071 | 54.67d |

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
| v1 | 2026-07-03 | Initial full-scan next-unbuilt FX cointegration basket build | Built from the 12768 two-leg basket pattern with sign-aware negative-beta leg direction |
