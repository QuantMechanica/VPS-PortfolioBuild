# QM5_11508_carter-t-ema50-100-macd-breakout - Strategy Spec

**EA ID:** QM5_11508
**Slug:** carter-t-ema50-100-macd-breakout
**Source:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades H1 trend breakouts on EURUSD.DWX, GBPUSD.DWX, and USDJPY.DWX. A long entry is opened on the next H1 bar when the last closed bar is above EMA(50), above EMA(100), at least 10 pips above the closer EMA, and MACD(12,26,9) is positive after crossing above zero within the last five closed bars. Shorts mirror the same logic below both EMAs after a recent MACD cross below zero. The initial stop is the five-bar structure extreme capped at 40 pips, half the position is closed at 2R with the stop moved to breakeven, and the remainder exits when price crosses 10 pips beyond EMA(50) against the trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_fast_period | 50 | 1+ | Fast EMA trend layer from the card. |
| strategy_ema_slow_period | 100 | 1+ | Slow EMA trend layer from the card. |
| strategy_macd_fast | 12 | 1+ | MACD fast EMA period. |
| strategy_macd_slow | 26 | 1+ | MACD slow EMA period. |
| strategy_macd_signal | 9 | 1+ | MACD signal period. |
| strategy_macd_cross_lookback | 5 | 1+ | Bars allowed since MACD crossed zero. |
| strategy_breakout_pips | 10 | 1+ | Required close distance beyond the closer EMA and EMA50 trail offset. |
| strategy_structure_bars | 5 | 1+ | Closed bars used for the initial structure stop. |
| strategy_sl_cap_pips | 40 | 1+ | Maximum initial stop distance in pips for P2. |
| strategy_tp1_r_multiple | 2.0 | >0 | Partial-close trigger in multiples of initial risk. |
| strategy_partial_close_ratio | 0.50 | 0-1 | Fraction of open volume closed at TP1. |
| strategy_be_buffer_pips | 0 | 0+ | Breakeven stop buffer after TP1. |
| strategy_spread_cap_pips | 15 | 1+ | Maximum allowed spread for trading. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed H1 DWX FX major with native tester data.
- GBPUSD.DWX - Card-listed H1 DWX FX major with native tester data.
- USDJPY.DWX - Card-listed H1 DWX FX major with native tester data.

**Explicitly NOT for:**
- Non-FX index and metal symbols - The card specifies DWX FX instruments only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_H1) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Card frontmatter omitted this; card mechanics imply hours to several days, depending on EMA50 trail. |
| Expected drawdown profile | Card frontmatter omitted this; fixed-risk stop capped at 40 pips bounds per-trade loss. |
| Regime preference | Trend-following breakout. |
| Win rate target (qualitative) | Medium; partial exits are intended to preserve capital while trailing winners. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Source type:** book
**Pointer:** Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following Systems", System #3; local source record `sources/carter-thomas-20-forex-trend-following-systems`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11508_carter-t-ema50-100-macd-breakout.md`

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
| v1 | 2026-06-11 | Initial build from card | feb31cd0-8e42-40e8-bd30-7fdd5c5d24d4 |
