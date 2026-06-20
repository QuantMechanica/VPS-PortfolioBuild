# QM5_11736_rfs-cutting-points-bb-rsi-adx-m5 - Strategy Spec

**EA ID:** QM5_11736
**Slug:** rfs-cutting-points-bb-rsi-adx-m5
**Source:** b5a932a2-40b6-5628-840b-d5069ac35c4a (see approved card and source PDF reference)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a Bollinger Band mean-reversion scalp on M5. A long setup requires the previous closed bar to have closed at or below the lower BB(20,2), RSI(7) on that over-extension bar below 30, ADX(14) below 30, and the next closed bar back above the lower band. A short setup mirrors the rule at the upper band with RSI above 70 and a close back below the upper band. Entries are market orders on the next bar, with the stop placed 3 pips beyond the relevant Bollinger outer band and the take-profit at the Bollinger middle line.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_bb_period | 20 | 2-200 | Bollinger Band period using the close price. |
| strategy_bb_deviation | 2.0 | 0.1-5.0 | Standard-deviation multiplier for the Bollinger Bands. |
| strategy_rsi_period | 7 | 2-100 | RSI lookback period used to confirm the band over-extension. |
| strategy_rsi_oversold | 30.0 | 1.0-50.0 | Maximum RSI value for long setups. |
| strategy_rsi_overbought | 70.0 | 50.0-99.0 | Minimum RSI value for short setups. |
| strategy_adx_period | 14 | 2-100 | ADX lookback period for the flat-market filter. |
| strategy_adx_cap | 30.0 | 1.0-60.0 | Maximum ADX value allowed for entry. |
| strategy_sl_buffer_pips | 3 | 1-50 | Stop buffer beyond the Bollinger outer band in pips. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX pair available in the DWX matrix.
- GBPUSD.DWX - card-listed liquid FX pair available in the DWX matrix.
- AUDUSD.DWX - card-listed liquid FX pair available in the DWX matrix.
- USDCAD.DWX - card-listed liquid FX pair available in the DWX matrix.

**Explicitly NOT for:**
- Indices, metals, energy, and non-card FX crosses - the approved card targets only the four listed FX pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Expected trade frequency | Card frontmatter omits this field; M5 scalp cadence inferred from the card body. |
| Typical hold time | Intraday, usually minutes to a few M5 bars until BB middle line or SL. |
| Expected drawdown profile | Mean-reversion scalp losses cluster when ranging filter fails during trend transitions. |
| Regime preference | Ranging / calm mean-reversion markets with ADX(14) below 30. |
| Win rate target (qualitative) | medium-high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b5a932a2-40b6-5628-840b-d5069ac35c4a
**Source type:** anonymous strategy compilation PDF
**Pointer:** Anonymous, "Cutting Points", Robo-forex Strategy Compilation, robofx.com, about 2015; PDF `362359657-Robo-forex-strategy.pdf`, pages 17-18.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11736_rfs-cutting-points-bb-rsi-adx-m5.md`.

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
| v1 | 2026-06-20 | Initial build from card | 5588e487-9a3e-4a4c-93f6-faa35fd5dc16 |
