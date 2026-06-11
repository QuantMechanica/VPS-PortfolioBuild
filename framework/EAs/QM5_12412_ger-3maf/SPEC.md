# QM5_12412_ger-3maf - Strategy Spec

**EA ID:** QM5_12412
**Slug:** ger-3maf
**Source:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades completed M15-bar pullbacks inside a three-EMA trend stack. A long setup requires EMA(60) above EMA(350) above EMA(600), the prior bar low between EMA(600) and EMA(60), and a lower Williams Fractal at shift 2. A short setup mirrors that logic with EMA(600) above EMA(350) above EMA(60), the prior bar high between EMA(60) and EMA(600), and an upper Williams Fractal at shift 2. Entries are market orders with a moving-average-derived stop and a fixed 1.5R take-profit; the source grid overlay is disabled.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ma1_len | 60 | 40-80 | Fast EMA length from the card. |
| strategy_ma2_len | 350 | 250-450 | Middle EMA length used for trend stack and preferred stop. |
| strategy_ma3_len | 600 | 450-750 | Slow EMA length used for trend stack and fallback MA stop. |
| strategy_tp_coef | 1.5 | 1.0-2.0 | Take-profit multiple of entry-to-stop risk. |
| strategy_min_sl_points | 100 | fixed from source | Minimum stop distance in broker points. |
| strategy_cat_atr_period | 14 | fixed V5 fallback | ATR period for catastrophic fallback stop when the MA stop is invalid or too close. |
| strategy_cat_atr_mult | 1.5 | V5 default | ATR multiplier for the catastrophic fallback stop. |

---

## 3. Symbol Universe

**Designed for:**
- USDCAD.DWX - Primary source-market forex CFD named in the approved card.
- EURUSD.DWX - Liquid DWX forex CFD in the card's portable basket.
- GBPUSD.DWX - Liquid DWX forex CFD in the card's portable basket.
- AUDUSD.DWX - Liquid DWX forex CFD in the card's portable basket.

**Explicitly NOT for:**
- Non-DWX symbols - Build, research, and backtest artifacts must retain the `.DWX` suffix.
- Index or commodity CFDs - The approved card's R3 basket is forex-only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Not specified in card; exits are SL/TP or framework Friday close. |
| Expected drawdown profile | Trend-pullback forex sleeve with fixed-risk sizing. |
| Regime preference | Moving-average trend with fractal pullback entries. |
| Win rate target (qualitative) | Not specified in card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Source type:** code
**Pointer:** Geraked / Rabist, 3MAF.mq5, geraked/metatrader5 GitHub repository
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12412_ger-3maf.md`

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
| v1 | 2026-06-11 | Initial build from card | 40cd43bc-3b3b-4bc1-ab59-777ac29a07eb |
