# QM5_11331_tc-m5-17-ema3-8-macd-stoch-psar-stddev — Strategy Spec

**EA ID:** QM5_11331
**Slug:** `tc-m5-17-ema3-8-macd-stoch-psar-stddev`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (Thomas Carter, 20 Forex Trading Strategies — 5 Min Trading System #17)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A five-condition M5 confluence. Four conditions are STATES evaluated on the last
closed bar and one is a fresh EVENT, so the EA never requires two crossovers on
the same bar (the .DWX zero-trade trap). The trigger EVENT is a Stochastic
%K/%D cross. A LONG fires when EMA(3) is above EMA(8) (trend up), the Parabolic
SAR sits below price, MACD main is above zero, Standard Deviation(20) is at or
above the per-symbol "medium" threshold (flat markets are skipped), AND %K
crosses above %D on the just-closed bar. SHORT is the exact mirror (EMA3 below
EMA8, SAR above price, MACD main below zero, StdDev medium-or-stronger, %K
crosses below %D). The stop is the recent swing low (long) / swing high (short)
over a lookback window, falling back to ATR(14)×1.5 if the structure level is on
the wrong side of entry. There is no fixed take-profit: the position is closed
when EMA(3) crosses back through EMA(8) against the trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 3 | 2-10 | Fast EMA, trend-direction state |
| `strategy_ema_slow_period` | 8 | 5-30 | Slow EMA, trend-direction state |
| `strategy_macd_fast` | 12 | 5-20 | MACD fast EMA |
| `strategy_macd_slow` | 26 | 15-40 | MACD slow EMA |
| `strategy_macd_signal` | 9 | 5-15 | MACD signal EMA |
| `strategy_stoch_k` | 10 | 5-20 | Stochastic %K period (card 10,15,15) |
| `strategy_stoch_d` | 15 | 3-20 | Stochastic %D period |
| `strategy_stoch_slow` | 15 | 3-20 | Stochastic slowing |
| `strategy_psar_step` | 0.02 | 0.01-0.05 | Parabolic SAR acceleration step |
| `strategy_psar_max` | 0.20 | 0.1-0.5 | Parabolic SAR maximum |
| `strategy_stddev_period` | 20 | 10-40 | Standard Deviation period |
| `strategy_stddev_medium_min` | 0.010 | 0.0001-1.0 | Min StdDev for "medium" regime (per-symbol; USDJPY→0.10) |
| `strategy_swing_lookback` | 10 | 5-30 | Bars for swing-low/high stop |
| `strategy_atr_period` | 14 | 7-30 | ATR period (fallback stop + spread reference) |
| `strategy_atr_sl_mult` | 1.5 | 0.5-3.0 | Fallback stop = mult × ATR |
| `strategy_spread_pct_of_stop` | 20.0 | 5-50 | Skip if spread exceeds this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary major; default StdDev threshold (0.010) calibrated here.
- `GBPUSD.DWX` — major with comparable price scale; same StdDev band as EURUSD.
- `USDJPY.DWX` — JPY pair; StdDev threshold differs (override `strategy_stddev_medium_min` to ~0.10 in the JPY setfile per the card's per-symbol table).

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the card is a forex M5 system with FX-scaled StdDev bands.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~90` |
| Typical hold time | `minutes to a few hours (M5 intraday)` |
| Expected drawdown profile | `moderate; many small trades, EMA-reverse exits cap individual losers` |
| Regime preference | `trend (confluence trend-continuation, volatility-gated)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 5 Min Trading System #17 (local PDF archive)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11331_tc-m5-17-ema3-8-macd-stoch-psar-stddev.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
