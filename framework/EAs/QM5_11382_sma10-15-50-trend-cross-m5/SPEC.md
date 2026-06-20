# QM5_11382_sma10-15-50-trend-cross-m5 - Strategy Spec

**EA ID:** QM5_11382
**Slug:** `sma10-15-50-trend-cross-m5`
**Source:** `828e3848-fdd3-5b45-a780-e746c4691997` (see `strategy-seeds/sources/828e3848-fdd3-5b45-a780-e746c4691997/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

Triple simple-moving-average trend scalper on M5. SMA(50) defines the trend state
(price above = bullish, below = bearish) and SMA(10)/SMA(15) form the trigger band.
The EA goes long when a closed M5 candle is fully above both SMA10 and SMA15
(low > max(SMA10, SMA15)), price closes above SMA50, and SMA10 plus SMA15 are both
above SMA50. Short is the mirror with the candle fully below both SMA10 and SMA15.
Stop = min(ATR(14) x 1.0, 20 pips) from entry; take-profit = ATR(14) x 1.5. A
defensive exit closes the position when a candle closes back below SMA10 or SMA15
(long) / above SMA10 or SMA15 (short). Trades only the London+NY broker-time window
13:00-22:00.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_fast_period` | 10 | 5-20 | Fast SMA of the trigger band |
| `strategy_sma_mid_period` | 15 | 8-30 | Mid SMA of the trigger band |
| `strategy_sma_trend_period` | 50 | 20-200 | Trend-filter SMA |
| `strategy_atr_period` | 14 | 7-28 | ATR period (stop / target) |
| `strategy_sl_atr_mult` | 1.0 | 0.5-2.0 | Stop distance = mult x ATR |
| `strategy_tp_atr_mult` | 1.5 | 0.8-3.0 | Target distance = mult x ATR |
| `strategy_sl_cap_pips` | 20 | 5-50 | Hard cap on stop distance (pips) |
| `strategy_spread_cap_pips` | 12 | 1-30 | Block only spread wider than this (pips) |
| `strategy_sess_start_broker` | 13 | 0-23 | London+NY window open hour (broker time) |
| `strategy_sess_end_broker` | 22 | 0-23 | Window close hour, exclusive (broker time) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - deepest, tightest-spread FX major; fits an M5 SMA scalper requiring tight spreads.
- `GBPUSD.DWX` - liquid FX major with London/NY-session movement that fits the trend-band entry.

**Explicitly NOT for:**
- Index/CFD symbols (NDX.DWX, WS30.DWX, SP500.DWX) - card targets FX majors; pip scaling and the 13:00-22:00 broker-time FX session are calibrated for forex, not cash-index hours.

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
| Trades / year / symbol | `~400` |
| Typical hold time | `minutes to a few hours (M5 intraday)` |
| Expected drawdown profile | `frequent small losses, ATR-capped; trend-aligned scalp` |
| Regime preference | `trend (intraday momentum continuation)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `828e3848-fdd3-5b45-a780-e746c4691997`
**Source type:** `book` (anonymous LQDFX broker promotional ebook, local PDF)
**Pointer:** local PDF - `440084498-5-Minute-Forex-Scalping-Strategy-pdf.pdf` (Dropbox Forex archive)
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11382_sma10-15-50-trend-cross-m5.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | aa5c2384-596a-414b-9618-ae2fd5a370f7 |
