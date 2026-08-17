# QM5_21513_qs-double-seven-trend-ndx — Strategy Spec

**EA ID:** QM5_21513
**Slug:** `qs-double-seven-trend-ndx`
**Source:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Author of this spec:** Gemini
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

This EA implements the Larry Connors / Cesar Alvarez "Double 7s" trend-aligned pullback strategy on the Nasdaq 100 (`NDX.DWX`) on the D1 timeframe. It trades short-term exhaustion pullbacks within the primary trend defined by a 200-day Simple Moving Average (SMA).

On the open of each new completed D1 bar:
- **Primary Trend Filter:** Evaluates `Close[1]` relative to `SMA(200, D1)[1]`. Bullish when above 200-SMA, Bearish when below 200-SMA.
- **Rolling Close Extremes:** Evaluates the rolling 7-day minimum and maximum completed close prices: `Lowest7 = Min(Close[1..7])`, `Highest7 = Max(Close[1..7])`.
- **Long Entry:** Open a long position when `Close[1] > SMA200[1]` and `Close[1] <= Lowest7` (today's close is the lowest of the last 7 days), provided no long position is already open and spread is within limits.
- **Short Entry:** Open a short position when `Close[1] < SMA200[1]` and `Close[1] >= Highest7` (today's close is the highest of the last 7 days), provided no short position is already open and spread is within limits.
- **Signal-Target Exit:** Close long positions when `Close[1] >= Highest7` (today's close is highest of last 7 days); close short positions when `Close[1] <= Lowest7` (today's close is lowest of last 7 days).
- **Hard Stop Loss:** Fixed hard stop placed at `strategy_atr_sl_mult` × ATR(14, D1) from entry.
- **Time Stop:** Positions are closed after `strategy_max_hold_bars` (default 30) completed D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_trend_sma_period` | 200 | 150-250 | Primary trend SMA period |
| `strategy_extreme_window` | 7 | 5-10 | Rolling close extreme lookback window in bars |
| `strategy_atr_period` | 14 | 10-20 | ATR period for stop loss calculation |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.5 | ATR multiplier for hard stop distance |
| `strategy_max_hold_bars` | 30 | 15-60 | Maximum holding period in completed D1 bars |
| `strategy_warmup_buffer` | 20 | 10-40 | Additional bar buffer for SMA warmup |
| `strategy_max_spread_points` | 500 | 300-800 | Maximum allowed spread in points |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — Liquid equity index CFD exhibiting strong multi-month trends punctuated by short-term pullbacks.

**Explicitly NOT for:**
- Non-index instruments.

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
| Trades / year / symbol | 15-25 |
| Typical hold time | 3-15 days |
| Expected drawdown profile | <= 17% max DD in fixed risk |
| Regime preference | trend-pullback |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Source type:** book / web summary
**Pointer:** Larry Connors & Cesar Alvarez (2008), "Short Term Trading Strategies That Work", Double 7s Setup; QuantifiedStrategies.com coverage: https://quantifiedstrategies.substack.com/p/larry-connors-double-seven-trading
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_21513_qs-double-seven-trend-ndx.md`

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
| v1 | 2026-08-17 | Initial build from card | Task 93a6aed4-8deb-429d-a01e-41c76119a2ab |
