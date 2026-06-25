# QM5_11830_carter-m5-s20-ema3-bb20-macd-m5 - Strategy Spec

**EA ID:** QM5_11830
**Slug:** carter-m5-s20-ema3-bb20-macd-m5
**Source:** f4430cee-7efb-592e-bf0f-e469ef156b2d
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades the M5 close after EMA(3) crosses the Bollinger Bands middle line from BB(20, 3). A long entry requires the EMA to cross above the middle band, MACD(12, 26, 9) histogram to be positive, and the last closed price to be below the upper Bollinger Band. A short entry requires the inverse cross, negative MACD histogram, and the last closed price above the lower Bollinger Band. Exits are the card's fixed 12-pip stop loss and 12-pip take profit, plus framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_period | 3 | 1+ | EMA period used as the crossing leg. |
| strategy_bb_period | 20 | 1+ | Bollinger Band period. |
| strategy_bb_deviation | 3.0 | >0 | Bollinger Band standard-deviation multiplier. |
| strategy_macd_fast | 12 | 1+ | MACD fast EMA period. |
| strategy_macd_slow | 26 | > fast | MACD slow EMA period. |
| strategy_macd_signal | 9 | 1+ | MACD signal period. |
| strategy_sl_pips | 12 | 1+ | Fixed stop-loss distance in pips. |
| strategy_tp_pips | 12 | 1+ | Fixed take-profit distance in pips. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed M5 forex major available in the DWX matrix.
- GBPUSD.DWX - card-listed M5 forex major available in the DWX matrix.
- USDJPY.DWX - card-listed M5 forex major available in the DWX matrix.
- USDCHF.DWX - card-listed M5 forex major available in the DWX matrix.
- AUDUSD.DWX - card-listed M5 forex major available in the DWX matrix.

**Explicitly NOT for:**
- Non-DWX symbols - this build is registered only for the card-listed DWX forex symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Intraday; fixed 12-pip stop/take on M5. |
| Expected drawdown profile | Frequent small fixed-risk wins and losses. |
| Regime preference | Trend-following momentum continuation. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** f4430cee-7efb-592e-bf0f-e469ef156b2d
**Source type:** retail PDF
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 2014; local PDF `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`, Strategy 20.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11830_carter-m5-s20-ema3-bb20-macd-m5.md`

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
| v1 | 2026-06-25 | Initial build from card | 762446b0-9cdf-4f1c-9532-7a15a850e4a1 |
