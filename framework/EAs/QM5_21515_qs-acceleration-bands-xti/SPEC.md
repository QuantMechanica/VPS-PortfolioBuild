# QM5_21515_qs-acceleration-bands-xti — Strategy Spec

**EA ID:** QM5_21515
**Slug:** qs-acceleration-bands-xti
**Source:** 0b564ef2-810c-5b1d-9084-342ddb20575c
**Author of this spec:** Gemini
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

The strategy implements Price Headley's Acceleration Bands indicator as a daily momentum breakout system on XTIUSD (crude oil CFD). Raw upper and lower bands are calculated from each bar's High and Low proportionally to its range, and smoothed using a 20-period simple moving average alongside an SMA midline.

A LONG entry is triggered on a closed D1 bar when the previous close breaks out above the smoothed Upper band while the Upper band is sloping upward. A SHORT entry is triggered when the previous close breaks down below the smoothed Lower band while the Lower band is sloping downward. Positions are protected with an initial ATR hard stop, exited on a recross of the SMA midline, or closed after a 60-bar maximum hold time limit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_accel_factor` | 0.001 | 0.0007-0.0015 | Price Headley acceleration multiplier factor |
| `strategy_band_sma_period` | 20 | 14-30 | SMA smoothing period for raw bands and midline |
| `strategy_slope_lookback` | 5 | 3-10 | Lookback shift for band slope direction filter |
| `strategy_atr_period` | 14 | 10-20 | ATR period for initial stop loss calculation |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.5 | ATR multiplier for hard stop loss distance |
| `strategy_max_hold_bars` | 60 | 30-100 | Maximum bar hold time exit guard |
| `strategy_warmup_buffer` | 20 | 10-40 | Additional bar warmup safety margin |
| `strategy_max_spread_points` | 600 | 400-900 | Maximum allowable spread filter in points |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` — Crude oil commodity CFD with sufficient volatility and trend persistence for range-proportional band breakouts.

**Explicitly NOT for:**
- `FX / Index instruments` — Card design is single-symbol calibrated for XTIUSD energy dynamics.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 6 |
| Typical hold time | 10 to 45 days |
| Expected drawdown profile | <= 22% peak-to-trough equity drawdown |
| Regime preference | Momentum breakout / trend expansion |
| Win rate target (qualitative) | Medium (45% to 55% with positive payoff ratio) |

---

## 6. Source Citation

**Source ID:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Source type:** Web / Research (Quantified Strategies)
**Pointer:** QuantifiedStrategies.com, "Acceleration Bands (Trading Strategy)", Price Headley methodology
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_21515_qs-acceleration-bands-xti.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | Initial build from approved card | Router task 7b3b2cfb-2a30-4b7d-b394-2f985d5a8319 |
