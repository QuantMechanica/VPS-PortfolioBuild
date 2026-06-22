# QM5_11831_scalp-macd1269-stoch833-m5 - Strategy Spec

**EA ID:** QM5_11831
**Slug:** `scalp-macd1269-stoch833-m5`
**Source:** `cea07ead-613e-5767-89b6-9b9ec98b84ee`
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades an M5 MACD and Stochastic scalping rule. Long entries require the MACD(12,26,9) main line to be above its signal line on the last closed bar, plus Stochastic(8,3,3) %K crossing above %D from below the 20 oversold threshold. Short entries require MACD main below signal, plus %K crossing below %D from above the 80 overbought threshold. Exits are handled by the initial 2x ATR(14) stop loss, fixed 25-pip take profit, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_macd_fast` | 12 | `> 0` and `< strategy_macd_slow` | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | `> strategy_macd_fast` | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | `> 0` | MACD signal period. |
| `strategy_stoch_k` | 8 | `> 0` | Stochastic %K period. |
| `strategy_stoch_d` | 3 | `> 0` | Stochastic %D period. |
| `strategy_stoch_slow` | 3 | `> 0` | Stochastic slowing period. |
| `strategy_stoch_os` | 20.0 | `0.0-50.0` | Oversold threshold for long triggers. |
| `strategy_stoch_ob` | 80.0 | `50.0-100.0` | Overbought threshold for short triggers. |
| `strategy_atr_period` | 14 | `> 0` | ATR period for the factory stop loss. |
| `strategy_sl_atr_mult` | 2.0 | `> 0.0` | Stop distance multiplier applied to ATR(14). |
| `strategy_take_profit_pips` | 25 | `> 0` | Fixed take-profit distance in pips. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card target and DWX M5 forex symbol.
- `GBPUSD.DWX` - Card target and DWX M5 forex symbol.
- `USDJPY.DWX` - Card target and DWX M5 forex symbol.
- `USDCHF.DWX` - Card target and DWX M5 forex symbol.
- `AUDUSD.DWX` - Card target and DWX M5 forex symbol.

**Explicitly NOT for:**
- Non-FX index and commodity `.DWX` symbols - The approved card targets the five listed forex pairs only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `200` |
| Expected trade frequency | Not specified in card frontmatter. |
| Typical hold time | Not specified in card frontmatter. |
| Regime preference | Momentum scalp; exact regime not specified in card frontmatter. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `cea07ead-613e-5767-89b6-9b9ec98b84ee`
**Source type:** `local PDF`
**Pointer:** `412362945-M1-M5-Forex-Scalping-Trading-Strategy-pdf.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11831_scalp-macd1269-stoch833-m5.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-23 | Initial build from card | f74f88c5-c099-4cd5-8ac3-fc6f9d4d3bb0 |
