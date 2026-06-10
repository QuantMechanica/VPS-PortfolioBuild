# QM5_9458_gk-2macd-sto - Strategy Spec

**EA ID:** QM5_9458
**Slug:** `gk-2macd-sto`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (Geraked/Rabist GitHub 2MACDSTO Expert Advisor)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA trades a pullback after two MACD filters disagree on the closed H3 bars. It buys when the slow MACD is positive, the fast MACD is negative, Stochastic was below 20 and not above its signal on bar 2, then Stochastic crosses above its signal on bar 1. It sells on the inverse condition with slow MACD negative, fast MACD positive, Stochastic above 80, and a bearish Stochastic cross. Exits occur at a 1R target, on the opposite valid signal, or after 40 H3 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_m1_fast` | 13 | 1-500 | Fast period for the short MACD filter. |
| `strategy_m1_slow` | 21 | 2-1000 | Slow period for the short MACD filter. |
| `strategy_m1_signal` | 1 | 1-100 | Signal period for the short MACD filter. |
| `strategy_m2_fast` | 34 | 1-500 | Fast period for the long MACD filter. |
| `strategy_m2_slow` | 144 | 2-1000 | Slow period for the long MACD filter. |
| `strategy_m2_signal` | 1 | 1-100 | Signal period for the long MACD filter. |
| `strategy_sto_k_period` | 7 | 1-100 | Stochastic K period. |
| `strategy_sto_d_period` | 3 | 1-100 | Stochastic D period. |
| `strategy_sto_slowing` | 3 | 1-100 | Stochastic slowing period. |
| `strategy_sto_oversold` | 20.0 | 0-100 | Long setup oversold threshold. |
| `strategy_sto_overbought` | 80.0 | 0-100 | Short setup overbought threshold. |
| `strategy_sl_lookback` | 7 | 1-200 | Closed-bar structure lookback for the swing stop. |
| `strategy_sl_dev_points` | 60 | 0-10000 | Stop deviation in raw symbol points added beyond the swing. |
| `strategy_tp_rr` | 1.0 | 0.1-10.0 | Reward-to-risk multiple for the take-profit. |
| `strategy_max_hold_bars` | 40 | 1-1000 | Fallback time exit in base timeframe bars. |

---

## 3. Symbol Universe

**Designed for:**
- `NZDUSD.DWX` - Card target and DWX forex symbol with native OHLC indicator coverage.
- `AUDUSD.DWX` - Card target and DWX forex symbol with native OHLC indicator coverage.
- `EURUSD.DWX` - Card target and DWX forex symbol with native OHLC indicator coverage.
- `GBPUSD.DWX` - Card target and DWX forex symbol with native OHLC indicator coverage.

**Explicitly NOT for:**
- Non-DWX symbols - Build and pipeline conventions require the registered `.DWX` symbols.
- Non-FX indices or commodities - The approved card only targets the listed forex basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H3` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Up to 40 H3 bars by fallback time exit; earlier via 1R target, stop, or opposite signal. |
| Expected drawdown profile | Fixed-risk swing-stop losses with no grid or multiple-position expansion. |
| Regime preference | Momentum-continuation pullback with oscillator-reversal timing. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub MQL5 expert advisor
**Pointer:** `https://github.com/geraked/metatrader5/blob/main/Experts/2MACDSTO.mq5`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9458_gk-2macd-sto.md`

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
| v1 | 2026-06-10 | Initial build from card | ae3a8024-8a8b-43b1-a05e-cb5a9c68f473 |
