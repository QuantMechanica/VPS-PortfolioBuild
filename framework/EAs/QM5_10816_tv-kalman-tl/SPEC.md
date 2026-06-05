# QM5_10816_tv-kalman-tl - Strategy Spec

**EA ID:** QM5_10816
**Slug:** `tv-kalman-tl`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA computes a fixed-parameter Kalman-smoothed close line on confirmed bars, then builds upper and lower trend levels one ATR offset around that center line. It opens long when the latest closed bar crosses above the upper trend level and the Kalman slope is positive for the configured confirmation count; it opens short on the mirrored cross below the lower level with negative slope. Long positions close when price crosses below the Kalman center, the Kalman slope is negative for two closed bars, or the configured max-bars timeout is reached; short positions mirror the same rules. Initial stop is the opposite Kalman trend level, capped by the fallback safety stop of 2.0 ATR from entry, and the stop trails to the Kalman center only after the position reaches +1R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_kalman_process_noise` | 0.05 | >0 | Fixed Kalman process-noise parameter. |
| `strategy_kalman_measurement_noise` | 2.0 | >0 | Fixed Kalman measurement-noise parameter. |
| `strategy_kalman_warmup_bars` | 80 | 20-240 | Closed-bar warmup depth used to seed the Kalman estimate. |
| `strategy_atr_period` | 14 | >=1 | ATR period for trend-level offset and safety stop. |
| `strategy_level_atr_mult` | 1.0 | >0 | ATR multiplier for the upper and lower Kalman trend levels. |
| `strategy_safety_stop_atr_mult` | 2.0 | >0 | Maximum fallback safety-stop distance in ATR units. |
| `strategy_slope_confirmation_bars` | 2 | 1-10 | Number of closed bars that must confirm Kalman slope direction for entries. |
| `strategy_use_sma_filter` | false | true/false | Optional SMA trend filter from the card; false keeps the baseline on pure Kalman levels. |
| `strategy_sma_period` | 200 | >=1 | SMA period used when the optional trend filter is enabled. |
| `strategy_max_bars_h1` | 120 | >=1 | Max-bars exit for H1 runs. |
| `strategy_max_bars_h4` | 80 | >=1 | Max-bars exit for H4 runs. |
| `strategy_max_spread_points` | 0 | >=0 | Optional spread cap; 0 disables the strategy-specific cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with OHLC and ATR data for Kalman trend testing.
- `GBPUSD.DWX` - liquid FX major from the card's portable P2 basket.
- `USDJPY.DWX` - liquid FX major from the card's portable P2 basket.
- `XAUUSD.DWX` - canonical DWX gold symbol for the card's `XAUUSD` target.
- `GDAXI.DWX` - available DAX proxy in the DWX matrix; used for the card's `GER40.DWX` target.
- `NDX.DWX` - liquid US large-cap index from the card's basket.
- `WS30.DWX` - liquid US large-cap index from the card's basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.

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
| Trades / year / symbol | approximately 45 |
| Typical hold time | up to 120 H1 bars or 80 H4 bars unless signal reversal or SL hits first |
| Expected drawdown profile | whipsaw losses in low-volatility ranges and lag after abrupt reversals |
| Regime preference | trend-following breakout around a smoothed Kalman level |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView strategy page
**Pointer:** `https://www.tradingview.com/script/iK7h4vm6/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10816_tv-kalman-tl.md`

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
| v1 | 2026-06-05 | Initial build from card | a9c5510f-28bd-4510-8272-23e043e925c9 |
