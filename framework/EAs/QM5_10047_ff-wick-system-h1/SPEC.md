# QM5_10047_ff-wick-system-h1 - Strategy Spec

**EA ID:** QM5_10047
**Slug:** ff-wick-system-h1
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA evaluates the just-closed H1 candle at each new H1 bar. It buys when the lower wick is larger than the upper wick and sells when the upper wick is larger than the lower wick, skipping exact wick ties. The prior candle range must be at least 0.25 times ATR(14), entries are limited to Monday through Thursday liquid-session hours, and spread must be no more than 10% of the fixed 50-pip stop. Positions exit through the fixed 50-pip TP, fixed 50-pip SL, or a strategy time exit after 12 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 1+ | ATR period for the minimum prior-bar range filter. |
| `strategy_min_range_atr` | 0.25 | 0.0+ | Minimum prior-bar range as a multiple of ATR. |
| `strategy_stop_pips` | 50 | 1+ | Fixed stop distance in pips. |
| `strategy_take_pips` | 50 | 1+ | Fixed take-profit distance in pips. |
| `strategy_max_spread_stop_pct` | 10.0 | 0.0+ | Maximum spread as percent of stop distance. |
| `strategy_max_hold_bars` | 12 | 1+ | H1 bars to hold before strategy time exit. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker-hour start of the liquid-session entry window. |
| `strategy_session_end_hour` | 20 | 0-23 | Broker-hour end of the liquid-session entry window. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 lists it as a primary DWX FX pair for OHLC wick testing.
- GBPUSD.DWX - card R3 lists it as a primary DWX FX pair for OHLC wick testing.
- USDJPY.DWX - card R3 lists it as a primary DWX FX pair for OHLC wick testing.
- EURJPY.DWX - card R3 lists it as a primary DWX FX pair for OHLC wick testing.

**Explicitly NOT for:**
- Symbols outside the four-card R3 basket - not registered for this EA and not part of the approved P2 baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` from the framework OnTick path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 900 |
| Typical hold time | Up to 12 H1 bars, with earlier TP or SL exits. |
| Expected drawdown profile | Fixed-risk, frequent FX wick system with bounded 50-pip stop per trade. |
| Regime preference | Statistical candle-wick directional edge in liquid FX sessions. |
| Expected trade frequency | Source rule fires every H1 candle; after session/spread filters estimate 700-1400 trades/year/symbol. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/771822-statistics-combined-with-system-profitable-what-do-you
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10047_ff-wick-system-h1.md`

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
| v1 | 2026-06-09 | Initial build from card | 9e4c76dd-e40d-40a1-b374-c7ed0aa7eafd |
