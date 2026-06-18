# QM5_11028_atc-wma-rev - Strategy Spec

**EA ID:** QM5_11028
**Slug:** atc-wma-rev
**Source:** 9441393d-5ffc-5b43-87be-bd532110f204
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades a fast/slow weighted moving average reversal trend signal on completed H1 bars. It opens long when the fast WMA crosses above the slow WMA, or when the close is above the slow WMA and the fast WMA slope is positive. It opens short on the mirrored bearish rule. Open positions are closed on an opposite signal; protective exits are an ATR stop and an optional ATR take-profit cap.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_fast_wma_period | 24 | 12-36 tested | Fast weighted moving average period. |
| strategy_slow_wma_period | 144 | 72-216 tested | Slow weighted moving average period. |
| strategy_atr_period | 14 | fixed baseline | ATR lookback for stop and target distance. |
| strategy_sl_atr_mult | 2.5 | 1.5-3.5 tested | Stop distance in ATR multiples. |
| strategy_tp_atr_mult | 5.0 | 0, 4.0, 5.0, 7.0 tested | Take-profit distance in ATR multiples; 0 disables TP. |
| strategy_max_spread_pips | 0.0 | 0+ | Maximum spread in pips; 0 disables the extra spread cap for DWX zero-spread tests. |
| strategy_use_related_confirm | false | true/false | Enables optional related-symbol WMA confirmation. |
| strategy_confirm_weight_a | 0.5 | 0.0-1.0 tested | Weight for related symbol A direction. |
| strategy_confirm_weight_b | 0.5 | 0.0-1.0 tested | Weight for related symbol B direction. |
| strategy_confirm_threshold | 0.5 | 0.0-1.0 tested | Minimum signed confirmation score for entry. |
| strategy_related_symbol_a | GBPUSD.DWX | DWX symbol | First related confirmation symbol. |
| strategy_related_symbol_b | USDJPY.DWX | DWX symbol | Second related confirmation symbol. |

---

## 3. Symbol Universe

**Designed for:**
- GBPJPY.DWX - Primary volatile JPY cross from the source/card.
- GBPUSD.DWX - GBP leg and portable FX target from R3.
- USDJPY.DWX - JPY leg and portable FX target from R3.
- EURJPY.DWX - Additional liquid JPY cross from R3.

**Explicitly NOT for:**
- Non-DWX symbols - The V5 build and tester registry require canonical `.DWX` names.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | hours to days |
| Expected drawdown profile | Vulnerable to large reversals and spread widening; bounded by ATR stop. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9441393d-5ffc-5b43-87be-bd532110f204
**Source type:** article/interview
**Pointer:** https://www.mql5.com/en/articles/624
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11028_atc-wma-rev.md`

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
| v1 | 2026-06-18 | Initial build from card | 92d8b27b-c955-49b9-be5d-37b2ae5849aa |
