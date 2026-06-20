# QM5_11339_tc20-h1-15-ema5-21-rsi21-candle-pattern - Strategy Spec

**EA ID:** QM5_11339
**Slug:** tc20-h1-15-ema5-21-rsi21-candle-pattern
**Source:** e78a9f1f-4e6a-563c-a080-915133d6ed28
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This H1 FX EA opens a long trade when EMA(5) has crossed above EMA(21) on the last closed bar or the bar before it, RSI(21) is above 50, EMA(5) remains above EMA(21), and a bullish engulfing or hammer pattern appears within that same one-bar window. It opens a short trade on the mirrored conditions: EMA(5) crosses below EMA(21), RSI(21) is below 50, EMA(5) remains below EMA(21), and a bearish engulfing or inverted hammer appears within one bar.

The stop is placed beyond the recent 10-bar swing low/high with a 2-pip buffer and is kept at least ATR(14) x 1.5 away from entry for the P2 stop instruction. There is no fixed take-profit because the card specifies EMA/RSI reversal exits: open positions close when EMA(5) recrosses EMA(21) against the trade or RSI(21) crosses back through 50 against the trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_fast_period | 5 | 3-15 | Fast EMA used for the cross trigger and trend state |
| strategy_ema_slow_period | 21 | 15-50 | Slow EMA used for the cross trigger and trend state |
| strategy_rsi_period | 21 | 7-30 | RSI period used for entry state and reversal exit |
| strategy_rsi_mid_level | 50.0 | 40-60 | RSI threshold for long/short state and exit recross |
| strategy_swing_lookback | 10 | 5-20 | Number of closed bars used for recent swing stop |
| strategy_swing_buffer_pips | 2 | 0-10 | Extra pips beyond the swing high/low for the stop |
| strategy_atr_period | 14 | 7-30 | ATR period for the P2 minimum stop distance |
| strategy_atr_sl_mult | 1.5 | 0.5-5.0 | ATR multiplier for the P2 minimum stop distance |
| strategy_hammer_wick_mult | 2.0 | 1.0-4.0 | Required long wick to body ratio for hammer patterns |
| strategy_hammer_oppwick_pct | 10.0 | 0-30 | Maximum opposite wick as percent of candle range |
| strategy_spread_cap_pips | 20 | 1-50 | Blocks only genuinely wide non-zero spreads |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card primary FX major; H1 EMA, RSI, and OHLC data are available in the DWX matrix.
- GBPUSD.DWX - Card primary FX major; H1 EMA, RSI, and OHLC data are available in the DWX matrix.
- USDJPY.DWX - P2 expansion symbol from the card; pip scaling is handled through framework stop helpers.

**Explicitly NOT for:**
- Index, commodity, and crypto `.DWX` symbols - the approved card is an H1 forex strategy with a 20-pip spread cap and FX candlestick assumptions.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Not specified in card; expected to be hours to a few days from H1 reversal exits |
| Expected drawdown profile | Not specified in card; fixed $1,000 risk per backtest trade via framework sizing |
| Regime preference | Trend-following EMA crossover with candlestick confirmation |
| Win rate target (qualitative) | Not specified in card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** e78a9f1f-4e6a-563c-a080-915133d6ed28
**Source type:** book / local PDF archive
**Pointer:** Thomas Carter, `20 Forex Trading Strategies (1 Hour Time Frame)`, Forex Trading Strategy #15, local PDF path cited in the approved card.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11339_tc20-h1-15-ema5-21-rsi21-candle-pattern.md`.

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
| v1 | 2026-06-20 | Initial build from card | 83184d24-4234-457f-8bd4-f42959bb2f5f |
