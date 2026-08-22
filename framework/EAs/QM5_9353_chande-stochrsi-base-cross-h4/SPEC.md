# QM5_9353_chande-stochrsi-base-cross-h4 — Strategy Spec

**EA ID:** QM5_9353
**Slug:** chande-stochrsi-base-cross-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The EA implements the canonical Chande & Kroll (1994) Stochastic-RSI Base %K-%D crossover strategy on H4 closed bars.
StochRSI is computed from a 14-period RSI, normalized over a rolling 14-period window, and smoothed with a 3-period SMA for %K and a 3-period SMA for %D.
A long entry is triggered when %K crosses above %D from the oversold zone (%K < 0.20 on prior bar) while price is above the 200-period SMA.
A short entry is triggered when %K crosses below %D from the overbought zone (%K > 0.80 on prior bar) while price is below the 200-period SMA.
Positions are exited on an opposite %K-%D cross occurring from the extreme zone, on an opposite cross with at least 1.0 * ATR(14) profit, or after a 25-bar time stop.
A protective ATR stop loss at 1.8 * ATR(14) is applied at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 7-30 | Lookback period for the base RSI calculation |
| `strategy_stoch_period` | 14 | 7-30 | Lookback period for StochRSI min/max normalization window |
| `strategy_k_period` | 3 | 2-10 | SMA smoothing period for %K |
| `strategy_d_period` | 3 | 2-10 | SMA smoothing period for %D trigger line |
| `strategy_trend_sma_period` | 200 | 50-300 | Trend filter SMA period on H4 |
| `strategy_atr_period` | 14 | 7-30 | ATR period for stop loss and profit targets |
| `strategy_sl_atr_mult` | 1.8 | 1.0-4.0 | ATR multiplier for protective stop loss |
| `strategy_oversold_threshold` | 0.20 | 0.05-0.35 | Oversold threshold for long entry |
| `strategy_overbought_threshold` | 0.80 | 0.65-0.95 | Overbought threshold for short entry |
| `strategy_profit_exit_atr_mult` | 1.0 | 0.5-3.0 | Minimum ATR profit required for secondary cross exit |
| `strategy_time_stop_bars` | 25 | 10-60 | Maximum number of closed H4 bars to hold a position |
| `strategy_spread_max_atr` | 0.15 | 0.05-0.50 | Maximum allowed spread as a fraction of ATR(14) |
| `strategy_warmup_bars` | 220 | 100-300 | Minimum required closed bars before trading |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, `WS30.DWX` — Major liquid index CFDs
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX` — Forex majors basket
- `XAUUSD.DWX` — Gold commodity CFD

**Explicitly NOT for:**
- Illiquid minor pairs with wide spreads.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~40 |
| Typical hold time | 1 to 4 days (up to 25 H4 bars) |
| Expected drawdown profile | Controlled drawdown with steady multi-symbol oscillator bounce equity curve |
| Regime preference | Trending markets with short-term pullbacks and oscillating swings |
| Win rate target (qualitative) | Medium (45% - 55%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** Book / Forum / Tushar Chande & Stanley Kroll, *The New Technical Trader* (Wiley 1994)
**Pointer:** ForexFactory Trading Systems / Chande StochRSI
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9353_chande-stochrsi-base-cross-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-22 | Initial build from approved card | Task 7bc95960-7134-4d02-88c2-87ce2cb8761c |
