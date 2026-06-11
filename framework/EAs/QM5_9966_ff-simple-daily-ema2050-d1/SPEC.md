# QM5_9966_ff-simple-daily-ema2050-d1 — Strategy Spec

**EA ID:** QM5_9966
**Slug:** `ff-simple-daily-ema2050-d1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On a new D1 bar, the EA checks whether the previous three closed daily candles are all bullish (close > open) and whether EMA(20) is above EMA(50) with both EMAs sloping upward. When all conditions are met, it enters long at the market open of the current bar. The short mirror applies when the last three candles are all bearish and both EMAs slope downward below each other. The stop loss is placed at the wider of: two pips below (or above) the previous candle's low/high, or 90 pips from entry, subject to a minimum floor of 0.5×ATR(14,D1). Take-profit is fixed at 100 pips; the stop is moved to breakeven after +30 pips. The position is closed early if an opposite three-candle + EMA signal forms before TP/SL is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 20 | 5–50 | Period of the fast EMA trend filter |
| `strategy_ema_slow` | 50 | 20–200 | Period of the slow EMA trend filter |
| `strategy_candle_lookback` | 3 | 2–5 | Consecutive same-color candles required for signal |
| `strategy_stop_max_pips` | 90 | 30–200 | Hard cap on stop distance in pips |
| `strategy_tp_pips` | 100 | 50–500 | Take-profit distance in pips from entry |
| `strategy_be_trigger_pips` | 30 | 10–100 | Move stop to breakeven after this many pips of profit |
| `strategy_atr_period` | 14 | 5–50 | ATR period for minimum-stop floor |
| `strategy_atr_min_sl_mult` | 0.5 | 0.1–2.0 | Minimum stop = this multiplier × ATR(14,D1) |
| `strategy_spread_pct_limit` | 8 | 1–20 | Maximum spread as % of stop distance; entry blocked if wider |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair with strong D1 trend tendencies; original source tested on EUR/USD
- `GBPUSD.DWX` — major FX pair with clear daily momentum regimes; EMA filter suitable
- `USDJPY.DWX` — major FX pair; risk-on/off D1 trend cycles align with EMA-slope filter
- `AUDUSD.DWX` — commodity-linked major; D1 continuation patterns observed; within R3 basket

**Explicitly NOT for:**
- Indices (NDX, WS30, SP500) — different pip structure and volatility regime; card specifies FX majors only
- Cross pairs — not in the card's primary P2 basket; tested on USD majors

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~25 (card estimate: 18–35) |
| Typical hold time | 1–5 days |
| Expected drawdown profile | Moderate; hard 90-pip cap + ATR floor prevent micro/macro stop extremes |
| Regime preference | trend-continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** TheThing, "Simple Daily System", ForexFactory, 2007 — https://www.forexfactory.com/thread/38981-simple-daily-system
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9966_ff-simple-daily-ema2050-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 78c4b463-25c3-4303-a0a6-60a487728aed |
