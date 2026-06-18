# QM5_11891_unger-daily-factor-indecision-pattern - Strategy Spec

**EA ID:** QM5_11891
**Slug:** unger-daily-factor-indecision-pattern
**Source:** 4c5f1a9d-8e2b-5cc6-a4d2-f8e9b3c1d7a5
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

On each newly closed D1 bar, the EA checks whether the candle shows indecision: absolute body size divided by full high-low range is below 0.50. If that condition is true, it places a buy-stop one pip above the closed bar high and a sell-stop one pip below the closed bar low, both valid for the next D1 session. The first side to fill becomes the position and the remaining pending order is cancelled. Exits use a 1.5 x ATR(14) stop, a 3.0 x ATR(14) take profit, and a time stop after five D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_body_range_threshold | 0.50 | 0.01-0.99 | Maximum body/range ratio for an indecision candle. |
| strategy_signal_shift | 1 | 1-10 | Closed D1 bar shift used for the setup candle. |
| strategy_trigger_offset_pips | 1 | 1-100 | Pip offset above high or below low for pending stop triggers. |
| strategy_stop_atr_period | 14 | 1-200 | ATR period used for stop and target distances. |
| strategy_stop_atr_mult | 1.50 | 0.10-20.00 | ATR multiple for stop-loss distance. |
| strategy_target_atr_mult | 3.00 | 0.10-40.00 | ATR multiple for take-profit distance. |
| strategy_holding_max_d1_bars | 5 | 1-30 | Maximum D1 bars to hold before strategy time stop. |
| strategy_order_expiration_hours | 24 | 1-168 | Pending order lifetime for the next D1 session. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Forex major, card-listed symmetric long/short target.
- GBPUSD.DWX - Forex major, card-listed symmetric long/short target.
- USDJPY.DWX - Forex major, card-listed symmetric long/short target.
- USDCAD.DWX - Forex major, card-listed symmetric long/short target.
- USDCHF.DWX - Forex major, card-listed symmetric long/short target.
- AUDUSD.DWX - Forex major, card-listed symmetric long/short target.
- NZDUSD.DWX - Forex major, card-listed symmetric long/short target.
- EURJPY.DWX - Forex cross, card-listed symmetric long/short target.
- GBPJPY.DWX - Forex cross, card-listed symmetric long/short target.
- AUDJPY.DWX - Forex cross, card-listed symmetric long/short target.

**Explicitly NOT for:**
- SP500.DWX, NDX.DWX, WS30.DWX - The card says index futures have asymmetric long/short dynamics not appropriate for this formulation.
- XAUUSD.DWX, XAGUSD.DWX, XTIUSD.DWX, XNGUSD.DWX - The card excludes commodities from the symmetric forex pattern.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Up to 5 D1 bars |
| Expected drawdown profile | Breakout losses cluster during unresolved range conditions; losses are bounded by ATR stop. |
| Regime preference | Trend continuation after indecision and volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 4c5f1a9d-8e2b-5cc6-a4d2-f8e9b3c1d7a5
**Source type:** interview
**Pointer:** Andrea Unger interview, Better System Trader Episode 045, transcript pages 6-7, URL https://bettersystemtrader.com/045
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11891_unger-daily-factor-indecision-pattern.md`

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
| v1 | 2026-06-18 | Initial build from card | 88fd82ef-d7bc-4e4b-9ba3-4a057a1ca431 |
