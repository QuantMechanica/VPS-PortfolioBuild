# QM5_10617_mql5-harami-sto - Strategy Spec

**EA ID:** QM5_10617
**Slug:** mql5-harami-sto
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see MQL5 CodeBase source URL)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA evaluates completed H1 bars only. It opens long when the most recent completed candle forms a Bullish Harami inside the previous bearish candle body and the Stochastic signal line on that completed bar is below 30. It opens short when the most recent completed candle forms a Bearish Harami inside the previous bullish candle body and the Stochastic signal line is above 70. Long positions close when the Stochastic signal line crosses downward through 80 or 20; short positions close when it crosses upward through 20 or 80. Every entry also receives a hard ATR(14) stop at 1.5 times ATR and a 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_work_tf` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for Harami and Stochastic reads. |
| `strategy_stoch_k_period` | `5` | `1+` | Stochastic K period. |
| `strategy_stoch_d_period` | `3` | `1+` | Stochastic signal-line period. |
| `strategy_stoch_slowing` | `3` | `1+` | Stochastic slowing value. |
| `strategy_stoch_entry_oversold` | `30.0` | `0-100` | Long entry requires signal line below this level. |
| `strategy_stoch_entry_overbought` | `70.0` | `0-100` | Short entry requires signal line above this level. |
| `strategy_stoch_exit_low` | `20.0` | `0-100` | Low Stochastic exit-cross threshold. |
| `strategy_stoch_exit_high` | `80.0` | `0-100` | High Stochastic exit-cross threshold. |
| `strategy_atr_period` | `14` | `1+` | ATR period for initial protective stop. |
| `strategy_atr_sl_mult` | `1.5` | `>0` | ATR multiplier for stop distance. |
| `strategy_take_profit_rr` | `1.5` | `>0` | Fixed target as reward-to-risk multiple. |
| `strategy_max_spread_points` | `80` | `0+` | Maximum entry spread in points; `0` disables the guard. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair with continuous DWX H1 OHLC and Stochastic availability.
- `GBPUSD.DWX` - major FX pair with liquid H1 reversal behaviour and DWX coverage.
- `USDJPY.DWX` - major FX pair included by the approved card and present in the DWX matrix.
- `XAUUSD.DWX` - liquid metal CFD included by the approved card; ATR stops scale to its wider range.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - unavailable to the DWX backtest infrastructure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Expected trade frequency | Harami reversal patterns gated by Stochastic extremes on H1 should be sparse to moderate; conservative estimate is 20-40 trades/year/symbol. |
| Typical hold time | Not stated in card frontmatter; exits are Stochastic threshold crosses plus SL/TP. |
| Expected drawdown profile | Fixed-risk reversal strategy with losses bounded by ATR protective stops. |
| Regime preference | Candlestick reversal / oscillator-confirmed mean reversion, inferred from card mechanics. |
| Win rate target (qualitative) | Not stated in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/310
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10617_mql5-harami-sto.md`

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
| v1 | 2026-06-13 | Initial build from card | b91c909b-4790-495d-ac74-2d51813b1656 |
