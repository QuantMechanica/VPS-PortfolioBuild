# QM5_9287_mql5-gator-ad-flip - Strategy Spec

**EA ID:** QM5_9287
**Slug:** mql5-gator-ad-flip
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades the MQL5 Pattern 8 Gator plus Accumulation/Distribution flip setup on closed H1 bars. A long entry requires both Gator histograms to be in contraction, Standard Deviation to be no larger than the larger Gator histogram magnitude, the AD oscillator two-bar range to be small relative to Standard Deviation, the last closed close above the prior bar midpoint, and AD rising. A short entry uses the same Gator, Standard Deviation, and AD range gates, but requires the last closed close below the prior bar midpoint and AD falling. Exits occur when the midpoint or AD direction has reversed for two consecutive closed bars, or after 72 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_jaw_period` | 13 | 2-100 | Alligator jaw SMMA period used to derive the Gator upper histogram. |
| `strategy_jaw_shift` | 8 | 0-50 | Alligator jaw forward shift applied as a closed-bar offset. |
| `strategy_teeth_period` | 8 | 2-100 | Alligator teeth SMMA period used in both Gator histograms. |
| `strategy_teeth_shift` | 5 | 0-50 | Alligator teeth forward shift applied as a closed-bar offset. |
| `strategy_lips_period` | 5 | 2-100 | Alligator lips SMMA period used to derive the Gator lower histogram. |
| `strategy_lips_shift` | 3 | 0-50 | Alligator lips forward shift applied as a closed-bar offset. |
| `strategy_stddev_period` | 20 | 2-200 | Standard Deviation period used by the Pattern 8 volatility gate. |
| `strategy_ad_fast_period` | 5 | 2-50 | Fast EMA period for the AD oscillator. |
| `strategy_ad_slow_period` | 13 | 3-100 | Slow EMA period for the AD oscillator. |
| `strategy_ad_warmup_bars` | 80 | 20-500 | Closed bars used to seed the ADL EMA oscillator. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for stop distance and the dead-range filter. |
| `strategy_atr_median_lookback` | 50 | 3-250 | ATR samples used for the median volatility filter. |
| `strategy_swing_lookback` | 5 | 1-50 | Bars used for recent swing high or low stop placement. |
| `strategy_atr_sl_mult` | 1.0 | 0.1-10.0 | ATR multiple added outside the swing stop. |
| `strategy_rr_take_profit` | 2.5 | 0.1-20.0 | Initial take profit in R multiples. |
| `strategy_max_hold_bars` | 72 | 1-500 | Failsafe maximum holding period in H1 bars. |
| `strategy_spread_cap_points` | 1000 | 0-100000 | Wide-spread guard; zero spread is allowed for DWX tests. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - Card-listed H1 DWX forex target with sufficient volatility for Gator and AD flip behavior.
- `XAUUSD.DWX` - Card-listed H1 DWX metals target with liquid trend-flip regimes.
- `GDAXI.DWX` - Card-listed H1 DWX index target matching the source's liquid market assumption.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the tester has no sanctioned DWX data path for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `65` |
| Typical hold time | Up to 72 H1 bars, with earlier strategy exits on two-bar reversal. |
| Expected drawdown profile | Medium frequency reversal sleeve with fixed 2.5R targets and swing-plus-ATR stops. |
| Regime preference | Trend-reversal / volume-spike flip after Gator contraction. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** MQL5 article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 78): Gator and AD Oscillator Strategies for Market Resilience", 2025-08-04, https://www.mql5.com/en/articles/18992
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9287_mql5-gator-ad-flip.md`

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
| v1 | 2026-06-25 | Initial build from card | afcdefbd-3a49-4798-a043-78221efc0785 |
