# QM5_11562_watthana-2018-candlestick-rsi14-stoch14-h4 - Strategy Spec

**EA ID:** QM5_11562
**Slug:** watthana-2018-candlestick-rsi14-stoch14-h4
**Source:** 85985515-bee5-5f5d-a618-9bd9fc924907
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades H4 reversal candles from Watthana 2018. A long entry requires a Hammer or Inverted Hammer on the last closed H4 bar, a downtrend proxy where Close[1] is below Close[10], RSI(14) below 30, and Stochastic K(14,3,3) below 20. A short entry requires a Hanging Man or Shooting Star on the last closed H4 bar, an uptrend proxy where Close[1] is above Close[10], RSI(14) above 70, and Stochastic K(14,3,3) above 80. Positions close when the opposite candle pattern appears, or when RSI/Stochastic reaches the opposite extreme; the only protective stop is the P2 safety stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_H4 | H4 primary; P3 may sweep H1/H4/D1 | Timeframe used for candle, RSI, and Stochastic signals. |
| strategy_rsi_period | 14 | 2-100 | RSI lookback period. |
| strategy_stoch_k | 14 | 2-100 | Stochastic K period. |
| strategy_stoch_d | 3 | 1-20 | Stochastic D period. |
| strategy_stoch_slowing | 3 | 1-20 | Stochastic slowing period. |
| strategy_trend_lookback_bars | 10 | 2-100 | Trend proxy bar: compare Close[1] with Close[N]. |
| strategy_rsi_oversold | 30.0 | 1-50 | Long RSI threshold. |
| strategy_rsi_overbought | 70.0 | 50-99 | Short RSI threshold and long exit threshold. |
| strategy_stoch_oversold | 20.0 | 1-50 | Long Stochastic threshold and short exit threshold. |
| strategy_stoch_overbought | 80.0 | 50-99 | Short Stochastic threshold and long exit threshold. |
| strategy_safety_stop_pips | 30 | 1-35 | P2 safety stop distance from entry. |
| strategy_max_stop_pips | 35 | 1-35 | Upper cap for safety stop pips. |
| strategy_spread_cap_pips | 15.0 | 0-100 | Blocks new entries when spread exceeds this value. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - the card's R3 PASS universe is explicitly H4 EURUSD.DWX from the Watthana paper context.

**Explicitly NOT for:**
- Non-EURUSD symbols - not registered for Q02 because the approved card's R3 row names only EURUSD.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Indicator exit on a later H4 bar; hours to days expected. |
| Expected drawdown profile | Reversal system with fixed 30-pip safety stop and no fixed TP. |
| Regime preference | Mean-reversion after long-shadow reversal candles. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 85985515-bee5-5f5d-a618-9bd9fc924907
**Source type:** paper
**Pointer:** Watthana Pongsena et al., "Developing A Forex Expert Advisor Based on Japanese Candlestick Patterns and Technical Trading Strategies", IJTEF Vol. 9 No. 6, December 2018, DOI 10.18178/ijtef.2018.9.6.622
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11562_watthana-2018-candlestick-rsi14-stoch14-h4.md`

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
| v1 | 2026-06-11 | Initial build from card | 1d8562ab-a247-4141-84a1-f5d1b0c8345e |
