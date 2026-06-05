# QM5_10819_tv-dema-vwap - Strategy Spec

**EA ID:** QM5_10819
**Slug:** tv-dema-vwap
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA computes a session VWAP and an EMA on the chart timeframe. A long entry is opened when the EMA is below VWAP and its slope turns positive on the latest closed bar; a short entry is opened when the EMA is above VWAP and its slope turns negative. Long positions close when the EMA is above VWAP and turns down, when the latest closed bar closes below VWAP, or when the session changes. Short positions close on the inverse rules, with an ATR emergency stop attached at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 21 | 2-200 | EMA length used for VWAP-side and slope-turn rules |
| strategy_slope_confirm_bars | 1 | 1-2 | Closed-bar spacing used to confirm the EMA slope turn |
| strategy_atr_period | 14 | 1-100 | ATR period for emergency stop distance |
| strategy_atr_stop_mult | 1.8 | 1.0-3.0 | Emergency stop multiplier applied to ATR(14) |
| strategy_min_session_bars | 8 | 1-64 | Minimum bars after session open before entries are allowed |
| strategy_max_spread_stop_fraction | 0.15 | 0.01-0.50 | Maximum spread as a fraction of emergency stop distance |
| strategy_vwap_anchor | 0 | 0-2 | VWAP anchor: 0 broker day, 1 London session, 2 New York session |
| strategy_london_start_hour | 7 | 0-23 | Broker-hour start for London-anchored VWAP |
| strategy_ny_start_hour | 13 | 0-23 | Broker-hour start for New-York-anchored VWAP |
| strategy_max_session_scan_bars | 160 | 8-240 | Bounded closed-bar scan for session VWAP |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid FX pair with broker tick volume for intraday VWAP.
- GBPUSD.DWX - liquid FX pair with broker tick volume for intraday VWAP.
- USDJPY.DWX - liquid FX pair with broker tick volume for intraday VWAP.
- XAUUSD.DWX - canonical DWX gold symbol for the card's XAUUSD target.
- GDAXI.DWX - canonical DWX DAX symbol used for the card's GER40.DWX target.
- NDX.DWX - liquid US index CFD for intraday VWAP/EMA slope testing.
- WS30.DWX - liquid US index CFD for intraday VWAP/EMA slope testing.

**Explicitly NOT for:**
- SPX500.DWX - not available in the DWX symbol matrix.
- SPY.DWX - not available in the DWX symbol matrix.
- GER40.DWX - not available in the DWX symbol matrix; GDAXI.DWX is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | same intraday session |
| Expected drawdown profile | whipsaw-prone around balanced VWAP sessions |
| Regime preference | intraday trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/d5I7yUXY-dEMA-w-VWAP-filter/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10819_tv-dema-vwap.md`

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
| v1 | 2026-06-05 | Initial build from card | 2ede08a9-66e2-4c0f-badb-ea7ff3b18622 |
