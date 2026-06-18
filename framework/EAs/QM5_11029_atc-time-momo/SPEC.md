# QM5_11029_atc-time-momo - Strategy Spec

**EA ID:** QM5_11029
**Slug:** atc-time-momo
**Source:** 9441393d-5ffc-5b43-87be-bd532110f204 (see MQL5 article citation in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA evaluates one setup per symbol per broker-server trading day at the configured fixed time, default 10:36. It measures the close-to-close movement over the prior lookback window on M5 bars and enters in the direction of that movement when the move is at least `strategy_min_movement_atr` times ATR(14). The stop is a fixed ATR multiple, the target is a fixed ATR multiple, and the target is pulled closer when the prior movement is already strong. Any open position is closed at the configured end-of-day time if neither SL nor TP has closed it first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_hour_server` | 10 | 0-23 | Broker-server hour for the fixed daily setup. |
| `strategy_entry_minute_server` | 36 | 0-59 | Broker-server minute for the fixed daily setup. |
| `strategy_entry_window_minutes` | 10 | >=1 | Grace window after the fixed time so M5 closed-bar callbacks can evaluate the 10:36 setup. |
| `strategy_eod_hour_server` | 21 | 0-23 | Broker-server hour for forced end-of-day flat. |
| `strategy_eod_minute_server` | 0 | 0-59 | Broker-server minute for forced end-of-day flat. |
| `strategy_lookback_minutes` | 60 | >=5 | Prior movement window measured close-to-close. |
| `strategy_atr_period` | 14 | >=2 | ATR period on the chart timeframe. |
| `strategy_min_movement_atr` | 0.50 | >0 | Minimum movement, in ATR units, required to trade. |
| `strategy_strong_movement_atr` | 1.50 | >0 | Movement threshold that switches to the nearer strong-move target. |
| `strategy_sl_atr_mult` | 0.80 | >0 | Stop-loss distance in ATR units. |
| `strategy_tp_normal_atr_mult` | 1.20 | >0 | Take-profit distance for normal movement. |
| `strategy_tp_strong_atr_mult` | 0.80 | >0 | Take-profit distance for strong prior movement. |
| `strategy_use_stop_order` | false | true/false | Use stop order with ATR buffer instead of market order. |
| `strategy_entry_buffer_atr` | 0.10 | >=0 | Stop-order buffer in ATR units. |
| `strategy_max_spread_points` | 0 | >=0 | Optional spread cap in points; 0 disables it for DWX zero-spread tests. |
| `strategy_use_h1_ema_filter` | false | true/false | Optional H1 EMA direction filter from the card. |
| `strategy_h1_ema_period` | 48 | >=2 | EMA period for the optional H1 direction filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX symbol with M5 DWX data.
- `GBPUSD.DWX` - card-listed liquid FX symbol with M5 DWX data.
- `USDJPY.DWX` - card-listed liquid FX symbol with M5 DWX data.
- `EURJPY.DWX` - card-listed liquid FX cross with M5 DWX data.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline artifacts require canonical DWX symbols.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no validated tester data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | Optional H1 EMA(48) filter when enabled |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, from fixed entry setup to SL/TP or end-of-day flat |
| Expected drawdown profile | One bounded fixed-risk attempt per trading day limits clustering. |
| Regime preference | Intraday momentum / time-of-day |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9441393d-5ffc-5b43-87be-bd532110f204
**Source type:** MQL5 article / interview
**Pointer:** https://www.mql5.com/en/articles/606
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11029_atc-time-momo.md`

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
| v1 | 2026-06-18 | Initial build from card | e71a71af-73d8-4fae-8f9d-8168ff9e5641 |
