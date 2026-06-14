# QM5_10755_tv-sweep-rider - Strategy Spec

**EA ID:** QM5_10755
**Slug:** tv-sweep-rider
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see approved TradingView mechanical strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA detects confirmed swing highs and lows with configurable left and right pivot bars. On each closed M5 bar, it looks for a liquidity sweep: a long signal occurs when the bar trades below an active swing low and closes back above it, and a short signal occurs when the bar trades above an active swing high and closes back below it. The sweep bar must have tick volume above its volume SMA multiplied by the configured threshold. Stops use the sweep candle extreme plus an ATR buffer, capped at a maximum ATR distance from entry, and the take-profit is fixed by the configured reward-to-risk multiple.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_pivot_left | 5 | >= 1 | Bars to the left of a candidate swing point. |
| strategy_pivot_right | 5 | >= 1 | Bars to the right required to confirm a swing point. |
| strategy_pivot_lookback | 120 | 1-500 | Maximum closed bars searched for active swing levels. |
| strategy_volume_sma_length | 20 | >= 1 | Tick-volume SMA length used for the sweep candle filter. |
| strategy_volume_multiplier | 1.25 | > 0 | Sweep candle volume must exceed SMA times this multiplier. |
| strategy_atr_period | 14 | >= 1 | ATR period for stop placement. |
| strategy_atr_buffer_mult | 0.25 | > 0 | ATR buffer beyond the sweep candle extreme. |
| strategy_atr_max_stop_mult | 2.0 | > 0 | Maximum stop distance from entry in ATR units. |
| strategy_rr_target | 2.0 | > 0 | Take-profit reward-to-risk multiple. |
| strategy_allow_longs | true | true/false | Enables long sweep entries. |
| strategy_allow_shorts | true | true/false | Enables short sweep entries. |
| strategy_session_filter | false | true/false | Optional London/New York style hour filter from the card. |
| strategy_session_start_hour | 7 | 0-23 | Broker-hour start for the optional session filter. |
| strategy_session_end_hour | 21 | 0-23 | Broker-hour end for the optional session filter. |
| strategy_max_spread_points | 0 | >= 0 | Optional spread cap in points; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - card includes gold; sweep and ATR logic ports to DWX metals.
- EURUSD.DWX - card includes EURUSD; liquid FX pair with tick-volume proxy.
- GBPUSD.DWX - card includes GBPUSD; liquid FX pair with tick-volume proxy.
- USDJPY.DWX - R3 section adds USDJPY to the primary P2 basket.
- NDX.DWX - card includes Nasdaq index exposure; DWX matrix provides NDX.

**Explicitly NOT for:**
- SPY.DWX - unavailable in the DWX matrix; no phantom symbols are registered.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Intraday, driven by M5 reversal entries and fixed SL/TP. |
| Expected drawdown profile | Stop clustering risk around recent pivot extremes; spread sensitivity on M5. |
| Regime preference | Intraday reversal after liquidity sweeps with volume expansion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView script
**Pointer:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_10755_tv-sweep-rider.md
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10755_tv-sweep-rider.md`; card R3 notes tick-volume portability should be validated downstream.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-14 | Initial build from card | 0f9f9ac7-56b4-473d-8d33-01578f2f8080 |
