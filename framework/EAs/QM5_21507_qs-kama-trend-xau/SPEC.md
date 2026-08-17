# QM5_21507_qs-kama-trend-xau — Strategy Spec

**EA ID:** QM5_21507
**Slug:** `qs-kama-trend-xau`
**Source:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Author of this spec:** Gemini
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

This EA implements Perry Kaufman's Adaptive Moving Average (KAMA) trend strategy on gold (`XAUUSD.DWX`) on the D1 timeframe. KAMA dynamically adjusts its smoothing constant between fast (2-period) and slow (30-period) boundaries using a 10-period Efficiency Ratio (ER) that measures price directional change relative to total path volatility.

On the open of each new completed D1 bar, the strategy evaluates entry and exit signals:
- **Long Entry:** Open a long position when `Close[1] > KAMA[1]` and `KAMA[1] > KAMA[2]` (price is above KAMA and KAMA is sloping up), provided no long position is already open and spread is within limits.
- **Short Entry:** Open a short position when `Close[1] < KAMA[1]` and `KAMA[1] < KAMA[2]` (price is below KAMA and KAMA is sloping down), provided no short position is already open and spread is within limits.
- **Flat Slope Gate:** If `KAMA[1] == KAMA[2]`, new entries are blocked.
- **Trend-Failure Exit:** Close long positions if `Close[1] < KAMA[1]`; close short positions if `Close[1] > KAMA[1]`.
- **Hard Stop Loss:** Fixed hard stop placed at `strategy_atr_sl_mult` × ATR(14, D1) from entry.
- **Time Stop:** Positions are closed after `strategy_max_hold_bars` (default 60) completed D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_er_period` | 10 | 8-20 | Efficiency ratio lookback period |
| `strategy_fast_ema` | 2 | 2-4 | Fast EMA period boundary |
| `strategy_slow_ema` | 30 | 20-45 | Slow EMA period boundary |
| `strategy_warmup_buffer` | 10 | 5-20 | Warmup bar buffer for recursive KAMA initialization |
| `strategy_atr_period` | 14 | 10-20 | ATR period for stop loss calculation |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.5 | ATR multiplier for hard stop distance |
| `strategy_max_hold_bars` | 60 | 40-90 | Maximum holding period in completed D1 bars |
| `strategy_max_spread_points` | 300 | 150-500 | Maximum allowed spread in points |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — Gold trends in multi-week regimes punctuated by choppy consolidation, matching KAMA's noise filtering.

**Explicitly NOT for:**
- Non-gold symbols (single-symbol sleeve only in v1).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20-35 |
| Typical hold time | 5-30 days |
| Expected drawdown profile | <= 22% max DD in fixed risk |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Source type:** paper / web backtest
**Pointer:** QuantifiedStrategies.com, "Adaptive Moving Average Trading Strategy: Backtest." https://www.quantifiedstrategies.com/adaptive-moving-average/
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_21507_qs-kama-trend-xau.md`

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
| v1 | 2026-08-17 | Initial build from card | Task 2ca6b5b7-30fb-4eb8-a856-3c0f44a78244 |
