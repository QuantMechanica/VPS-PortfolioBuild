# QM5_11776_tc-tf-s12-sma-cci5-m15 - Strategy Spec

**EA ID:** QM5_11776
**Slug:** `tc-tf-s12-sma-cci5-m15`
**Source:** `3afb28d0-5993-527a-b039-5eef9c0e62e8` (see `sources/thomas-carter-20-trend-following-systems`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades an M15 trend-following system from Thomas Carter Strategy #12. A long signal requires SMA(7) to cross above SMA(21), CCI(5) to cross above zero within one candle of that SMA cross, and the last closed price to be above SMA(84) and SMA(336). A short signal mirrors the same rules below zero and below both long-term averages. The initial stop is 2 x ATR(14); the EA closes half at 25 pips, moves the stop to breakeven, and closes the remainder when the last closed candle crosses back through SMA(7).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_fast_period` | 7 | `> 0` | Fast SMA used for entry cross and trailing exit line. |
| `strategy_sma_slow_period` | 21 | `> 0` | Slow SMA used for entry cross. |
| `strategy_sma_trend_period_1` | 84 | `> 0` | First long-term SMA trend filter. |
| `strategy_sma_trend_period_2` | 336 | `> 0` | Second long-term SMA trend filter. |
| `strategy_cci_period` | 5 | `> 0` | CCI period for the zero-cross confirmation. |
| `strategy_atr_period` | 14 | `> 0` | ATR period for the initial stop. |
| `strategy_atr_sl_mult` | 2.0 | `> 0` | ATR multiple for the initial stop. |
| `strategy_partial_pips` | 25 | `> 0` | Profit threshold for the 50 percent partial exit. |
| `strategy_partial_fraction` | 0.50 | `0.0-1.0` | Fraction of the open volume to close at the partial exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed DWX forex major pair.
- `GBPUSD.DWX` - Card-listed DWX forex major pair.
- `USDJPY.DWX` - Card-listed DWX forex major pair.
- `USDCHF.DWX` - Card-listed DWX forex major pair.
- `AUDUSD.DWX` - Card-listed DWX forex major pair.
- `USDCAD.DWX` - Card-listed DWX forex major pair.

**Explicitly NOT for:**
- Non-forex `.DWX` symbols - The approved card targets M15 forex majors only.
- Forex pairs outside the card list - Not part of the approved target universe for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `150` |
| Typical hold time | Not specified in card frontmatter; expected intraday to multi-session trend hold from M15 trailing logic. |
| Expected drawdown profile | Not specified in card frontmatter; bounded by 2 x ATR(14) initial stop and partial exit to breakeven. |
| Regime preference | Trend-following. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3afb28d0-5993-527a-b039-5eef9c0e62e8`
**Source type:** book/PDF
**Pointer:** `514732392-Forex-Trend-Following-Strategy.pdf`, pages 30-32
**R1-R4 verdict (Q00):** top-level card frontmatter reports all R1-R4 PASS per `artifacts/cards_approved/QM5_11776_tc-tf-s12-sma-cci5-m15.md`

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
| v1 | 2026-06-25 | Initial build from card | b9cb4aab-e784-48b9-9066-8d27e5c4e650 |
