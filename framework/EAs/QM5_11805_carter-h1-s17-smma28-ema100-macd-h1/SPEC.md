# QM5_11805_carter-h1-s17-smma28-ema100-macd-h1 - Strategy Spec

**EA ID:** QM5_11805
**Slug:** carter-h1-s17-smma28-ema100-macd-h1
**Source:** 529382f8-fbd1-5c17-ba62-fbe56990ebcd (see `strategy-seeds/sources/529382f8-fbd1-5c17-ba62-fbe56990ebcd/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the Carter S17 H1 slow-trend system. It buys when SMMA(28) is above EMA(100) and MACD(30,60,30) crosses above zero on the latest closed H1 bar. It sells when SMMA(28) is below EMA(100) and MACD(30,60,30) crosses below zero. Exits are handled by a 2x ATR(14) stop, a 4x ATR(14) target, or by closing when the SMMA(28)/EMA(100) relationship reverses.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_timeframe | PERIOD_H1 | MT5 timeframe enum | Timeframe used for all strategy indicator reads. |
| strategy_smma_period | 28 | >= 2 | Smoothed moving average period for the medium-term trend filter. |
| strategy_ema_period | 100 | >= 2 | Exponential moving average period for the long-term trend filter. |
| strategy_macd_fast | 30 | >= 1 | MACD fast EMA period. |
| strategy_macd_slow | 60 | > strategy_macd_fast | MACD slow EMA period. |
| strategy_macd_signal | 30 | >= 1 | MACD signal period. |
| strategy_atr_period | 14 | >= 1 | ATR period for factory stop and target distance. |
| strategy_atr_sl_mult | 2.0 | > 0 | Stop loss distance as ATR multiple. |
| strategy_atr_tp_mult | 4.0 | > 0 | Take profit distance as ATR multiple. |
| strategy_allow_shorts | true | true/false | Enables the card's short-side mirror entry. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card target symbol and DWX matrix forex major.
- GBPUSD.DWX - card target symbol and DWX matrix forex major.
- AUDUSD.DWX - card target symbol and DWX matrix forex major.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must use canonical `.DWX` symbols.
- Indices, metals, and energy symbols - the approved card targets FX majors only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Not specified in frontmatter; position holds until ATR stop, ATR target, or SMMA/EMA reversal. |
| Expected drawdown profile | Trend-following FX profile with losses during choppy SMMA/EMA transitions. |
| Regime preference | Slow-trend H1 regime. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 529382f8-fbd1-5c17-ba62-fbe56990ebcd
**Source type:** book/PDF
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", Scribd circa 2014, Strategy S17; local PDF `376863900-20-Forex-Trading-Strategies-Collection.pdf`.
**R1-R4 verdict (Q00):** all PASS; see `artifacts/cards_approved/QM5_11805_carter-h1-s17-smma28-ema100-macd-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | 320ab944-616f-4dbc-8660-5c9db4a37ff5 |
