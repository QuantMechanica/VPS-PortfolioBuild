# QM5_1068_carver-breakout-range - Strategy Spec

**EA ID:** QM5_1068
**Slug:** carver-breakout-range
**Source:** 2a380bee-1ec4-50d1-a348-b10fac642c7a (see `strategy-seeds/sources/2a380bee-1ec4-50d1-a348-b10fac642c7a/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

On each closed D1 bar the EA reads the last 80 daily closes, finds the highest and lowest close in that window, and computes a capped Carver forecast from the latest close's distance from the range midpoint. It opens long when the forecast is above +2 and short when the forecast is below -2. A long is closed when the forecast falls below zero, and a short is closed when the forecast rises above zero. Each new trade receives an emergency stop at 2.5 times ATR(20, D1).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_lookback_d1_bars | 80 | 2-512 | Number of closed D1 closes used for the rolling range. |
| strategy_entry_forecast | 2.0 | >0 | Absolute forecast threshold for long and short entry. |
| strategy_forecast_scalar | 40.0 | >0 | Scalar applied to the range-midpoint forecast formula. |
| strategy_forecast_cap | 20.0 | >0 | Absolute cap applied to the forecast. |
| strategy_atr_period | 20 | >0 | ATR period for the emergency stop. |
| strategy_atr_sl_mult | 2.5 | >0 | ATR multiple for the emergency stop. |
| strategy_spread_median_days | 20 | 1-64 | D1 spread samples used for the median spread cap. |
| strategy_spread_mult | 2.0 | >0 | Maximum current spread as a multiple of the median spread. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- GDAXI.DWX - matrix-approved DAX proxy for the card's GER40.DWX basket member.
- NDX.DWX - liquid Nasdaq 100 index CFD for daily trend-following.
- WS30.DWX - liquid Dow 30 index CFD for daily trend-following.
- EURUSD.DWX - major FX pair with daily OHLC history.
- GBPUSD.DWX - major FX pair with daily OHLC history.
- USDJPY.DWX - major FX pair with daily OHLC history.
- XAUUSD.DWX - gold CFD, matching the card's metals sleeve.
- XTIUSD.DWX - crude oil CFD, matching the card's oil sleeve.

**Explicitly NOT for:**
- SP500.DWX - not listed in this card's proposed P2 universe.
- GER40.DWX - card-stated name is not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is the registered canonical DAX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entry dispatch; D1 forecast cache advances from the latest closed D1 bar. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 500 |
| Typical hold time | days |
| Expected drawdown profile | Trend-following drawdowns during range-bound markets; emergency ATR stop bounds single-trade loss. |
| Regime preference | trend / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Source type:** blog
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1068_carver-breakout-range.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1068_carver-breakout-range.md`

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
| v1 | 2026-06-14 | Initial build from card | 5079d90b-530f-4917-aeeb-a74639fdb6a1 |
