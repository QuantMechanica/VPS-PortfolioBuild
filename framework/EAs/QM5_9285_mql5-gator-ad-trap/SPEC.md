# QM5_9285_mql5-gator-ad-trap - Strategy Spec

**EA ID:** QM5_9285
**Slug:** `mql5-gator-ad-trap`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades Pattern 5 from the MQL5 Gator and Accumulation/Distribution article. On each closed M30 bar, it requires two consecutive Gator states where the upper histogram is red and the lower histogram is green. A long entry fires when the last closed bar closes above the prior two highs and the AD oscillator is at least the maximum of its prior two values; a short entry mirrors this with a close below the prior two lows and an AD oscillator value at or below the prior two values. Exits occur on the card's price failure condition, two consecutive adverse AD oscillator steps, the 96-bar failsafe, TP, SL, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_jaw_period` | 13 | 5-50 | Bill Williams Alligator jaw SMMA period used to derive Gator upper histogram |
| `strategy_jaw_shift` | 8 | 1-20 | Alligator jaw visual shift |
| `strategy_teeth_period` | 8 | 3-30 | Alligator teeth SMMA period used by both Gator histograms |
| `strategy_teeth_shift` | 5 | 1-20 | Alligator teeth visual shift |
| `strategy_lips_period` | 5 | 2-20 | Alligator lips SMMA period used to derive Gator lower histogram |
| `strategy_lips_shift` | 3 | 1-20 | Alligator lips visual shift |
| `strategy_ad_fast_period` | 5 | 2-20 | Fast EMA period applied to the ADL series |
| `strategy_ad_slow_period` | 13 | 5-50 | Slow EMA period applied to the ADL series |
| `strategy_atr_period` | 14 | 5-50 | ATR period for initial stop distance |
| `strategy_atr_sl_mult` | 1.0 | 0.5-5.0 | ATR multiple added beyond the three-bar structure stop |
| `strategy_rr_take_profit` | 2.0 | 0.5-5.0 | Initial take-profit multiple of entry risk |
| `strategy_max_hold_bars` | 96 | 1-500 | Failsafe time exit in M30 bars |
| `strategy_ad_warmup_bars` | 80 | 30-300 | Bounded warmup window for ADL EMA oscillator calculation |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - card target; liquid JPY cross with frequent M30 directional breaks
- `EURJPY.DWX` - card target; liquid JPY cross with comparable Gator/AD behaviour
- `XAUUSD.DWX` - card target; gold volatility supports trap-breakout confirmation

**Explicitly NOT for:**
- Equity index CFDs - not listed by this card and not part of the approved R3 basket
- Non-DWX symbols - V5 research and backtest naming requires the `.DWX` suffix

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` in framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `140` |
| Typical hold time | M30 signal lifecycle, capped at 96 bars or about 48 hours |
| Expected drawdown profile | breakout-trap strategy with losses concentrated in failed continuation bursts |
| Regime preference | false-breakout confirmation with volume-confirmed trend continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** MQL5 article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 78): Gator and AD Oscillator Strategies for Market Resilience", MQL5 Articles, 2025-08-04, https://www.mql5.com/en/articles/18992
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9285_mql5-gator-ad-trap.md`

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
| v1 | 2026-06-20 | Initial build from card | d898e3e9-fd31-4c06-8923-11487ba09183 |
