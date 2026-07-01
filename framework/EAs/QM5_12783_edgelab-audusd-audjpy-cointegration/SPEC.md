# QM5_12783_edgelab-audusd-audjpy-cointegration - Strategy Spec

**EA ID:** QM5_12783
**Slug:** edgelab-audusd-audjpy-cointegration
**Source:** claude_cross_asset_discovery_2026-06-09 plus Chan cointegration pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

The EA trades the AUDUSD.DWX and AUDJPY.DWX D1 cointegration spread. It computes
`S = ln(AUDUSD) - beta * ln(AUDJPY)` with beta defaulting to 0.236355, then
calculates a 60-bar rolling z-score of that spread.

It opens a short-spread package when z is above +2.0 and a long-spread package
when z is below -2.0. It closes both legs when the cached spread z-score has
reverted inside +/-0.5. Each leg also carries a 2.0 * ATR(20, D1) protective
stop.

This is an exploratory next-best basket, not a hard-bar scan survivor. The
published 66-pair scan only certified QM5_12533 and QM5_12532. A rerun of the
same script ranked AUDUSD/AUDJPY as the next unbuilt rank-27 tail candidate
after the existing
12532/12533/12624/12712/12723/12728/12731/12732/12735/12739/12747/12749/12751/12756/12758/12760/12762/12764/12765/12766/12768/12770/12772/12776/12778/12781
baskets, with DEV Sharpe 0.3295, OOS net Sharpe -0.3601, OOS return -3.8428%,
15 OOS state changes, beta 0.236355, and 139.55-day half-life.

The positive DEV Sharpe but negative OOS Sharpe mean this did not clear the
original build discipline; it is a very high-risk exploratory sleeve built only
because the mission requested a non-duplicate next-best FX cointegration pair
after the strict survivors and stronger exploratory candidates were already
built.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_z_lookback_d1 | 60 | 20+ | D1 bars used for rolling spread mean and standard deviation |
| strategy_beta | 0.236355 | >0 | Hedge coefficient in `ln(AUDUSD) - beta * ln(AUDJPY)` |
| strategy_entry_z | 2.0 | >0 | Absolute z-score threshold for opening a spread package |
| strategy_exit_z | 0.5 | >=0 | Absolute z-score threshold for closing the open package |
| strategy_atr_period_d1 | 20 | 2+ | D1 ATR period for per-leg hard stop distance |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for each leg's hard stop |
| strategy_deviation_points | 20 | 0+ | Broker deviation points for market leg entries |

---

## 3. Symbol Universe

**Designed for:**
- AUDUSD.DWX - leg 1 of the fixed AUDUSD/AUDJPY spread and the spread numerator.
- AUDJPY.DWX - leg 2 of the fixed AUDUSD/AUDJPY spread and the beta-weighted spread denominator.

**Explicitly not for:**
- Other `.DWX` symbols. This card is a fixed two-leg FX-cross basket, not a portable multi-pair strategy.

Q04 repair note: tester accounting is AUD so the two traded AUD-base symbols
provide the required conversion paths. USDJPY.DWX is intentionally not selected
or warmed by this EA.

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
| Expected drawdown profile | high; Q02/Q04/Q05 must judge whether this weak residual is tradable after cost |
| Regime preference | low-conviction macro relative-value residual between dollar-yen and Aussie-yen rate/risk expressions |
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
| AUDUSD~AUDJPY | 0.3295 | -0.3601 | -3.8428% | 15 | 0.236355 | 139.55d |

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | AUD 1,500 per basket trade, approximately the canonical USD 1,000 budget |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

Q04 tester repair note: the manifest pins `tester_currency=AUD` and
`tester_deposit=150000`. The logical basket backtest setfile uses
`RISK_FIXED=1500`, with `RISK_PERCENT=0`, to avoid bare `USDJPY` conversion
history pulls while preserving roughly the canonical USD 1,000 fixed-risk
budget.

Q02 was auto-enqueued by `farmctl record-build` after strict compile and
build-check passed. No manual MT5 run was launched from this build session; Q02
is delegated to paced farm workers through the logical basket setfile.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-29 | Initial rank-27 next-unbuilt FX cointegration basket build | Built from the adjacent AUDUSD/JPY basket pattern with explicit USDJPY conversion history |
| v2 | 2026-07-01 | Q04 AUD-account conversion repair | Removed obsolete USDJPY.DWX warmup, switched tester accounting to AUD, and set backtest fixed risk to AUD 1,500 |

