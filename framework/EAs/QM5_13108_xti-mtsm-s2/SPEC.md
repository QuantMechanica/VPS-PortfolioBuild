# QM5_13108_xti-mtsm-s2 - Strategy Spec

**EA ID:** QM5_13108  
**Slug:** `xti-mtsm-s2`  
**Source:** `LIU-MTSM-2021_XTI_S01`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA implements the MTSM-S2 managed time-series-momentum state machine on
`XTIUSD.DWX`. On each new D1 bar it sums the latest 30 completed daily returns,
calculates five-day upper and lower partial moments, and compares those moments
with separate no-lookahead 80th-percentile references from 252 older
observations.

- Both moments in their tails: flat.
- Lower partial moment alone in its tail: long.
- Upper partial moment alone in its tail: short.
- Neither in its tail: follow the sign of the 30-day cumulative return.

The EA closes flat/opposed/unknown states, permits same-bar state reversal after
the prior position is closed, uses a frozen ATR hard stop, and retains framework
Friday close. This is not a WTI return-sign horizon variant: the source-defined
joint partial-moment region map can override or neutralize base momentum.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_momentum_days` | 30 | 20, 30, 40 | Base cumulative-return state |
| `strategy_partial_moment_days` | 5 | 5 | UPM/LPM window |
| `strategy_percentile_history` | 252 | 126, 252, 504 | Older tail-reference observations |
| `strategy_tail_percentile` | 80.0 | 80.0 | Separate UPM/LPM nearest-rank threshold |
| `strategy_atr_period` | 20 | 14, 20, 30 | D1 ATR for hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5, 3.0, 4.0 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 8 | 7, 8 | Stale-position safeguard |
| `strategy_max_spread_points` | 1500 | 1000, 1500, 2000 | Entry spread cap |

The five-day partial-moment window, 80th percentile, S2 map, and symmetric
long/short direction are locked.

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.
- The source studied a diversified Chinese commodity-futures universe rather
  than WTI. This single-symbol carrier is a falsifiable port, not a replication
  claim.

## 4. Timeframe

- Host and signal timeframe: D1.
- All state inputs are completed D1 closes.
- `CopyClose` history work is gated by `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected completed packages: 20-52/year before Q02 validation.
- Typical hold: one to five D1 bars, with framework Friday flatten and an
  eight-day stale guard.
- Regime preference: persistent WTI moves except when recent one-sided squared
  returns put the S2 map into a reversal/flat state.
- Q02 backtest mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## 6. Source Citation

Liu, Z., Lu, S., and Wang, S. (2021), "Asymmetry, tail risk and time series
momentum," *International Review of Financial Analysis* 78, 101938,
https://doi.org/10.1016/j.irfa.2021.101938. Accepted manuscript:
https://centaur.reading.ac.uk/100824/1/FINANA-D-21-00329-R1.pdf.

The source uses 30-day momentum, five-day partial moments, recursive 80th
percentiles, and the four-region MTSM-S2 action map. It does not establish a
WTI-specific result and omits transaction costs.

## 7. Risk Model

| Environment | Mode | Value |
|---|---|---:|
| Q02+ backtest | `RISK_FIXED` | 1000 |
| Live, if separately approved | `RISK_PERCENT` | allocated by portfolio process |

The paper's daily volatility targeting is intentionally not implemented because
V5 requires fixed-dollar backtest risk. Each entry has a 3 ATR broker stop.
No live setfile, `T_Live` file, AutoTrading state, deploy manifest, portfolio
gate, admission rule, or portfolio KPI code is touched.

## 8. Framework Alignment

- No-Trade: exact symbol/timeframe/slot and parameter guards.
- Entry: calculate the S2 state once per D1 bar; open the target side with ATR
  hard stop after history, arithmetic, percentile, and spread checks pass.
- Management: close unknown, flat, opposed, or stale exposure on a new D1 bar.
- Close: target-state change, stale guard, broker ATR stop, or framework Friday
  flatten.

## 9. Pipeline History

| version | date | reason | next phase |
|---|---|---|---|
| v1 | 2026-07-10 | initial source-backed WTI MTSM-S2 build | Q02 |

