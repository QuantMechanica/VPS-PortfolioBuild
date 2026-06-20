# QM5_9288_mql5-gator-ad-mtf — Strategy Spec

**EA ID:** QM5_9288
**Slug:** mql5-gator-ad-mtf
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades M30 breakouts only when the M30 Gator oscillator is expanding and the latest fully closed H4 bar also has at least one expanding Gator histogram. A long entry requires the just-closed M30 close to break above the prior M30 high, the latest closed H4 close to be above the previous H4 close, and the M30 Accumulation/Distribution oscillator not to be below its prior three-bar minimum. A short entry mirrors this with a break below the prior M30 low, falling H4 close direction, and AD not above its prior three-bar maximum.

Long exits trigger when two closed H4 bars fall consecutively, the M30 close loses the prior-bar low, or the trade reaches the 120-M30-bar time stop. Short exits trigger when two closed H4 bars rise consecutively, the M30 close recaptures the prior-bar high, or the same time stop is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_higher_tf` | `PERIOD_H4` | MT5 timeframe enum | Higher timeframe used for Gator and close-direction confirmation. |
| `strategy_jaw_period` | 13 | 2-100 | Alligator jaw SMMA period used to reconstruct Gator upper histogram. |
| `strategy_jaw_shift` | 8 | 0-50 | Jaw forward shift used in Gator reconstruction. |
| `strategy_teeth_period` | 8 | 2-100 | Alligator teeth SMMA period used by both Gator histograms. |
| `strategy_teeth_shift` | 5 | 0-50 | Teeth forward shift used in Gator reconstruction. |
| `strategy_lips_period` | 5 | 2-100 | Alligator lips SMMA period used to reconstruct Gator lower histogram. |
| `strategy_lips_shift` | 3 | 0-50 | Lips forward shift used in Gator reconstruction. |
| `strategy_ad_fast_period` | 5 | 2-50 | Fast EMA period of the AD oscillator. |
| `strategy_ad_slow_period` | 13 | 3-100 | Slow EMA period of the AD oscillator. |
| `strategy_ad_warmup_bars` | 80 | 25-300 | Closed-bar history used to warm up AD oscillator EMAs. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for initial stop offset. |
| `strategy_swing_lookback_bars` | 5 | 2-50 | Closed M30 bars used to approximate the latest swing high or low for stop placement. |
| `strategy_atr_sl_mult` | 1.0 | 0.1-10.0 | ATR multiple placed beyond the latest swing high or low. |
| `strategy_rr_take_profit` | 2.2 | 0.1-10.0 | Initial take-profit multiple of entry risk. |
| `strategy_max_hold_bars` | 120 | 1-1000 | Failsafe time exit measured in M30 bars. |
| `strategy_spread_cap_points` | 1000 | 0-100000 | Blocks only genuinely wide positive spreads; zero modeled spread remains tradable. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` — card-listed JPY cross with M30 and H4 DWX OHLC and tick-volume coverage.
- `EURJPY.DWX` — card-listed JPY cross with the same M30/H4 Gator and AD inputs available.
- `UK100.DWX` — card-listed index CFD with M30/H4 OHLC and tick-volume coverage.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — the tester does not provide canonical DWX data for them.
- Monthly-only or external-macro symbols — this EA uses native M30/H4 OHLC and tick-volume only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `H4` Gator histogram color and H4 closed-bar close direction |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `85` |
| Typical hold time | Intraday to several days, capped at 120 M30 bars |
| Expected drawdown profile | Trend-breakout drawdowns clustered during choppy or reversing regimes |
| Regime preference | Multi-timeframe trend-following breakout with volume participation confirmation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** MQL5 article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 78): Gator and AD Oscillator Strategies for Market Resilience", MQL5 Articles, 2025-08-04, https://www.mql5.com/en/articles/18992
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9288_mql5-gator-ad-mtf.md`

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
| v1 | 2026-06-20 | Initial build from card | da4759c6-e334-4e18-b49c-95a4457cd5c8 |
