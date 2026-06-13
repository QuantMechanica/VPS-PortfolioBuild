# QM5_10607_mql5-coeffline - Strategy Spec

**EA ID:** QM5_10607
**Slug:** mql5-coeffline
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA calculates the CoeffofLine_true histogram value on each completed bar using the source default SMMA period of 5. It enters long when the completed-bar histogram crosses from below zero to above zero, and enters short when it crosses from above zero to below zero. It exits on the opposite zero cross, or after 16 completed base-timeframe bars, with a catastrophic stop at 2.5 times ATR(14) from entry and no take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_smma_period | 5 | >= 2 | CoeffofLine_true smoothing period from the source indicator. |
| strategy_atr_period | 14 | >= 1 | ATR period used for the catastrophic stop. |
| strategy_atr_sl_mult | 2.5 | > 0 | ATR multiple for the entry stop loss. |
| strategy_max_hold_bars | 16 | >= 1 | Fallback time stop measured in completed base-timeframe bars. |
| strategy_use_ema_filter | false | true/false | Optional P3 switch for the 200 EMA trend filter; disabled for baseline. |
| strategy_ema_period | 200 | >= 1 | EMA period used only when the optional trend filter is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- AUDUSD.DWX - Source test used AUDUSD H4 and the card lists AUDUSD as a target FX symbol.
- EURUSD.DWX - Card-listed DWX FX major suitable for the same histogram zero-cross logic.
- GBPUSD.DWX - Card-listed DWX FX major suitable for the same histogram zero-cross logic.
- USDJPY.DWX - Card-listed DWX FX major suitable for the same histogram zero-cross logic.

**Explicitly NOT for:**
- Non-DWX broker symbols - V5 research and backtest artifacts must use the canonical `.DWX` symbols.
- Unlisted CFDs - The approved card targets four FX symbols, not an all-CFD basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Up to 16 H4 bars by time stop; earlier on opposite cross |
| Expected drawdown profile | ATR-capped oscillator breakout with no take-profit baseline |
| Regime preference | Closed-bar histogram zero-cross / oscillator breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/1151
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10607_mql5-coeffline.md`

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
| v1 | 2026-06-13 | Initial build from card | 30315aeb-e1b7-4936-af26-99cdc39b9c07 |
