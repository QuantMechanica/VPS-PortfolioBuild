# QM5_12778_edgelab-audusd-eurjpy-cointegration - Strategy Spec

**EA ID:** QM5_12778
**Slug:** edgelab-audusd-eurjpy-cointegration
**Source:** claude_cross_asset_discovery_2026-06-09 plus Chan cointegration pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA trades the AUDUSD.DWX and EURJPY.DWX D1 cointegration spread. It
computes `S = ln(AUDUSD) - beta * ln(EURJPY)` with beta defaulting to
0.279193, then calculates a 60-bar rolling z-score of that spread.

It opens a short-spread package when z is above +2.0 and a long-spread package
when z is below -2.0. It closes both legs when the cached spread z-score has
reverted inside +/-0.5. Each leg also carries a 2.0 * ATR(20, D1) protective
stop.

This is an exploratory next-best basket, not a hard-bar scan survivor. The
published 66-pair scan only certified QM5_12533 and QM5_12532. A rerun of the
same script ranked AUDUSD/EURJPY as the next unbuilt rank-25 tail candidate
after the existing
12532/12533/12624/12712/12723/12728/12731/12732/12735/12739/12747/12749/12751/12756/12758/12760/12762/12764/12765/12766/12768/12770/12772/12776
baskets, with DEV Sharpe 0.3598, OOS net Sharpe -0.2240, OOS return -2.6162%,
17 OOS state changes, beta 0.279193, and 110.79-day half-life.

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
| strategy_beta | 0.279193 | >0 | Hedge coefficient in `ln(AUDUSD) - beta * ln(EURJPY)` |
| strategy_entry_z | 2.0 | >0 | Absolute z-score threshold for opening a spread package |
| strategy_exit_z | 0.5 | >=0 | Absolute z-score threshold for closing the open package |
| strategy_atr_period_d1 | 20 | 2+ | D1 ATR period for per-leg hard stop distance |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for each leg's hard stop |
| strategy_deviation_points | 20 | 0+ | Broker deviation points for market leg entries |

---

## 3. Symbol Universe

**Designed for:**
- AUDUSD.DWX - leg 1 of the fixed AUDUSD/EURJPY spread and the spread numerator.
- EURJPY.DWX - leg 2 of the fixed AUDUSD/EURJPY spread and the beta-weighted spread denominator.
- EURUSD.DWX - custom-symbol conversion history only, preloaded for
  AUDUSD accounting in the EUR-denominated tester.

**Explicitly not for:**
- Other `.DWX` symbols. This card is a fixed two-leg FX-cross basket, not a portable multi-pair strategy.

EURUSD.DWX is selected as conversion history for EUR-denominated tester
accounting of the AUDUSD leg. It is not a traded leg.

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
| Expected drawdown profile | very high; Q02/Q04/Q05 must judge whether this weak residual is tradable after cost |
| Regime preference | low-conviction AUD/USD risk expression versus euro-yen carry/risk expression |
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
| AUDUSD~EURJPY | 0.3598 | -0.2240 | -2.6162% | 17 | 0.279193 | 110.79d |

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | EUR 1,000 per basket trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

Q02 tester note: the manifest pins `tester_currency=EUR` and
`tester_deposit=100000`. The logical basket backtest setfile uses the canonical
`RISK_FIXED=1000`, with `RISK_PERCENT=0`.

No manual tester run is launched from this build session; Q02 is delegated to
the paced farm workers through the logical basket setfile.

Q02 handoff: build task `e6ac4aae-f214-40f0-b037-1a9eeea4e2f8` was recorded
on 2026-06-29 and auto-enqueued one logical basket work item,
`8f0e511f-0f93-42eb-b2c5-b07e1f7a6f1e`, for
`QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`. The Q02 payload includes the
basket manifest, AUDUSD/EURJPY basket legs, EURUSD conversion history,
`tester_currency=EUR`, `tester_deposit=100000`, `RISK_FIXED=1000`, and a
120-minute paced-fleet timeout. The first Q02 attempt failed with
`NO_HISTORY`/`INCOMPLETE_RUNS` after the tester synchronized `EURUSD.DWX` but
then fell through to bare `USDJPY`; v1-q02-conversion preloads both conversion
legs as `.DWX` symbols before framework initialization.

Repair handoff: the repaired build was strict-compiled on 2026-06-29 with 0
errors and 0 warnings, build-check PASS, and the existing build task was
re-recorded with refreshed hashes. `record-build` auto-enqueued replacement Q02
work item `7f04ff6a-35ca-45bd-a702-afc37b310f97` for the same logical basket
symbol. The prior `8f0e511f-0f93-42eb-b2c5-b07e1f7a6f1e` row remains terminal
as the original infra-fail evidence.

Second repair handoff: replacement Q02 work item
`7f04ff6a-35ca-45bd-a702-afc37b310f97` reproduced the same
`NO_HISTORY`/`INCOMPLETE_RUNS` failure on 2026-06-30. T4 tester logs showed the
EA opened both `.DWX` legs, then USD-denominated EURJPY accounting requested
bare `USDJPY` and timed out. The basket manifest now uses an EUR tester account
and declares only `AUDUSD.DWX`, `EURJPY.DWX`, and `EURUSD.DWX`, so the next Q02
requeue avoids that bare-symbol conversion branch.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-29 | Initial rank-25 next-unbuilt FX cointegration basket build | Built from the 12772 two-leg basket pattern |
| v1-q02 | 2026-06-29 | Build recorded and logical basket Q02 enqueued | build task `e6ac4aae-f214-40f0-b037-1a9eeea4e2f8`; work item `8f0e511f-0f93-42eb-b2c5-b07e1f7a6f1e` enqueued |
| v1-q02-conversion | 2026-06-29 | Q02 conversion-history repair | Preloaded `EURUSD.DWX` and `USDJPY.DWX`; replacement Q02 work item `7f04ff6a-35ca-45bd-a702-afc37b310f97` enqueued |
| v1-q02-eur-accounting | 2026-06-30 | Q02 conversion-accounting repair | Switched basket manifest to `tester_currency=EUR` and removed `USDJPY.DWX` from declared conversion scope before requeueing Q02 |
