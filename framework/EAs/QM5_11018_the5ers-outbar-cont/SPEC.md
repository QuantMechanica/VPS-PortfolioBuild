# QM5_11018_the5ers-outbar-cont - Strategy Spec

**EA ID:** QM5_11018
**Slug:** the5ers-outbar-cont
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see `sources/the5ers-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades H4 outside-bar continuation after a pullback in an EMA trend. A closed outside bar must engulf the prior bar, align with the EMA(20)/EMA(50) trend state, follow a recent pullback to EMA(20) that did not break EMA(50), and close in the trend direction. It places a stop entry one tick beyond the outside bar, uses a 2 ATR initial stop, takes a 50% partial at 2 ATR, moves the stop to breakeven at 80% of that distance, trails by 2 ATR, and exits if price closes on the wrong side of EMA(50) or after 24 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 20 | 5-100 | Fast EMA used for trend and pullback state. |
| `strategy_ema_slow_period` | 50 | 10-200 | Slow EMA used for trend state and signal exit. |
| `strategy_pullback_bars` | 5 | 1-20 | Number of bars before the outside bar scanned for a pullback. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for range filter, stop, targets, and trailing. |
| `strategy_range_min_atr` | 1.0 | 0.1-5.0 | Minimum outside-bar range as ATR multiple. |
| `strategy_range_max_atr` | 3.0 | 0.5-10.0 | Maximum outside-bar range as ATR multiple. |
| `strategy_order_expiry_bars` | 2 | 1-6 | Pending stop order expiry in H4 bars. |
| `strategy_sl_atr_mult` | 2.0 | 0.5-5.0 | Initial stop distance as ATR multiple. |
| `strategy_tp1_atr_mult` | 2.0 | 0.5-5.0 | First target distance as ATR multiple. |
| `strategy_tp1_partial_pct` | 50.0 | 1-99 | Percent of open volume closed at the first target. |
| `strategy_be_trigger_pct` | 80.0 | 1-100 | Percent of first target distance required before SL moves to breakeven. |
| `strategy_trail_atr_mult` | 2.0 | 0.5-5.0 | ATR multiple for trailing the remaining position. |
| `strategy_final_rr` | 7.0 | 1-20 | Final take-profit in initial-risk multiples. |
| `strategy_time_stop_bars` | 24 | 1-100 | Maximum holding period in H4 bars. |
| `strategy_risk_cap_d1_pct` | 75.0 | 1-200 | Maximum initial risk distance as percent of 20-day ATR. |
| `strategy_spread_pct_of_atr` | 15.0 | 0-100 | Maximum spread as percent of H4 ATR; zero modeled spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target forex major with H4 OHLC, EMA, and ATR data.
- `GBPUSD.DWX` - card target forex major with H4 OHLC, EMA, and ATR data.
- `USDJPY.DWX` - card target forex major with H4 OHLC, EMA, and ATR data.
- `AUDUSD.DWX` - card target forex major with H4 OHLC, EMA, and ATR data.
- `EURJPY.DWX` - card target forex cross with H4 OHLC, EMA, and ATR data.
- `XAUUSD.DWX` - card target gold CFD with H4 OHLC, EMA, and ATR data.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest registries require canonical `.DWX` names.
- Unregistered symbols - magic resolution is only reserved for the six card targets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 ATR(20) risk-cap reference |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 36 |
| Typical hold time | Intraday to 4 trading days, capped at 24 H4 bars |
| Expected drawdown profile | Trend-continuation pullback system with ATR-defined risk per trade |
| Regime preference | Trend continuation after pullback |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** blog
**Pointer:** https://the5ers.com/outside-bar-candlestick/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11018_the5ers-outbar-cont.md`

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
| v1 | 2026-06-18 | Initial build from card | 962e4f90-ae6d-4f45-8b4d-5561e4cf4e96 |
