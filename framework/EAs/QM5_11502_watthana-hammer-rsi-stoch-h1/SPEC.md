# QM5_11502_watthana-hammer-rsi-stoch-h1 — Strategy Spec

**EA ID:** QM5_11502
**Slug:** watthana-hammer-rsi-stoch-h1
**Source:** 84fab994-8d52-5062-a0ac-69c1c765aa4f (see `strategy-seeds/sources/84fab994-8d52-5062-a0ac-69c1c765aa4f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades completed-bar reversal candles on the active chart timeframe, with H1 as the card baseline. A long setup requires a Hammer or Inverted Hammer candle on the last closed bar, RSI(14) below 30, and Stochastic %K(5,3,3) below 20; a short setup requires a long-shadow bearish or bullish reversal candle, RSI(14) above 70, and Stochastic %K above 80. Entries are market orders on the next bar with an ATR(14) stop at 2.0 times ATR. Positions close when RSI returns through 50 in the direction of mean reversion or when the 20-bar maximum hold is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 2+ | RSI lookback period for entry and exit thresholds. |
| `strategy_stoch_k_period` | 5 | 2+ | Stochastic %K lookback period. |
| `strategy_stoch_d_period` | 3 | 1+ | Stochastic %D smoothing period used by the framework reader. |
| `strategy_stoch_slowing` | 3 | 1+ | Stochastic slowing value used by the framework reader. |
| `strategy_rsi_long_level` | 30.0 | 0-100 | Maximum RSI value for long entries. |
| `strategy_rsi_short_level` | 70.0 | 0-100 | Minimum RSI value for short entries. |
| `strategy_stoch_long_level` | 20.0 | 0-100 | Maximum Stochastic %K value for long entries. |
| `strategy_stoch_short_level` | 80.0 | 0-100 | Minimum Stochastic %K value for short entries. |
| `strategy_rsi_exit_long` | 50.0 | 0-100 | Long exit threshold once RSI reverts to neutral. |
| `strategy_rsi_exit_short` | 50.0 | 0-100 | Short exit threshold once RSI reverts to neutral. |
| `strategy_shadow_body_mult` | 2.0 | >0 | Required shadow-to-body multiple for reversal candle detection. |
| `strategy_atr_period` | 14 | 2+ | ATR lookback period for stop placement. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiple used for initial stop loss. |
| `strategy_max_hold_bars` | 20 | 0+ | Fallback time stop in bars; 0 disables the fallback. |
| `strategy_spread_cap_pips` | 15.0 | >0 | Maximum allowed spread for new entries. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary paper instrument and canonical DWX FX major.
- `GBPUSD.DWX` — liquid DWX FX major suitable for H1 candlestick and oscillator reversal tests.
- `AUDUSD.DWX` — liquid DWX FX major in the card's portable FX basket.
- `USDJPY.DWX` — liquid DWX FX major in the card's portable FX basket.

**Explicitly NOT for:**
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX` — the card specifies an H1 FX basket, not index CFDs.
- `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX` — commodities are outside the paper's EURUSD-style FX reversal scope.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Up to 20 H1 bars |
| Expected drawdown profile | Mean-reversion reversal trades with ATR-bounded downside per position. |
| Regime preference | Short-term mean reversion after oscillator extremes. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 84fab994-8d52-5062-a0ac-69c1c765aa4f
**Source type:** paper
**Pointer:** Watthana et al., "Developing A Forex Expert Advisor Based on Japanese Candlestick Patterns and Technical Trading Strategies", IJTEF Vol. 9 No. 6, DOI: 10.18178/ijtef.2018.9.6.622, December 2018.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11502_watthana-hammer-rsi-stoch-h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 9931ea7c-bb74-4312-b145-919c1998f649 |
