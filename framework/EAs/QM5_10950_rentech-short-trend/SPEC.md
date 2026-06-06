# QM5_10950_rentech-short-trend - Strategy Spec

**EA ID:** QM5_10950
**Slug:** rentech-short-trend
**Source:** 21ef3dfd-fac6-5d5d-b9a0-5ba447992f94 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades short-horizon H4 continuation after a completed-bar directional move. It goes long when ROC(6) is greater than 0.75 times ATR(14) divided by close, the close is above EMA(50), and ATR(14) divided by close is below its 252-bar 80th percentile. It goes short on the mirror condition. Exits occur when ROC(3) reverses against the position, close crosses EMA(20) against the position, the trade has been open for 12 H4 bars, or the framework SL/TP is hit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_roc_lookback` | 6 | 3-12 | Completed H4 bars used for entry ROC. |
| `strategy_exit_roc_lookback` | 3 | 3-12 | Completed H4 bars used for exit ROC reversal. |
| `strategy_atr_period` | 14 | 1+ | ATR period for entry threshold and stop distance. |
| `strategy_roc_atr_mult` | 0.75 | 0.50-1.00 | ATR-equivalent ROC threshold multiplier. |
| `strategy_trend_ema_period` | 50 | 20-100 | EMA trend filter for entries. |
| `strategy_exit_ema_period` | 20 | 1+ | EMA cross filter for exits. |
| `strategy_vol_lookback` | 252 | 2+ | ATR/close percentile lookback. |
| `strategy_vol_percentile` | 80.0 | 1-99 | Maximum ATR/close percentile allowed for entries. |
| `strategy_stop_atr_mult` | 1.5 | 1.0-2.0 | ATR multiple used for initial stop. |
| `strategy_tp_r_mult` | 1.8 | 0.1+ | Profit target in initial R. |
| `strategy_be_trigger_r` | 1.0 | 0.1+ | R multiple that moves stop to breakeven. |
| `strategy_max_hold_bars` | 12 | 6-24 | Maximum H4 bars to hold a position. |
| `strategy_spread_stop_ratio` | 0.10 | 0.01+ | Maximum spread as a fraction of stop distance. |
| `strategy_warmup_bars` | 300 | 300+ | Minimum H4 bars before signals are allowed. |
| `strategy_weekend_skip_hours` | 4 | 0+ | Hours before Friday close when new entries are skipped. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid currency exposure named by the card.
- `GBPUSD.DWX` - liquid currency exposure named by the card.
- `XAUUSD.DWX` - liquid metals exposure named by the card.
- `XAGUSD.DWX` - liquid metals exposure named by the card.
- `XTIUSD.DWX` - liquid commodity exposure named by the card.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's GER40 exposure.
- `NDX.DWX` - liquid index exposure named by the card.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is registered instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Up to 12 H4 bars, roughly 48 hours |
| Expected drawdown profile | Whipsaw losses in range-bound markets, bounded by ATR stop and volatility filter |
| Regime preference | Short-horizon trend continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 21ef3dfd-fac6-5d5d-b9a0-5ba447992f94
**Source type:** book
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10950_rentech-short-trend.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10950_rentech-short-trend.md`

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
| v1 | 2026-06-06 | Initial build from card | d3d08450-b706-4379-af25-67fee90fdbc8 |
