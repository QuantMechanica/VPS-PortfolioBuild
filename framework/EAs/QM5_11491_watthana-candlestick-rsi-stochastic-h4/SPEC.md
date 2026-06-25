# QM5_11491_watthana-candlestick-rsi-stochastic-h4 - Strategy Spec

**EA ID:** QM5_11491
**Slug:** `watthana-candlestick-rsi-stochastic-h4`
**Source:** `0d6086c2-6e04-5266-a1c5-93b79cc15ffd` (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades H4 reversal setups on completed bars. A trade can open when the last closed candle has a long upper or lower shadow, EMA(50) slopes in the exhausted trend direction over five bars, and both RSI(14) and Stochastic(5,3,3) are in the matching oversold or overbought zone. Long entries require a declining EMA with RSI below 30 and Stochastic %K below 20; short entries require a rising EMA with RSI above 70 and Stochastic %K above 80. Exits are the fixed ATR stop and target, framework Friday close, or a full opposite-direction confluence signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 50 | `> 0` | EMA period used for the trend-slope state. |
| `strategy_ema_slope_bars` | 5 | `> 0` | Closed bars between current EMA and prior EMA slope comparison. |
| `strategy_shadow_mult` | 2.0 | `> 0` | Required shadow-to-body ratio for hammer / shooting-star style candles. |
| `strategy_rsi_period` | 14 | `> 0` | RSI lookback period. |
| `strategy_rsi_os` | 30.0 | `0-100` | RSI oversold threshold for long entries. |
| `strategy_rsi_ob` | 70.0 | `0-100` | RSI overbought threshold for short entries. |
| `strategy_stoch_k` | 5 | `> 0` | Stochastic %K period. |
| `strategy_stoch_d` | 3 | `> 0` | Stochastic %D period. |
| `strategy_stoch_slow` | 3 | `> 0` | Stochastic slowing period. |
| `strategy_stoch_os` | 20.0 | `0-100` | Stochastic oversold threshold for long entries. |
| `strategy_stoch_ob` | 80.0 | `0-100` | Stochastic overbought threshold for short entries. |
| `strategy_atr_period` | 14 | `> 0` | ATR lookback period for SL and TP. |
| `strategy_sl_atr_mult` | 2.0 | `> 0` | Stop-loss distance in ATR multiples. |
| `strategy_tp_atr_mult` | 3.0 | `> 0` | Take-profit distance in ATR multiples. |
| `strategy_spread_cap_pips` | 20 | `>= 0` | Skip new work when modeled spread is wider than this pip cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - the card explicitly names EURUSD as a forex target and it is present in the DWX matrix.
- `GBPUSD.DWX` - the card explicitly names GBPUSD as a forex target and it is present in the DWX matrix.

**Explicitly NOT for:**
- `SP500.DWX` - index exposure is outside this forex candlestick card.
- `NDX.DWX` - index exposure is outside this forex candlestick card.
- `WS30.DWX` - index exposure is outside this forex candlestick card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `15` |
| Typical hold time | H4 multi-bar hold; not explicitly specified in card frontmatter |
| Expected drawdown profile | Reversal strategy with fixed 2 ATR stop and 3 ATR target; P2 validation required |
| Regime preference | Mean-reversion / reversal after trend exhaustion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0d6086c2-6e04-5266-a1c5-93b79cc15ffd`
**Source type:** paper
**Pointer:** Panichkul et al., "Developing A Forex Expert Advisor Based on Japanese Candlestick Patterns and Technical Trading Strategies", IJTEF 2018, DOI:10.18178/ijtef.2018.9.6.622.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11491_watthana-candlestick-rsi-stochastic-h4.md`

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
| v1 | 2026-06-26 | Initial build from card | 6d945846-96ba-41fc-ade3-2044e72c3d09 |
