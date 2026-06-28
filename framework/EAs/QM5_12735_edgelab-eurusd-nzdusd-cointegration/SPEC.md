# QM5_12735_edgelab-eurusd-nzdusd-cointegration - Strategy Spec

**EA ID:** QM5_12735
**Slug:** edgelab-eurusd-nzdusd-cointegration
**Source:** claude_cross_asset_discovery_2026-06-09 plus Chan cointegration pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-06-28

---

## 1. Strategy Logic

The EA trades the EURUSD.DWX and NZDUSD.DWX D1 cointegration spread. It computes
`S = ln(EURUSD) - beta * ln(NZDUSD)` with beta defaulting to 0.81, then
calculates a 60-bar rolling z-score of that spread.

It opens a short-spread package when z is above +2.0 and a long-spread package
when z is below -2.0. It closes both legs when the cached spread z-score has
reverted inside +/-0.5. Each leg also carries a 2.0 * ATR(20, D1) protective
stop.

This is an exploratory next-best basket, not a hard-bar scan survivor. The
published 66-pair scan only certified QM5_12533 and QM5_12532. A rerun of the
same script ranked EURUSD/NZDUSD as the strongest remaining unbuilt positive
DEV/OOS candidate after the existing 12532/12533/12624/12712/12723/12728/12731/12732 baskets, with
DEV Sharpe 0.65, OOS net Sharpe 0.54, OOS return +2.81%, 20 OOS state changes,
beta 0.81, and 49-day half-life.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_z_lookback_d1 | 60 | 20+ | D1 bars used for rolling spread mean and standard deviation |
| strategy_beta | 0.81 | >0 | Hedge coefficient in `ln(EURUSD) - beta * ln(NZDUSD)` |
| strategy_entry_z | 2.0 | >0 | Absolute z-score threshold for opening a spread package |
| strategy_exit_z | 0.5 | >=0 | Absolute z-score threshold for closing the open package |
| strategy_atr_period_d1 | 20 | 2+ | D1 ATR period for per-leg hard stop distance |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for each leg's hard stop |
| strategy_deviation_points | 20 | 0+ | Broker deviation points for market leg entries |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - leg 1 of the fixed EURUSD/NZDUSD spread and the spread numerator.
- NZDUSD.DWX - leg 2 of the fixed EURUSD/NZDUSD spread and the beta-weighted spread denominator.

**Explicitly not for:**
- Other `.DWX` symbols. This card is a fixed two-leg FX-cross basket, not a portable multi-pair strategy.

The EA selects EURUSD.DWX and NZDUSD.DWX only; both legs have direct USD
settlement in the tester.

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
| Expected drawdown profile | moderate-high; Q04/Q05 must judge stability because this is sub-threshold research |
| Regime preference | mean-reverting EUR-vs-NZD USD-major relative-value relative-value spread |
| Win rate target | medium |

---

## 6. Source Citation

Primary method source:
- Chan, Ernest P. (2009). *Quantitative Trading*. Wiley. Chapter 7, stationarity and cointegration pair trading; examples 3.6, 7.2, 7.5 as extracted in `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.

Pair-selection source:
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`, rerun on `D:/QM/mt5/T_Export/MQL5/Files` D1 data.

Rerun excerpt for this candidate:

| pair | DEV Sharpe | OOS net Sharpe | OOS ret | OOS state changes | hedge | half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD~NZDUSD | 0.31 | 0.35 | +2.38% | 15 | 0.81 | 52d |

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
| v1 | 2026-06-28 | Initial next-best FX cointegration basket build | Built from the 12731 basket pattern |
