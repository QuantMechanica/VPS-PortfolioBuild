# QM5_11361_robo-bb-macd-ma-m15 - Strategy Spec

**EA ID:** QM5_11361
**Slug:** robo-bb-macd-ma-m15
**Source:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d (see local RoboForex PDF archive)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a M15 Bollinger middle-band crossover with a fast SMA(2) signal line and a MACD sign/direction filter. It opens long when SMA(2) crosses above the BB(20,2) middle line on the last closed bar and MACD(11,27,4) main is below zero but rising versus the prior closed bar. It opens short when SMA(2) crosses below the BB(20,2) middle line and MACD main is above zero but falling versus the prior closed bar. Exits are only the fixed 12-pip take profit, fixed 13-pip stop loss, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | 5-100 | Bollinger Band period; the middle band is the SMA baseline. |
| strategy_bb_deviation | 2.0 | 0.5-4.0 | Bollinger Band standard-deviation multiplier. |
| strategy_sma_period | 2 | 2-20 | Fast SMA period crossing the Bollinger middle line. |
| strategy_macd_fast | 11 | 2-50 | MACD fast EMA period. |
| strategy_macd_slow | 27 | 3-100 | MACD slow EMA period. |
| strategy_macd_signal | 4 | 2-30 | MACD signal EMA period. |
| strategy_sl_pips | 13 | 1-100 | Fixed stop-loss distance in pips. |
| strategy_tp_pips | 12 | 1-100 | Fixed take-profit distance in pips. |
| strategy_spread_cap_pips | 5.0 | 0.0-20.0 | Blocks only genuine live/test spread wider than this cap; zero DWX spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed M15 major FX symbol with DWX data.
- GBPUSD.DWX - Card-listed M15 major FX symbol with DWX data.
- AUDUSD.DWX - Card-listed M15 major FX symbol with DWX data.
- USDCAD.DWX - Card-listed M15 major FX symbol with DWX data.
- NZDUSD.DWX - Card-listed M15 major FX symbol with DWX data.
- USDJPY.DWX - Card-listed M15 major FX symbol with DWX data.

**Explicitly NOT for:**
- Index, metal, energy, and non-card FX-cross symbols - not listed by the approved RoboForex FX card for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Intraday; fixed 12-pip TP and 13-pip SL imply minutes to hours on M15. |
| Expected drawdown profile | High-frequency small fixed-loss profile; risk is dominated by consecutive 13-pip stops. |
| Regime preference | Short-term FX reversal/recovery after SMA/BB middle crossover with MACD sign filter. |
| Win rate target (qualitative) | Medium to high due to 12-pip TP versus 13-pip SL, subject to spread and slippage. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
**Source type:** institutional PDF
**Pointer:** C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11361_robo-bb-macd-ma-m15.md`

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
| v1 | 2026-06-20 | Initial build from card | e7a4eda5-dc76-4c3c-aea8-9761263cc127 |
