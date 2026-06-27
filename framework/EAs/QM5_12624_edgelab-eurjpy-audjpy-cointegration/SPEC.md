# QM5_12624_edgelab-eurjpy-audjpy-cointegration - Strategy Spec

**EA ID:** QM5_12624
**Slug:** edgelab-eurjpy-audjpy-cointegration
**Source:** claude_cross_asset_discovery_2026-06-09 plus Chan cointegration pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-06-27

---

## 1. Strategy Logic

The EA trades the EURJPY.DWX and AUDJPY.DWX D1 cointegration spread. It computes
`S = ln(EURJPY) - beta * ln(AUDJPY)` with beta defaulting to 0.60, then
calculates a 60-bar rolling z-score of that spread.

It opens a short-spread package when z is above +2.0 and a long-spread package
when z is below -2.0. It closes both legs when the cached spread z-score has
reverted inside +/-0.5. Each leg also carries a 2.0 * ATR(20, D1) protective
stop.

This is an exploratory next-best basket, not a hard-bar scan survivor. The
published 66-pair scan only certified QM5_12533 and QM5_12532. A rerun of the
same script ranked EURJPY/AUDJPY as a positive-DEV/OOS common-JPY candidate
with DEV Sharpe 0.62, OOS net Sharpe 0.58, OOS return +4.25%, 23 OOS trades,
beta 0.60, and 22-day half-life.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_z_lookback_d1 | 60 | 20+ | D1 bars used for rolling spread mean and standard deviation |
| strategy_beta | 0.60 | >0 | Hedge coefficient in `ln(EURJPY) - beta * ln(AUDJPY)` |
| strategy_entry_z | 2.0 | >0 | Absolute z-score threshold for opening a spread package |
| strategy_exit_z | 0.5 | >=0 | Absolute z-score threshold for closing the open package |
| strategy_atr_period_d1 | 20 | 2+ | D1 ATR period for per-leg hard stop distance |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for each leg's hard stop |
| strategy_deviation_points | 20 | 0+ | Broker deviation points for market leg entries |

---

## 3. Symbol Universe

**Designed for:**
- EURJPY.DWX - leg 1 of the fixed EURJPY/AUDJPY spread and the spread numerator.
- AUDJPY.DWX - leg 2 of the fixed EURJPY/AUDJPY spread and the beta-weighted spread denominator.

**Explicitly not for:**
- Other `.DWX` symbols. This card is a fixed two-leg FX-cross basket, not a portable multi-pair strategy.

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
| Trades / year / logical basket | 7-12 |
| Typical hold time | days to weeks |
| Expected drawdown profile | moderate; Q04/Q05 must judge stability because this is sub-threshold research |
| Regime preference | mean-reverting common-JPY spread |
| Win rate target | medium |

---

## 6. Source Citation

Primary method source:
- Chan, Ernest P. (2009). *Quantitative Trading*. Wiley. Chapter 7, stationarity and cointegration pair trading; examples 3.6, 7.2, 7.5 as extracted in `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.

Pair-selection source:
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`, rerun on `D:/QM/mt5/T_Export/MQL5/Files` D1 data.

Rerun excerpt for this candidate:

| pair | DEV Sharpe | OOS net Sharpe | OOS ret | OOS trades | hedge | half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURJPY~AUDJPY | 0.62 | 0.58 | +4.25% | 23 | 0.60 | 22d |

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | JPY 150,000 per basket trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

Q02 tester note: the manifest pins `tester_currency=JPY` and `tester_deposit=15000000`.
The logical basket backtest setfile uses `RISK_FIXED=150000`, the approximate JPY
equivalent of the canonical USD 1000 backtest risk, so lot sizing stays above
broker minimum volume under a JPY tester account.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-27 | Initial next-best FX cointegration basket build | Built from 12533 basket pattern |
