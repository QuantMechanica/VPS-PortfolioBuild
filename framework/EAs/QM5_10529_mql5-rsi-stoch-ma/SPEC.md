# QM5_10529_mql5-rsi-stoch-ma - Strategy Spec

**EA ID:** QM5_10529
**Slug:** `mql5-rsi-stoch-ma`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates closed H1 bars. It buys when the close is above SMA(150), RSI(3) is below 20, and Stochastic %K(6,3,3) is below 30. It sells when the close is below SMA(150), RSI(3) is above 80, and Stochastic %K(6,3,3) is above 70. Longs close when Stochastic %K rises above 70 with non-negative open profit; shorts close when Stochastic %K falls below 30 with non-negative open profit; both sides also use a 1.2 ATR(14) stop, 1.5R target, and 12-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ma_period` | 150 | 1+ | SMA trend filter period. |
| `strategy_rsi_period` | 3 | 1+ | RSI lookback period. |
| `strategy_rsi_long_level` | 20.0 | 0-100 | Long entry requires RSI below this level. |
| `strategy_rsi_short_level` | 80.0 | 0-100 | Short entry requires RSI above this level. |
| `strategy_stoch_k` | 6 | 1+ | Stochastic %K period. |
| `strategy_stoch_d` | 3 | 1+ | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | 1+ | Stochastic slowing period. |
| `strategy_stoch_long_level` | 30.0 | 0-100 | Long entry threshold and short exit threshold. |
| `strategy_stoch_short_level` | 70.0 | 0-100 | Short entry threshold and long exit threshold. |
| `strategy_atr_period` | 14 | 1+ | ATR period for protective stop. |
| `strategy_atr_sl_mult` | 1.2 | >0 | ATR multiple for protective stop. |
| `strategy_tp_rr` | 1.5 | >0 | Fixed reward/risk target. |
| `strategy_time_stop_bars` | 12 | 0+ | Maximum hold in base-timeframe bars; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card primary FX basket member with DWX data available.
- `GBPUSD.DWX` - card primary FX basket member with DWX data available.
- `USDJPY.DWX` - card primary FX basket member with DWX data available.
- `XAUUSD.DWX` - card primary metals basket member with DWX data available.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not valid for DWX backtest registration.
- Non-FX/metals symbols - not part of the approved R3 P2 basket for this card.

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
| Trades / year / symbol | `50` |
| Typical hold time | Up to 12 H1 bars by protective time stop. |
| Expected drawdown profile | ATR-normalized stop with fixed $1,000 backtest risk should create bounded single-position drawdowns. |
| Regime preference | MA(150) directional filter with RSI/Stochastic extreme entries; trend-filtered oscillator mean reversion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `forum / codebase`
**Pointer:** `https://www.mql5.com/en/code/18671`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10529_mql5-rsi-stoch-ma.md`

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
| v1 | 2026-05-29 | Initial build from card | 314bddfd-6273-42ad-91fc-caa0d84a8068 |
