# QM5_11114_bb-alert-break - Strategy Spec

**EA ID:** QM5_11114
**Slug:** bb-alert-break
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H1 bars with Bollinger Bands period 20 and deviation 2. A long entry fires when the previous completed close was below the upper band and the latest completed close breaks above the upper band. A short entry fires when the previous completed close was above the lower band and the latest completed close breaks below the lower band. Long positions exit on an opposite lower-band breakout, a close back below the middle band, or after 24 H1 bars; short positions use the inverse exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | >= 2 | Bollinger Band period on H1 completed bars. |
| strategy_bb_deviation | 2.0 | > 0 | Bollinger Band standard-deviation multiplier. |
| strategy_atr_period | 14 | >= 1 | ATR period used for the hard stop. |
| strategy_atr_sl_mult | 2.0 | > 0 | ATR multiplier for the hard stop from entry. |
| strategy_max_hold_h1_bars | 24 | >= 1 | Safety time stop measured in H1 bars. |

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
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework OnTick gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Up to 24 H1 bars by safety time stop |
| Expected drawdown profile | Breakout losses can cluster when band breaks fail and price reverts through the middle band. |
| Regime preference | Completed-bar Bollinger breakout / volatility expansion |
| Win rate target (qualitative) | medium |

Expected frequency from card frontmatter: "Completed-bar Bollinger band breakouts on H1 should occur multiple times per month per liquid symbol; conservative estimate 80 trades/year/symbol."

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub repository and MQL5 indicator source
**Pointer:** EarnForex Bollinger Bands Breakout Alert, `MQL5/Indicators/MQLTA MT5 Bollinger Bands With Alert.mq5`, function `IsSignal`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11114_bb-alert-break.md`

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
| v1 | 2026-06-07 | Initial build from card | a01edd07-6470-41a7-8ac0-c714e73fdd5f |
