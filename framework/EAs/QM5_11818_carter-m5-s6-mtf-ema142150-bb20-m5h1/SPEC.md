# QM5_11818_carter-m5-s6-mtf-ema142150-bb20-m5h1 - Strategy Spec

**EA ID:** QM5_11818
**Slug:** carter-m5-s6-mtf-ema142150-bb20-m5h1
**Source:** f4430cee-7efb-592e-bf0f-e469ef156b2d
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA trades Thomas Carter Strategy 6 as a multi-timeframe EMA pullback on EURUSD.DWX. A long entry requires EMA(14) > EMA(21) > EMA(50) on H1 and M5, then the last closed M5 bar must pull back to or below EMA(21) while its close remains inside the BB(20,20) envelope. A short entry requires EMA(14) < EMA(21) < EMA(50) on H1 and M5, then the last closed M5 bar must pull back to or above EMA(21) while its close remains inside the BB(20,20) envelope. Exits are only the initial 2 x ATR(14) stop loss and 4 x ATR(14) take profit, plus framework exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_fast_period | 14 | integer > 0 | Fast EMA period used in the H1 and M5 stack. |
| strategy_ema_mid_period | 21 | integer > 0 | Mid EMA period used for stack order and the M5 pullback touch. |
| strategy_ema_slow_period | 50 | integer > 0 | Slow EMA period used in the H1 and M5 stack. |
| strategy_bb_period | 20 | integer > 0 | Bollinger Band period on M5. |
| strategy_bb_deviation | 20.0 | decimal > 0 | Bollinger Band standard-deviation setting from the card's BB(20,20). |
| strategy_atr_period | 14 | integer > 0 | ATR period on M5 for initial stop and take-profit distance. |
| strategy_sl_atr_mult | 2.0 | decimal > 0 | Stop-loss distance in ATR multiples. |
| strategy_tp_atr_mult | 4.0 | decimal > 0 | Take-profit distance in ATR multiples. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - The card's stated target symbol and R3-approved DWX market.

**Explicitly NOT for:**
- Other `.DWX` symbols - The card does not define a portable basket beyond EURUSD.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | H1 EMA(14/21/50) trend stack confirmation |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Expected trade frequency | Not specified as a separate frontmatter field; implied by 80 trades/year/symbol. |
| Typical hold time | Not specified in the card. |
| Expected drawdown profile | Not specified in the card. |
| Regime preference | Trend-following pullback regime. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** f4430cee-7efb-592e-bf0f-e469ef156b2d
**Source type:** PDF/book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 2014, Strategy 6; local PDF `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`
**R1-R4 verdict (Q00):** all PASS per frontmatter and G0 approval in `artifacts/cards_approved/QM5_11818_carter-m5-s6-mtf-ema142150-bb20-m5h1.md`

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
| v1 | 2026-06-30 | Initial build from card | 9c93307f-afa1-4400-b3b5-dce0272bc109 |
