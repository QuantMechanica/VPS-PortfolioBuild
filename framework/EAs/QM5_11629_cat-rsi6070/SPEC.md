# QM5_11629_cat-rsi6070 - Strategy Spec

**EA ID:** QM5_11629
**Slug:** cat-rsi6070
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see `scrtlabs/catalyst`, `catalyst/examples/mean_reversion_simple.py`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA is a long-only M15 RSI mean-reversion strategy. It enters when the last completed M15 candle has RSI(14) at or below 60, provided no position or pending order exists for this magic number and no trade action has already been taken on the current broker calendar day. It exits an open long when the last completed M15 candle has RSI(14) at or above 70. The source has no protective stop, so the V5 implementation adds a catastrophic ATR stop at 2.0 times ATR(14) and uses no fixed take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | integer > 0 | RSI lookback period on completed M15 candles. |
| `strategy_rsi_entry_level` | 60.0 | 0 < value < exit level | Long entry threshold; enter when RSI is at or below this level. |
| `strategy_rsi_exit_level` | 70.0 | value > entry level | Strategy exit threshold; close long when RSI is at or above this level. |
| `strategy_atr_period` | 14 | integer > 0 | ATR lookback period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.0 | value > 0 | ATR multiplier used to place the protective stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major listed by the card and available in the DWX matrix.
- `GBPUSD.DWX` - FX major listed by the card and available in the DWX matrix.
- `USDJPY.DWX` - FX major listed by the card and available in the DWX matrix.
- `XAUUSD.DWX` - gold symbol listed by the card and available in the DWX matrix.
- `NDX.DWX` - Nasdaq index CFD listed by the card and available in the DWX matrix.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX test data is available.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Expected trade frequency | not specified in card |
| Typical hold time | not specified in card |
| Expected drawdown profile | bounded by V5 fixed risk and ATR catastrophic stop |
| Regime preference | mean-reversion |
| Win rate target (qualitative) | not specified in card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository source file
**Pointer:** https://github.com/scrtlabs/catalyst/blob/master/catalyst/examples/mean_reversion_simple.py
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11629_cat-rsi6070.md`

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
| v1 | 2026-06-25 | Initial build from card | 2454f927-ff19-4de1-b499-032887b2136a |
