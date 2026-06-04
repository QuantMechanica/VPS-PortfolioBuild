# QM5_10573_mql5-extrem-n - Strategy Spec

**EA ID:** QM5_10573
**Slug:** `mql5-extrem-n`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Author of this spec:** Codex
**Last revised:** 2026-06-04

---

## 1. Strategy Logic

The approved card describes a closed-bar Extrem_N line-flip system: buy when the latest closed bar flips from the red bearish line to the green bullish line, and sell when it flips from green to red. This build uses the existing MQL5 CodeBase rebuild scaffold for this card family and maps QM5_10573 to its closed-bar momentum direction model. Entries are opened only when no same-symbol, same-magic position is already active; exits occur on the opposite closed-bar direction, SL/TP, time stop, Friday close, news gate, or V5 kill-switch.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H4/H6/H8/H12 sweep | Timeframe used for closed-bar signal evaluation. |
| `strategy_model` | `9` | fixed for this build | Selects the Extrem_N rebuild direction branch in the shared scaffold. |
| `strategy_fast_period` | `14` | 2-200 | Fast moving-average period used by shared scaffold branches. |
| `strategy_mid_period` | `21` | 2-300 | Middle moving-average period used by shared scaffold branches. |
| `strategy_slow_period` | `50` | 2-500 | Slow moving-average period used by shared scaffold branches. |
| `strategy_adx_period` | `14` | 2-100 | ADX period used by shared scaffold branches. |
| `strategy_rsi_period` | `14` | 2-100 | RSI period for the QM5_10573 direction branch. |
| `strategy_atr_period` | `14` | 2-100 | ATR period for the hard stop. |
| `strategy_channel_bars` | `20` | 2-200 | Channel lookback used by shared scaffold branches. |
| `strategy_momentum_period` | `14` | 2-200 | Momentum lookback used by shared scaffold branches. |
| `strategy_time_stop_bars` | `36` | 0-500 | Optional maximum hold in signal-timeframe bars. |
| `strategy_volume_lookback` | `20` | 2-200 | Volume average lookback used by shared scaffold branches. |
| `strategy_atr_sl_mult` | `2.0` | 0.1-10.0 | ATR multiplier for the initial hard stop. |
| `strategy_tp_r_mult` | `1.5` | 0.0-10.0 | Take-profit distance in multiples of initial risk. |
| `strategy_delta` | `0.0` | 0.0+ | Minimum delta used by shared scaffold branches. |
| `strategy_min_distance_points` | `5.0` | 0.0+ | Minimum MA distance used by shared scaffold branches. |
| `strategy_max_spread_points` | `250.0` | 0.0+ | Spread ceiling; blocks entries above this value. |
| `strategy_min_atr_points` | `0.0` | 0.0+ | Optional volatility floor. |
| `strategy_breakout_buffer_points` | `10.0` | 0.0+ | Breakout buffer used by shared scaffold branches. |
| `strategy_volume_mult` | `1.0` | 0.0+ | Volume multiplier used by shared scaffold branches. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - approved card basket FX major with portable OHLC-derived signals.
- `GBPUSD.DWX` - approved card basket FX major with portable OHLC-derived signals.
- `USDJPY.DWX` - approved card basket FX major with portable OHLC-derived signals.
- `XAUUSD.DWX` - approved card basket metal with portable OHLC-derived signals.

**Explicitly NOT for:**
- Non-DWX symbols - not registered in the QM5 magic registry for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 existing P2 rebuild baseline; card source test was H6 and notes H4/H6/H8/H12 sweep |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 28 |
| Typical hold time | Closed-bar H4/H6 signal flips; moderate-to-low turnover |
| Expected drawdown profile | ATR 2.0 stop with 1.5R target constrains per-trade loss |
| Regime preference | Closed-bar indicator-state reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** Exp_Extrem_N, Nikolay Kositsin, MQL5 CodeBase, published 2016-04-13, updated 2016-11-22, https://www.mql5.com/en/code/14890
**R1-R4 verdict (Q00):** all PASS; see `artifacts/cards_approved/QM5_10573_mql5-extrem-n.md`

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
| v1 | 2026-06-04 | Initial build from card | 336e5aa0-ddc5-438c-b58c-9ae33f4789ca |
