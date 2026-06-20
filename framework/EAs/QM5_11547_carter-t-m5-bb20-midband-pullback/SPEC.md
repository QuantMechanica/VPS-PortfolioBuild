# QM5_11547_carter-t-m5-bb20-midband-pullback - Strategy Spec

**EA ID:** QM5_11547
**Slug:** carter-t-m5-bb20-midband-pullback
**Source:** 42530cb3-0265-534a-89cc-150f80733ff5 (see `sources/carter-thomas-20-forex-strategies-5min`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a Bollinger Band middle-band pullback on M5. A long setup requires the Bollinger middle band to be rising from bar 5 to bar 1, the last closed bar to touch the middle band from above, and the same bar to close back above the middle band. A short setup mirrors that logic with a falling middle band, a touch from below, and a close back below the middle band. The take profit is the outer band in the trade direction, and the stop is the opposite outer band capped to a maximum 15-pip loss.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | 14-25 | Bollinger Band period from the card and P3 sweep notes. |
| strategy_bb_deviation | 2.0 | 1.0-3.0 | Bollinger Band standard-deviation multiplier. |
| strategy_slope_lookback | 5 | 3-8 | Bars between midband slope comparison points. |
| strategy_slope_min_pips | 0.0 | 0.0-2.0 | Optional minimum middle-band slope distance; 0.0 implements the literal card rule `mid[1] > mid[5]`. |
| strategy_sl_max_pips | 15.0 | 1.0-50.0 | Maximum stop distance in pips. |
| strategy_no_friday_entry | true | true/false | Blocks new entries on Friday. |
| strategy_spread_max_pips | 5.0 | 0.0-20.0 | Blocks only genuinely wide positive spreads; zero modeled `.DWX` spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 lists EURUSD M5 as available and portable on DWX.
- GBPUSD.DWX - Card R3 lists GBPUSD M5 as available and portable on DWX.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - The source strategy and approved card describe a 5-minute forex setup, not indices, metals, or energy contracts.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Intraday; usually minutes to hours on M5. |
| Expected drawdown profile | Moderate stop-defined drawdowns from repeated 15-pip capped losses in sideways tape. |
| Regime preference | Trend pullback with mean-reversion to dynamic support/resistance. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 42530cb3-0265-534a-89cc-150f80733ff5
**Source type:** book
**Pointer:** `sources/carter-thomas-20-forex-strategies-5min`; Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", self-published 2014, System #4.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11547_carter-t-m5-bb20-midband-pullback.md`

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
| v1 | 2026-06-20 | Initial build from card | c76d4871-e2ad-4198-9536-032cfac33afe |
