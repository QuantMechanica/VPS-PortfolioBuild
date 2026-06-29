# QM5_12770_edgelab-eurusd-eurgbp-cointegration - Strategy Spec

**EA ID:** QM5_12770
**Slug:** edgelab-eurusd-eurgbp-cointegration
**Source:** claude_cross_asset_discovery_2026-06-09 plus Chan cointegration pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-06-29

---

## 1. Strategy Logic

The EA trades the EURUSD.DWX and EURGBP.DWX D1 cointegration spread. It
computes `S = ln(EURUSD) - beta * ln(EURGBP)` with beta defaulting to
0.601215, then calculates a 60-bar rolling z-score of that spread.

It opens a short-spread package when z is above +2.0 and a long-spread package
when z is below -2.0. It closes both legs when the cached spread z-score has
reverted inside +/-0.5. Each leg also carries a 2.0 * ATR(20, D1) protective
stop.

This is an exploratory next-best basket, not a hard-bar scan survivor. The
published 66-pair scan only certified QM5_12533 and QM5_12532. A rerun of the
same script ranked EURUSD/EURGBP as the next unbuilt rank-22 tail candidate
after the existing
12532/12533/12624/12712/12723/12728/12731/12732/12735/12739/12747/12749/12751/12756/12758/12760/12762/12764/12765/12766/12768
baskets, with DEV Sharpe -0.0833, OOS net Sharpe -0.1761, OOS return -1.4936%,
17 OOS state changes, beta 0.601215, and 149.27-day half-life.

The negative DEV and OOS Sharpe mean this did not clear the original build
discipline; it is a very high-risk exploratory sleeve built only because the
mission requested a non-duplicate next-best FX cointegration pair after the
strict survivors and stronger exploratory candidates were already built.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_z_lookback_d1 | 60 | 20+ | D1 bars used for rolling spread mean and standard deviation |
| strategy_beta | 0.601215 | >0 | Hedge coefficient in `ln(EURUSD) - beta * ln(EURGBP)` |
| strategy_entry_z | 2.0 | >0 | Absolute z-score threshold for opening a spread package |
| strategy_exit_z | 0.5 | >=0 | Absolute z-score threshold for closing the open package |
| strategy_atr_period_d1 | 20 | 2+ | D1 ATR period for per-leg hard stop distance |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for each leg's hard stop |
| strategy_deviation_points | 20 | 0+ | Broker deviation points for market leg entries |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - leg 1 of the fixed EURUSD/EURGBP spread and the spread numerator.
- EURGBP.DWX - leg 2 of the fixed EURUSD/EURGBP spread and the beta-weighted spread denominator.

**Explicitly not for:**
- Other `.DWX` symbols. This card is a fixed two-leg FX-cross basket, not a portable multi-pair strategy.

The manifest selects GBPUSD.DWX as conversion history for USD-denominated tester
accounting of the EURGBP leg.

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
| Typical hold time | days to weeks |
| Expected drawdown profile | very high; Q02/Q04/Q05 must judge whether this negative-OOS residual is tradable after cost |
| Regime preference | weak EUR base-side residual between EURUSD and EURGBP |
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
| EURUSD~EURGBP | -0.0833 | -0.1761 | -1.4936% | 17 | 0.601215 | 149.27d |

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

No manual tester run was launched from this build session; Q02 is enqueued by
`farmctl record-build`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-29 | Initial rank-22 next-unbuilt FX cointegration basket build | Built from the 12768 two-leg basket pattern |
