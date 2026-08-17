# QM5_33002_larry-williams-volatility-expansion-breakout — Strategy Spec

**EA ID:** QM5_33002
**Slug:** larry-williams-volatility-expansion-breakout
**Source:** larry-williams-volatility-expansion-breakout-official-source
**Author of this spec:** Gemini
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

The strategy implements Larry Williams' classic Volatility Expansion Breakout model on D1 indices and commodities (SP500.DWX, NDX.DWX, XAUUSD.DWX). The premise is that large range expansion days follow small range compression days.

When the prior day's range ($Range_{t-1} = High_{t-1} - Low_{t-1}$) is compressed below $0.80 \times SMA(Range, 10)$, breakout buy stop and sell stop orders are placed at daily open $\pm 0.60 \times Range_{t-1}$. Once one side fills, the unfilled opposite stop is canceled (OCO). Positions are protected by a $0.50 \times Range_{t-1}$ stop loss, closed on the first profitable daily open (bailout exit), or force closed after 3 completed trading days (max hold).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_lookback` | 10 | 5-20 | Lookback period for baseline range SMA compression reference |
| `strategy_compression_thresh` | 0.80 | 0.60-0.95 | Threshold multiplier of range SMA to trigger compression state |
| `strategy_breakout_fraction` | 0.60 | 0.40-0.80 | Prior range multiplier added/subtracted from daily open for breakout trigger |
| `strategy_sl_fraction` | 0.50 | 0.30-0.80 | Multiplier of prior range for initial hard stop loss distance |
| `strategy_max_hold_days` | 3 | 1-5 | Maximum holding period in trading days |
| `strategy_atr_period` | 14 | 10-20 | ATR period for spread filter evaluation |
| `strategy_spread_atr_mult` | 1.8 | 1.2-2.5 | Maximum allowable spread relative to ATR |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` (Primary, slot 0) — High liquidity US equity large-cap index CFD.
- `NDX.DWX` (slot 1) — High liquidity US tech index CFD.
- `XAUUSD.DWX` (slot 2) — Liquid commodity CFD exhibiting strong range expansion breakouts.

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
| Trades / year / symbol | 25 |
| Typical hold time | 1 to 3 days |
| Expected drawdown profile | <= 18% peak-to-trough equity drawdown |
| Regime preference | Volatility expansion / directional range breakouts following compression |
| Win rate target (qualitative) | High (60% to 75% with short holding periods) |

---

## 6. Source Citation

**Source ID:** `larry-williams-volatility-expansion-breakout-official-source`
**Source type:** Classic Quantitative Trading Book
**Pointer:** Williams, L. (1999). Long-Term Secrets to Short-Term Trading. John Wiley & Sons.
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_33002_larry-williams-volatility-expansion-breakout.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | Initial build from approved card | Router task 2d3a6323-d804-427f-8387-ca78687a78b1 |
