# QM5_11526_ciurea-rsi10-50-d1 - Strategy Spec

**EA ID:** QM5_11526
**Slug:** ciurea-rsi10-50-d1
**Source:** 0192e348-5570-531c-9110-7954a36caca2
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades GBPUSD.DWX on D1 when RSI(10) crosses the 50 midline on the last closed bar. A cross from at or below 50 to above 50 opens a long at the next D1 bar; a cross from at or above 50 to below 50 opens a short. The stop is placed three pips beyond the most adverse extreme of the last three closed D1 bars, capped at 150 pips, and the take profit is set at 2R. Fresh Friday entries are skipped.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_rsi_period | 10 | 2-100 | RSI lookback used for the midline cross signal. |
| strategy_rsi_cross_level | 50.0 | 1.0-99.0 | RSI level used as the directional momentum threshold. |
| strategy_struct_lookback | 3 | 1-20 | Closed D1 bars used for the stop extreme. |
| strategy_sl_buffer_pips | 3 | 1-50 | Extra stop distance beyond the three-bar extreme. |
| strategy_tp_rr | 2.0 | 0.5-10.0 | Reward/risk multiple for take profit. |
| strategy_sl_cap_pips | 150 | 10-500 | Maximum stop distance allowed for D1 three-bar extremes. |
| strategy_spread_cap_pips | 30 | 1-100 | Maximum genuinely positive spread allowed before blocking entries. |
| strategy_no_friday_entry | true | true/false | When true, the EA does not open fresh Friday trades. |

---

## 3. Symbol Universe

**Designed for:**
- GBPUSD.DWX - source-specified pair with positive Ciurea RSI(10,50) D1 result and available DWX factory data.

**Explicitly NOT for:**
- EURUSD.DWX - source comparison was negative for EUR/USD RSI settings, so it is not registered for P2 baseline.
- Index and commodity DWX symbols - the approved card is a single-pair GBP/USD forex signal, not a portable multi-asset basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 22 |
| Typical hold time | days, until 2R take profit, structure stop, or framework Friday close |
| Expected drawdown profile | low win-rate momentum profile; losses are capped by the three-bar structure stop |
| Regime preference | D1 directional momentum |
| Win rate target (qualitative) | low; source reports 30.72% for GBP/USD RSI(10,50) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0192e348-5570-531c-9110-7954a36caca2
**Source type:** self-published trading article/PDF
**Pointer:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_11526_ciurea-rsi10-50-d1.md
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11526_ciurea-rsi10-50-d1.md`

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
| v1 | 2026-06-25 | Initial build from card | bdb24bfc-ce1b-4688-833a-f84e8640cfd5 |
