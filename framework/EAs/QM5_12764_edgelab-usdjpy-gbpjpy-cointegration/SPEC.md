# QM5_12764_edgelab-usdjpy-gbpjpy-cointegration - Strategy Spec

**EA ID:** QM5_12764
**Slug:** edgelab-usdjpy-gbpjpy-cointegration
**Source:** claude_cross_asset_discovery_2026-06-09 plus Chan cointegration pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA trades the USDJPY.DWX and GBPJPY.DWX D1 cointegration spread. It computes
`S = ln(USDJPY) - beta * ln(GBPJPY)` with beta defaulting to 0.992629, then
calculates a 60-bar rolling z-score of that spread.

It opens a short-spread package when z is above +2.0 and a long-spread package
when z is below -2.0. It closes both legs when the cached spread z-score has
reverted inside +/-0.5. Each leg also carries a 2.0 * ATR(20, D1) protective
stop.

This is an exploratory next-best basket, not a hard-bar scan survivor. The
published 66-pair scan only certified QM5_12533 and QM5_12532. A rerun of the
same script ranked USDJPY/GBPJPY as the strongest remaining unbuilt
OOS-positive candidate after the existing
12532/12533/12624/12712/12723/12728/12731/12732/12735/12739/12747/12749/12751/12756/12758/12760/12762 baskets,
with DEV Sharpe -0.2377, OOS net Sharpe 0.0935, OOS return +0.8665%, 17 OOS state
changes, beta 0.992629, and 109.22-day half-life.

The negative DEV Sharpe and very low OOS Sharpe mean this did not clear the
original build discipline; it is a very high-risk exploratory sleeve built only
because the mission requested a
non-duplicate next-best FX cointegration pair after the strict survivors and
stronger exploratory candidates were already built.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_z_lookback_d1 | 60 | 20+ | D1 bars used for rolling spread mean and standard deviation |
| strategy_beta | 0.992629 | >0 | Hedge coefficient in `ln(USDJPY) - beta * ln(GBPJPY)` |
| strategy_entry_z | 2.0 | >0 | Absolute z-score threshold for opening a spread package |
| strategy_exit_z | 0.5 | >=0 | Absolute z-score threshold for closing the open package |
| strategy_atr_period_d1 | 20 | 2+ | D1 ATR period for per-leg hard stop distance |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for each leg's hard stop |
| strategy_deviation_points | 20 | 0+ | Broker deviation points for market leg entries |

---

## 3. Symbol Universe

**Designed for:**
- USDJPY.DWX - leg 1 of the fixed USDJPY/GBPJPY spread and the spread numerator.
- GBPJPY.DWX - leg 2 of the fixed USDJPY/GBPJPY spread and the beta-weighted spread denominator.

**Explicitly not for:**
- Other `.DWX` symbols. This card is a fixed two-leg FX-cross basket, not a portable multi-pair strategy.

USDJPY.DWX is also the conversion history for the GBPJPY leg under
USD-denominated tester accounting.

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
| Regime preference | low-conviction macro relative-value residual between dollar-yen and sterling-yen risk/funding expressions |
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
| USDJPY~GBPJPY | -0.2377 | 0.0935 | +0.8665% | 17 | 0.992629 | 109.22d |

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

Q02 queue note: `farmctl record-build` inserted one logical-basket work item
`dea115dd-02b5-4c27-a29f-98013541fc3c` for
`QM5_12764_USDJPY_GBPJPY_COINTEGRATION_D1` on 2026-06-29. No per-leg Q02
fanout was created.

Q02 payload repair note: on 2026-06-30 the existing pending row was updated in
place, not duplicated, with `priority_track=true`, `timeout_min=120`,
`tester_deposit=100000`, `risk_fixed=1000`, basket symbol count, and the
runtime multisymbol hint. The paced fleet still owns execution; no manual MT5
tester run was launched.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-29 | Initial next-best FX cointegration basket build | Built from the 12760 two-leg basket pattern |
| v1-q02 | 2026-06-29 | Build task 6876bf40-5fd9-4445-a7b4-b658b895fb88 recorded | Pending logical-basket work item dea115dd-02b5-4c27-a29f-98013541fc3c |
| v1-q02a | 2026-06-30 | Q02 payload priority repair | Existing pending work item repaired in place with basket priority, fixed-risk, tester deposit, timeout, and multisymbol hints |


