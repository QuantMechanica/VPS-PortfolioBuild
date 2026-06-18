# QM5_11039_atc-azxy-daily — Strategy Spec

**EA ID:** QM5_11039
**Slug:** `atc-azxy-daily`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

On each new D1 bar, the EA describes the prior day by close location inside its range, candle body direction, and range percentile versus the recent D1 range history. It compares that vector with the same day-of-year window from the prior year, keeps the closest analogs, and takes a long trade when their next-day median return is positive above the ATR threshold or a short trade when it is negative below the threshold. The EA places one market order per day at most, with TP from H1 ATR capped to a small pip target, SL as the larger of a TP multiple or H1 ATR, and a broker-time exit at 22:00.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pattern_window_days` | 10 | 1-20 | Calendar day-of-year window around the prior-year analog date. |
| `strategy_range_lookback_days` | 60 | 5-120 | D1 bars used to rank the prior-day range percentile. |
| `strategy_analog_top_percent` | 20.0 | 1-100 | Percent of closest prior-year analogs used for the median return. |
| `strategy_return_threshold_atr_mult` | 0.10 | 0.05-0.20 | Minimum analog median next-day return as a multiple of H1 ATR. |
| `strategy_tp_atr_mult` | 0.35 | 0.20-0.50 | TP distance as a multiple of H1 ATR before pip cap. |
| `strategy_sl_tp_multiple` | 2.0 | 1.5-3.0 | SL minimum as a multiple of TP distance. |
| `strategy_sl_atr_mult` | 1.0 | 0.5-2.0 | SL minimum as a multiple of H1 ATR. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for H1 TP/SL and D1 range filter. |
| `strategy_min_tp_pips` | 6 | 1-100 | Lower TP clamp in pips. |
| `strategy_max_tp_pips` | 10 | 1-100 | Upper TP clamp in pips. |
| `strategy_min_d1_range_atr_mult` | 0.75 | 0.1-2.0 | Minimum prior-day range as a multiple of D1 ATR. |
| `strategy_time_exit_hour_broker` | 22 | 0-23 | Broker/server hour for same-day time exit. |
| `strategy_max_spread_points` | 30 | 0-1000 | Maximum live modeled spread in points; zero spread passes. |
| `strategy_body_confirm_enabled` | false | true/false | Optional body-direction confirmation for the analog signal. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card target and DWX forex major with D1/H1 OHLC available.
- `GBPUSD.DWX` — card target and DWX forex major with D1/H1 OHLC available.
- `USDJPY.DWX` — card target and DWX forex major with D1/H1 OHLC available.
- `XAUUSD.DWX` — card target and DWX metal with D1/H1 OHLC available.

**Explicitly NOT for:**
- Equity index `.DWX` symbols — the approved card names FX/metals only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `PERIOD_H1` ATR for TP/SL sizing; `PERIOD_D1` ATR and OHLC for the pattern. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `150` |
| Typical hold time | Intraday; TP lock or broker-time close at 22:00. |
| Expected drawdown profile | Small-target daily scalp with fixed-risk SL and one active position per symbol/magic. |
| Regime preference | Daily-pattern short-horizon scalp. |
| Win rate target (qualitative) | Medium to high due to small TP target, with spread/slippage sensitivity. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** `MQL5 article interview`
**Pointer:** `https://www.mql5.com/en/articles/555`
**R1–R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11039_atc-azxy-daily.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | 6b3e132d-7117-4917-a4d3-5e28f163857d |
