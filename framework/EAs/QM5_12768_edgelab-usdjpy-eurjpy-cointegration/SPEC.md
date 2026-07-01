# QM5_12768_edgelab-usdjpy-eurjpy-cointegration - Strategy Spec

**EA ID:** QM5_12768
**Slug:** edgelab-usdjpy-eurjpy-cointegration
**Source:** claude_cross_asset_discovery_2026-06-09 plus Chan cointegration pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-06-29

---

## 1. Strategy Logic

The EA trades the USDJPY.DWX and EURJPY.DWX D1 cointegration spread. It computes
`S = ln(USDJPY) - beta * ln(EURJPY)` with beta defaulting to 1.236712, then
calculates a 60-bar rolling z-score of that spread.

It opens a short-spread package when z is above +2.0 and a long-spread package
when z is below -2.0. It closes both legs when the cached spread z-score has
reverted inside +/-0.5. Each leg also carries a 2.0 * ATR(20, D1) protective
stop.

This is an exploratory next-best basket, not a hard-bar scan survivor. The
published 66-pair scan only certified QM5_12533 and QM5_12532. A rerun of the
same script ranked USDJPY/EURJPY as the next unbuilt rank-21 tail candidate
after the existing
12532/12533/12624/12712/12723/12728/12731/12732/12735/12739/12747/12749/12751/12756/12758/12760/12762/12764/12765/12766
baskets, with DEV Sharpe 0.4669, OOS net Sharpe -0.1174, OOS return -1.0184%,
17 OOS state changes, beta 1.236712, and 137.40-day half-life.

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
| strategy_beta | 1.236712 | >0 | Hedge coefficient in `ln(USDJPY) - beta * ln(EURJPY)` |
| strategy_entry_z | 2.0 | >0 | Absolute z-score threshold for opening a spread package |
| strategy_exit_z | 0.5 | >=0 | Absolute z-score threshold for closing the open package |
| strategy_atr_period_d1 | 20 | 2+ | D1 ATR period for per-leg hard stop distance |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for each leg's hard stop |
| strategy_deviation_points | 20 | 0+ | Broker deviation points for market leg entries |

---

## 3. Symbol Universe

**Designed for:**
- USDJPY.DWX - leg 1 of the fixed USDJPY/EURJPY spread and the spread numerator.
- EURJPY.DWX - leg 2 of the fixed USDJPY/EURJPY spread and the beta-weighted spread denominator.

**Explicitly not for:**
- Other `.DWX` symbols. This card is a fixed two-leg FX-cross basket, not a portable multi-pair strategy.

USDJPY.DWX is also the conversion history for the EURJPY leg under
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
| Regime preference | low-conviction macro relative-value residual between dollar-yen and euro-yen rate/risk expressions |
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
| USDJPY~EURJPY | 0.4669 | -0.1174 | -1.0184% | 17 | 1.236712 | 137.40d |

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

Q02 queue note: build task `50b8f15b-11ff-4cf3-ae31-4f8534ce5a82`
was recorded and enqueued one logical-basket Q02 work item for
`QM5_12768_USDJPY_EURJPY_COINTEGRATION_D1`:
`93909a80-8ce6-4e95-be28-889f8dc17a7d`. No per-leg Q02 fanout was
created.

Q02 payload repair note: on 2026-06-29 the existing pending work item
`93909a80-8ce6-4e95-be28-889f8dc17a7d` was updated in place after
`build_check.ps1 -SkipCompile` PASS. The payload now carries the full logical
basket metadata (`portfolio_scope=basket`, both basket legs, host symbol,
tester deposit/currency, `RISK_FIXED=1000`, 120 minute basket timeout, and
priority tracking). No duplicate Q02 row or manual MT5 launch was created.

Q04 requeue note: Q02 completed PASS. The existing Q04 work item
`190f8061-7947-48b3-b9c2-c7cc3742d877` was requeued in place on 2026-07-01
after the prior retry returned `INFRA_FAIL` from fold F1
`NO_HISTORY/REPORT_MISSING` output while F2 and F3 produced valid reports. No
duplicate Q04 row or manual MT5 launch was created; the row is pending for the
paced worker fleet.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-29 | Initial rank-21 next-unbuilt FX cointegration basket build | Built from the 12764 two-leg JPY-cross basket pattern |
| v1-q02 | 2026-06-29 | Compile/build-check PASS and Q02 enqueued | Pending logical-basket work item 93909a80-8ce6-4e95-be28-889f8dc17a7d |
| v1-q02-payload | 2026-06-29 | Repaired existing pending Q02 payload | Added full basket/runtime metadata in place; duplicate guard left one pending/active logical Q02 row |
| v1-q04-requeue | 2026-07-01 | Requeued existing Q04 row after infra invalid summary | Q04 work item 190f8061-7947-48b3-b9c2-c7cc3742d877 pending; no duplicate row inserted |


