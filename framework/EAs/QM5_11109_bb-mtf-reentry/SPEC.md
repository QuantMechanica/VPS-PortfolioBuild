# QM5_11109_bb-mtf-reentry - Strategy Spec

**EA ID:** QM5_11109
**Slug:** bb-mtf-reentry
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H1 bars and reads Bollinger Bands with period 20 and deviation 2 on H1, H4, and D1. A long entry requires all three timeframes to show the same re-entry state: the prior completed candle closed below the lower band, the current completed candle closed back above the lower band, and the current high stayed below the middle band. A short entry is the inverse: prior close above the upper band, current close back below the upper band, and current low stayed above the middle band. Exits occur on the opposite three-timeframe state, an H1 close through the Bollinger middle band, or a 20-H1-bar safety time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | >= 2 | Bollinger Band period for H1, H4, and D1. |
| strategy_bb_deviation | 2.0 | > 0 | Bollinger Band deviation for H1, H4, and D1. |
| strategy_atr_period | 14 | >= 1 | ATR period used for the hard stop. |
| strategy_atr_sl_mult | 2.0 | > 0 | ATR multiplier for the hard stop from entry. |
| strategy_max_hold_h1_bars | 20 | >= 1 | Safety time stop measured in H1 bars. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 primary P2 basket includes this liquid major FX symbol.
- GBPUSD.DWX - Card R3 primary P2 basket includes this liquid major FX symbol.
- USDJPY.DWX - Card R3 primary P2 basket includes this liquid major FX symbol.
- XAUUSD.DWX - Card R3 primary P2 basket includes this liquid gold symbol.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX test data is registered for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | H1, H4, D1 Bollinger Band re-entry state |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework OnTick gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 36 |
| Typical hold time | Up to 20 H1 bars by safety time stop |
| Expected drawdown profile | Mean-reversion drawdowns can cluster when band re-entries fail to revert toward the middle band. |
| Regime preference | Bollinger mean-reversion / re-entry after band excursion |
| Win rate target (qualitative) | medium |

Expected frequency from card frontmatter: "Three-timeframe Bollinger re-entry alignment on H1 should occur roughly monthly to a few times per quarter per liquid symbol; conservative estimate 36 trades/year/symbol."

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub repository and MQL5 indicator source
**Pointer:** EarnForex BB-Multi-Timeframe, `MQL5/Indicators/BB Multi-Timeframe.mq5`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11109_bb-mtf-reentry.md`

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
| v1 | 2026-06-07 | Initial build from card | 8128f441-f729-4bc0-84af-ad9610006d6c |
