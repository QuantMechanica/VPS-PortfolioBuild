# QM5_11534_carter-t-h1-bb20-ema3-macd617-rsi14 - Strategy Spec

**EA ID:** QM5_11534
**Slug:** `carter-t-h1-bb20-ema3-macd617-rsi14`
**Source:** `3001a121-97a0-5db0-b6ff-69b89a0fc07d` (see approved card source record)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades H1 Bollinger/EMA/MACD/RSI confluence from Carter System #8. A long entry is allowed when EMA(3) crosses above the Bollinger middle band, MACD(6,17,1) crosses above zero, and RSI(14) crosses above 50 within the recent two closed bars, with all three still on the bullish side at entry. A short entry mirrors the rule below the Bollinger middle band, below MACD zero, and below RSI 50. The stop is the relevant opposite Bollinger band capped at 40 pips, and take profit is the closer of the opposite Bollinger band or 50 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 2-200 | Bollinger period; middle band is SMA20 by default. |
| `strategy_bb_deviation` | 3.0 | 0.5-5.0 | Bollinger deviation multiplier. |
| `strategy_ema_period` | 3 | 2-50 | Fast EMA period crossing the Bollinger middle band. |
| `strategy_macd_fast` | 6 | 2-50 | MACD fast EMA period. |
| `strategy_macd_slow` | 17 | 3-100 | MACD slow EMA period. |
| `strategy_macd_signal` | 1 | 1-50 | MACD signal period; 1 matches the card's no-smoothing note. |
| `strategy_rsi_period` | 14 | 2-100 | RSI lookback period. |
| `strategy_rsi_mid` | 50.0 | 1-99 | RSI trend threshold. |
| `strategy_recent_cross_bars` | 2 | 1-2 | Recent closed-bar window for the EMA, MACD, and RSI threshold crosses. |
| `strategy_sl_cap_pips` | 40 | 1-500 | Maximum stop distance in pips. |
| `strategy_tp_fixed_pips` | 50 | 1-500 | Fixed take-profit alternative in pips. |
| `strategy_no_friday_entry` | true | true/false | Blocks new Friday entries per card. |
| `strategy_spread_cap_pips` | 15 | 1-100 | Blocks only genuinely wide spread above this pip cap. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 explicitly names H1 EURUSD.DWX as available and portable.
- `GBPUSD.DWX` - Card R3 explicitly names H1 GBPUSD.DWX as available and portable.

**Explicitly NOT for:**
- Non-FX index or metal symbols - The source strategy and approved card are specific to H1 forex pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Intraday to multi-hour, bounded by SL/TP and Friday close |
| Expected drawdown profile | Active H1 FX strategy with fixed-risk trade sizing |
| Regime preference | Volatility-expansion and directional momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3001a121-97a0-5db0-b6ff-69b89a0fc07d`
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", self-published 2014, System #8.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11534_carter-t-h1-bb20-ema3-macd617-rsi14.md`

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
| v1 | 2026-06-20 | Initial build from card | eb92d973-2264-4521-808a-3b583545cfd6 |
