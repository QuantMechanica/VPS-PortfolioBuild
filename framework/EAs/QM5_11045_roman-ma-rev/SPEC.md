# QM5_11045_roman-ma-rev - Strategy Spec

**EA ID:** QM5_11045
**Slug:** `roman-ma-rev`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (see `artifacts/cards_approved/QM5_11045_roman-ma-rev.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades Roman Zamozhnyy's fixed moving-average reversal-cross module on H1 bars. It opens a short when the long SMA is rising and the short SMA crosses above the long SMA on the latest closed bar. It opens a long when the long SMA is falling and the short SMA crosses below the long SMA. Positions exit on the opposite reversal-cross, protective SL/TP, or after the configured maximum H1 bars in trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | H1 baseline | Timeframe used for SMA and ATR reads. |
| `strategy_short_sma_period` | `8` | 5, 8, 13, 21 | Short SMA period from the card's test grid. |
| `strategy_long_sma_period` | `55` | 34, 55, 89 | Long SMA period from the card's test grid. |
| `strategy_atr_period` | `14` | 14 baseline | ATR period for SL and ATR filter. |
| `strategy_atr_sl_mult` | `1.5` | 1.0-2.0 | SL distance as ATR multiple. |
| `strategy_tp_sl_ratio` | `1.0` | 0.75-1.25 | TP distance relative to SL distance. |
| `strategy_max_bars_in_trade` | `24` | 12, 24, 48 | Time exit after this many signal-timeframe bars. |
| `strategy_break_even_enabled` | `true` | true/false | Enables the card-authorized break-even move. |
| `strategy_break_even_r` | `0.75` | 0.75 baseline | Profit in R before SL moves to entry. |
| `strategy_atr_percentile_lookback` | `100` | fixed baseline | Rolling ATR sample count for percentile filter. |
| `strategy_min_atr_percentile` | `20.0` | 20 baseline | Blocks entries at or below this ATR percentile. |
| `strategy_min_atr_samples` | `40` | 1-100 | Minimum valid ATR samples before trading. |
| `strategy_median_spread_points` | `20` | symbol-dependent | Fixed median-spread proxy in points. |
| `strategy_spread_max_mult` | `2.0` | 2 baseline | Blocks spread above median proxy times this multiple. |
| `strategy_session_filter_enabled` | `false` | true/false | Optional London+NY session gate from the card. |
| `strategy_session_start_hour` | `7` | 0-23 | Broker-hour session start if enabled. |
| `strategy_session_end_hour` | `21` | 0-23 | Broker-hour session end if enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Source and card list EURUSD for H1 FX MA testing.
- `GBPUSD.DWX` - Source and card list GBPUSD for H1 FX MA testing.
- `USDCHF.DWX` - Source and card list USDCHF for H1 FX MA testing.
- `USDJPY.DWX` - Source and card list USDJPY for H1 FX MA testing.

**Explicitly NOT for:**
- `SP500.DWX` - The approved card is an FX-pair strategy and does not call for index exposure.
- `XAUUSD.DWX` - The approved card does not include metals in the R3 basket.

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
| Trades / year / symbol | `45` |
| Typical hold time | `Up to 24 H1 bars unless opposite signal, SL, or TP fires first` |
| Expected drawdown profile | `Counter-cross mean-reversion can fight strong trends; fixed SL/TP bounds per-trade risk.` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/350`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11045_roman-ma-rev.md`

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
| v1 | 2026-06-07 | Initial build from card | 50547f14-9c75-4772-83d5-802f24b61b63 |
