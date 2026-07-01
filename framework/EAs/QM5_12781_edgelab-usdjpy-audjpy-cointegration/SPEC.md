# QM5_12781_edgelab-usdjpy-audjpy-cointegration - Strategy Spec

**EA ID:** QM5_12781
**Slug:** edgelab-usdjpy-audjpy-cointegration
**Source:** claude_cross_asset_discovery_2026-06-09 plus Chan cointegration pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-06-29

---

## 1. Strategy Logic

The EA trades the USDJPY.DWX and AUDJPY.DWX D1 cointegration spread. It computes
`S = ln(USDJPY) - beta * ln(AUDJPY)` with beta defaulting to 0.763733, then
calculates a 60-bar rolling z-score of that spread.

It opens a short-spread package when z is above +2.0 and a long-spread package
when z is below -2.0. It closes both legs when the cached spread z-score has
reverted inside +/-0.5. Each leg also carries a 2.0 * ATR(20, D1) protective
stop.

This is an exploratory next-best basket, not a hard-bar scan survivor. The
published 66-pair scan only certified QM5_12533 and QM5_12532. A rerun of the
same script ranked USDJPY/AUDJPY as the next unbuilt rank-26 tail candidate
after the existing
12532/12533/12624/12712/12723/12728/12731/12732/12735/12739/12747/12749/12751/12756/12758/12760/12762/12764/12765/12766/12768/12770/12772/12776/12778
baskets, with DEV Sharpe 0.3587, OOS net Sharpe -0.3548, OOS return -3.8397%,
15 OOS state changes, beta 0.763733, and 139.63-day half-life.

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
| strategy_beta | 0.763733 | >0 | Hedge coefficient in `ln(USDJPY) - beta * ln(AUDJPY)` |
| strategy_entry_z | 2.0 | >0 | Absolute z-score threshold for opening a spread package |
| strategy_exit_z | 0.5 | >=0 | Absolute z-score threshold for closing the open package |
| strategy_atr_period_d1 | 20 | 2+ | D1 ATR period for per-leg hard stop distance |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for each leg's hard stop |
| strategy_deviation_points | 20 | 0+ | Broker deviation points for market leg entries |

---

## 3. Symbol Universe

**Designed for:**
- USDJPY.DWX - leg 1 of the fixed USDJPY/AUDJPY spread and the spread numerator.
- AUDJPY.DWX - leg 2 of the fixed USDJPY/AUDJPY spread and the beta-weighted spread denominator.

**Explicitly not for:**
- Other `.DWX` symbols. This card is a fixed two-leg FX-cross basket, not a portable multi-pair strategy.

The basket runs under JPY-denominated tester accounting. Both legs are
JPY-quoted, so the test does not rely on a separate bare-symbol conversion
history path.

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
| USDJPY~AUDJPY | 0.3587 | -0.3548 | -3.8397% | 15 | 0.763733 | 139.63d |

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | JPY 150,000 per basket trade, roughly USD 1,000 equivalent |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

Q02 tester note: the manifest pins `tester_currency=JPY` and
`tester_deposit=15000000`. The logical basket backtest setfile uses
`RISK_FIXED=150000`, with `RISK_PERCENT=0`, to preserve roughly the canonical
USD 1,000 fixed-risk budget without forcing MT5 to fetch bare `USDJPY`
conversion history.

Q02 was auto-enqueued by `farmctl record-build` after strict compile and
build-check passed. No manual MT5 run was launched from this build session; Q02
is delegated to paced farm workers through the logical basket setfile.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-29 | Initial rank-26 next-unbuilt FX cointegration basket build | Built from the 12764 two-leg JPY-cross basket pattern |
| v2 | 2026-06-29 | Q02 handoff | Build task c5c43c78-2d18-465d-9a9a-c0cc078bbd05 recorded; Q02 work item 080ebc00-3644-4719-b6e6-6f855604f6b6 active on T2 |
| v3 | 2026-07-01 | JPY tester-account repair | Q07 seed failures traced to bare USDJPY conversion-history timeouts; manifest and setfiles switched to JPY accounting; Q02 task ccd2d5bd-1d18-4c42-a888-63dadfe9b6a3 / work item 54c04ac1-e5f7-4060-ae60-6814cb930fd5 pending |

