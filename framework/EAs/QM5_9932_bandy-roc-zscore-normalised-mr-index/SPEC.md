# QM5_9932_bandy-roc-zscore-normalised-mr-index — Strategy Spec

**EA ID:** QM5_9932
**Slug:** `bandy-roc-zscore-normalised-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Author of this spec:** Gemini Orchestration
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

Mechanical long-only mean reversion index strategy based on Howard Bandy's *Quantitative Technical Analysis* (2015).
On each completed D1 bar close:
1. Calculates the 10-day Rate of Change (ROC): `roc10 = 100 * (close[0] - close[10]) / close[10]`.
2. Computes the rolling z-score of ROC over a 60-day window: `z = (roc10[0] - mean(roc10, 60)) / stdev(roc10, 60)` using population standard deviation.
3. Checks a degenerate quiet-regime guard (`stdev(roc10, 60) >= 0.20`).
4. Checks a 200-period simple moving average regime filter (`close > SMA(close, 200)`).
5. Opens a long position at the next D1 bar open when `z <= -2.0`, `close > SMA(200)`, and no open position exists for this magic. Short entries are structurally excluded.
6. Attaches a catastrophic stop loss at `entry_price - 2.5 * ATR(14)` at entry (no trailing).
7. Closes the position at the next bar open when the ROC z-score recovers to neutral (`z >= 0.0`) or when held for 8 completed trading bars (time stop).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_roc_period` | 10 | 5 / 10 / 14 | Lookback period in D1 bars for Rate of Change calculation. |
| `strategy_zscore_lookback` | 60 | 40 / 60 / 90 | Rolling window length in D1 bars for mean and standard deviation of ROC. |
| `strategy_entry_z` | -2.0 | -2.5 / -2.0 / -1.5 | Entry threshold: ROC z-score at or below this value triggers long entry. |
| `strategy_exit_z` | 0.0 | -0.5 / 0.0 / 0.5 | Exit threshold: ROC z-score at or above this value closes the long position. |
| `strategy_regime_sma_period` | 200 | 100 / 200 / 300 | D1 simple moving average regime filter period. |
| `strategy_atr_period` | 14 | fixed | D1 ATR period for catastrophic stop loss. |
| `strategy_atr_stop_mult` | 2.5 | 2.0 / 2.5 / 3.0 | ATR multiplier for catastrophic stop loss distance. |
| `strategy_time_stop_bars` | 8 | 5 / 8 / 12 | Maximum holding duration in completed D1 bars. |
| `strategy_min_stdev` | 0.20 | fixed | Minimum ROC standard deviation guard to prevent division by zero. |
| `strategy_warmup_bars` | 270 | 200 .. 300 | Minimum D1 bars required before trading. |

> Framework-level inputs (`RISK_PERCENT`, `RISK_FIXED`, `PORTFOLIO_WEIGHT`, `qm_news_*`, `qm_rng_seed`, `qm_friday_close_*`) are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — canonical equity index backtest instrument.
- `NDX.DWX` — liquid index CFD.
- `WS30.DWX` — liquid index CFD.
- `GDAXI.DWX` — liquid index CFD.
- `UK100.DWX` — liquid index CFD.
- `XAUUSD.DWX` — liquid gold CFD.
- `EURUSD.DWX` — liquid FX major.
- `GBPUSD.DWX` — liquid FX major.
- `USDJPY.DWX` — liquid FX major.
- `USDCHF.DWX` — liquid FX major.
- `AUDUSD.DWX` — liquid FX major.
- `USDCAD.DWX` — liquid FX major.
- `NZDUSD.DWX` — liquid FX major.

**Explicitly NOT for:**
Any symbol not registered in `framework/registry/magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entries; `QM_IsNewCalendarPeriod(PERIOD_D1)` for restart-safe D1 exits |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 22 |
| Expected trade frequency | approximately 1–2 entries per month per symbol during pullbacks in uptrend |
| Typical hold time | 2 to 8 trading days (exits on mean-reversion recovery or 8-day time stop) |
| Expected drawdown profile | clustered drawdown during sharp market corrections penetrating the 2.5xATR stop |
| Regime preference | bull-market pullbacks (`close > SMA(200)`) |
| Win rate target (qualitative) | high win rate (>65%) typical of mean reversion systems with short holding periods |

---

## 6. Source Citation

This strategy was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** book
**Citation:** Howard B. Bandy, *Quantitative Technical Analysis: An Integrated Approach to Trading System Development and Trade Management*, Blue Owl Press, 2015, ISBN 9780979183850.
**Approved card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9932_bandy-roc-zscore-normalised-mr-index.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | `RISK_FIXED` | $1,000 per trade |
| Live burn-in (Q13) | `RISK_PERCENT` | Min-lot equivalent |
| Full live (post-Q13 PASS) | `RISK_PERCENT` | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | Initial build from card | Gemini Orchestration cycle |
