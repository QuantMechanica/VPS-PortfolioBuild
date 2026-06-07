# QM5_11047_roman-sar-break - Strategy Spec

**EA ID:** QM5_11047
**Slug:** `roman-sar-break`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades H1 Parabolic SAR crossings through the completed bar open. A long entry fires when SAR moves from above the previous completed bar open to below the latest completed bar open; a short entry fires on the inverse crossing. Each entry uses an ATR(14) stop at 1.5x ATR, a 1.0R take profit, one active position per symbol/magic, and exits on the opposite SAR/open crossing or after the configured max bars in trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H1` | H1 | Base signal timeframe from the card |
| `strategy_psar_step` | `0.02` | 0.01-0.03 | Parabolic SAR acceleration step |
| `strategy_psar_maximum` | `0.20` | 0.10-0.30 | Parabolic SAR maximum acceleration |
| `strategy_atr_period` | `14` | fixed | ATR period for volatility filter and stop distance |
| `strategy_atr_sl_mult` | `1.50` | 1.00-2.00 | Stop-loss distance as a multiple of ATR |
| `strategy_tp_sl_ratio` | `1.00` | 0.75-1.25 | Take-profit distance relative to stop distance |
| `strategy_max_bars_in_trade` | `24` | 12-48 | Time exit in H1 bars |
| `strategy_break_even_enabled` | `true` | true/false | Enables optional break-even management |
| `strategy_break_even_trigger_r` | `0.75` | 0.75 | Move stop to entry after this R-multiple |
| `strategy_atr_percentile_lookback_bars` | `100` | >=20 | Lookback used for the ATR percentile filter |
| `strategy_min_atr_percentile` | `20.0` | 0-100 | Skip entries when ATR is below this rolling percentile |
| `strategy_median_spread_points` | `20.0` | >0 | Current spread must be no more than twice this median-spread proxy |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Source and card list EURUSD as an H1 FX test symbol.
- `GBPUSD.DWX` - Source and card list GBPUSD as an H1 FX test symbol.
- `USDCHF.DWX` - Source and card list USDCHF as an H1 FX test symbol.
- `USDJPY.DWX` - Source and card list USDJPY as an H1 FX test symbol.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - The approved card R3 basket is limited to four FX majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | H1 bars, capped by default at 24 bars |
| Expected drawdown profile | Whipsaw risk in range-bound markets, bounded by ATR SL, TP, break-even, and time exit |
| Regime preference | trend-following breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** MQL5 article and attachment
**Pointer:** `https://www.mql5.com/en/articles/350`, `strategysar.mqh` attachment
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11047_roman-sar-break.md`

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
| v1 | 2026-06-07 | Initial build from card | e865d357-5096-40ee-9320-da12c20a8731 |
