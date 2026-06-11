<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate
Validator: framework/scripts/validate_spec_doc.py
-->

# QM5_9975_ff-pipsaccumulator-d1 — Strategy Spec

**EA ID:** QM5_9975
**Slug:** `ff-pipsaccumulator-d1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On the D1 timeframe, the EA waits for the EMA(5) to be above EMA(10) (uptrend) and the last closed bar to print a pullback lower low (Low[1] < Low[2]). When both conditions hold, a buy stop order is placed 1 pip above the pullback bar's high; the stop loss is set at the minimum low of the signal bar and the previous 2 D1 bars minus 3 pips, and take profit is at 3R. The mirror logic applies for shorts (EMA(5) < EMA(10), higher high pullback bar, sell stop below the bar's low). Each D1 bar the pending order is cancelled and reworked while conditions remain valid; it is cancelled outright after 5 D1 bars unfilled. Once a position is open, stop loss moves to breakeven after +1R, and from the 5th day a trailing stop follows the 3-bar low/high minus/plus 3 pips. The position closes early if EMA(5)/EMA(10) cross in the opposite direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 5 | 3–20 | Fast EMA period for trend filter |
| `strategy_ema_slow` | 10 | 5–50 | Slow EMA period for trend filter |
| `strategy_entry_pips` | 1 | 1–5 | Pips above/below pullback bar for stop entry |
| `strategy_sl_buffer_pips` | 3 | 1–10 | Pips beyond local extrema for stop loss |
| `strategy_tp_r_multiple` | 3.0 | 1.0–5.0 | Take profit as multiple of 1R |
| `strategy_sl_lookback` | 3 | 1–5 | D1 bars for local extrema (SL reference) |
| `strategy_trail_start_days` | 5 | 3–10 | Days from entry before trailing activates |
| `strategy_trail_lookback` | 3 | 1–5 | D1 bars for trailing low/high reference |
| `strategy_stale_bars` | 5 | 2–10 | Cancel pending after this many D1 bars unfilled |
| `strategy_spread_max_pct` | 6.0 | 0–20 | Max spread as % of SL distance (0 = disabled) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair, sufficient daily range, liquid D1 bars, EMA pullback well-defined
- `GBPUSD.DWX` — major FX pair, trending characteristics suit EMA5/10 D1 pullback
- `USDJPY.DWX` — major FX pair, strong trend regimes, low spread relative to D1 stop distances
- `AUDUSD.DWX` — commodity-correlated major FX pair, D1 pullbacks common in trend phases

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500) — EMA5/10 D1 pullback stop calibrated for FX pip conventions; card targets FX majors only

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~25 |
| Typical hold time | 2–10 days |
| Expected drawdown profile | Moderate; 3R target with 1R SL, BE after 1R limits runaway losses |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** bpola, "PipsAccumulator", ForexFactory, 2021, https://www.forexfactory.com/thread/post/13711869
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9975_ff-pipsaccumulator-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 9c4fc5a6-e3ed-4f9d-ad49-ae7734540df9 |
