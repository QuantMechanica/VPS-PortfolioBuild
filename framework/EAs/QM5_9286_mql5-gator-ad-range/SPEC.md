# QM5_9286_mql5-gator-ad-range - Strategy Spec

**EA ID:** QM5_9286
**Slug:** `mql5-gator-ad-range`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a closed-bar M30 range breakout when the Gator oscillator shows a sleeping-range color state and the Accumulation/Distribution EMA oscillator confirms the breakout direction. A long opens when the latest closed bar closes above the highs of the prior two closed bars, the AD oscillator is at or above its prior two values, and ATR(14) is above its 20-bar median. A short mirrors the rule below the prior two lows with AD at or below its prior two values. Exits occur when price closes back inside the prior two-bar range, AD reverses for two consecutive closed bars, the 96-bar time stop is reached, or the framework Friday close fires.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_jaw_period` | 13 | 2-100 | Alligator jaw SMMA period used for Gator upper histogram. |
| `strategy_jaw_shift` | 8 | 0-50 | Alligator jaw displacement used in the Gator calculation. |
| `strategy_teeth_period` | 8 | 2-100 | Alligator teeth SMMA period used in both Gator histograms. |
| `strategy_teeth_shift` | 5 | 0-50 | Alligator teeth displacement used in the Gator calculation. |
| `strategy_lips_period` | 5 | 2-100 | Alligator lips SMMA period used for Gator lower histogram. |
| `strategy_lips_shift` | 3 | 0-50 | Alligator lips displacement used in the Gator calculation. |
| `strategy_ad_fast_period` | 5 | 2-50 | Fast EMA period for the ADL oscillator. |
| `strategy_ad_slow_period` | 13 | 3-100 | Slow EMA period for the ADL oscillator. |
| `strategy_ad_warmup_bars` | 80 | 20-300 | Closed-bar warmup window for ADL EMA state. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for stop distance and volatility filter. |
| `strategy_atr_median_lookback` | 20 | 3-100 | Median ATR lookback for stale micro-range rejection. |
| `strategy_atr_sl_mult` | 1.0 | 0.1-10.0 | ATR multiple added beyond the three-bar stop structure. |
| `strategy_rr_take_profit` | 2.2 | 0.1-10.0 | Initial take-profit distance in R multiples. |
| `strategy_max_hold_bars` | 96 | 1-500 | Failsafe time exit in chart bars. |
| `strategy_spread_cap_points` | 1000 | 0-10000 | Maximum modeled spread in points; zero modeled spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `EURGBP.DWX` - card-approved EUR/GBP cross with DWX M30 OHLC and tick volume.
- `GBPJPY.DWX` - card-approved GBP/JPY cross with DWX M30 OHLC and tick volume.
- `EURUSD.DWX` - card-approved major FX pair with DWX M30 OHLC and tick volume.

**Explicitly NOT for:**
- Non-DWX or unregistered symbols - the EA relies on V5 magic registration and DWX tester data.
- Symbols outside the card target list - not part of the approved R3 universe for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | M30 breakout hold, capped at 96 M30 bars (about 48 hours) |
| Expected drawdown profile | Fixed-risk breakout sleeve with losses bounded by ATR/structure stops. |
| Regime preference | Range accumulation/distribution breakout after volatility compression. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** MQL5 article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 78): Gator and AD Oscillator Strategies for Market Resilience", 2025-08-04, https://www.mql5.com/en/articles/18992
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9286_mql5-gator-ad-range.md`

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
| v1 | 2026-06-20 | Initial build from card | eb41a5b9-4ec6-47f1-a909-1b258aca5b03 |
