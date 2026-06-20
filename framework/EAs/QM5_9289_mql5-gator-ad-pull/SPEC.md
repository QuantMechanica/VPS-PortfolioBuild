# QM5_9289_mql5-gator-ad-pull - Strategy Spec

**EA ID:** QM5_9289
**Slug:** `mql5-gator-ad-pull`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades the MQL5 Part 77 Gator Oscillator plus Accumulation/Distribution pullback-continuation pattern on closed M30 bars. A long entry requires the Gator upper histogram to switch from contracting to expanding, the lower histogram to expand on both recent bars, the latest closed bar to make a higher high while closing no higher than the prior close, and the AD oscillator to rise for two bars. A short entry uses the same Gator transition, a lower low with no lower close than the prior bar, and a two-bar falling AD oscillator. Exits occur at the initial 2R target, ATR stop, Gator upper histogram contraction, two-bar adverse AD movement, framework Friday close, or after 96 M30 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_gator_jaw_period` | 13 | 2-100 | Alligator jaw SMMA period used in Gator upper calculation |
| `strategy_gator_jaw_shift` | 8 | 0-50 | Jaw forward shift mirrored as a closed-bar lookback offset |
| `strategy_gator_teeth_period` | 8 | 2-100 | Alligator teeth SMMA period used in both Gator histograms |
| `strategy_gator_teeth_shift` | 5 | 0-50 | Teeth forward shift mirrored as a closed-bar lookback offset |
| `strategy_gator_lips_period` | 5 | 2-100 | Alligator lips SMMA period used in Gator lower calculation |
| `strategy_gator_lips_shift` | 3 | 0-50 | Lips forward shift mirrored as a closed-bar lookback offset |
| `strategy_ad_fast_ema` | 5 | 2-50 | Fast EMA period applied to the ADL series |
| `strategy_ad_slow_ema` | 13 | 3-100 | Slow EMA period applied to the ADL series |
| `strategy_ad_warmup_bars` | 80 | 20-500 | Bounded closed-bar window for ADL EMA state |
| `strategy_atr_period` | 14 | 2-100 | ATR period for initial stop distance |
| `strategy_atr_sl_mult` | 1.0 | 0.1-10.0 | ATR multiple placed beyond signal-bar low or high |
| `strategy_take_profit_rr` | 2.0 | 0.1-10.0 | Initial take-profit multiple of initial risk |
| `strategy_time_stop_bars` | 96 | 1-1000 | Maximum hold time in M30 bars |
| `strategy_spread_cap_points` | 1000 | 0-100000 | Hard spread cap used as the DWX-safe implementation of the card spread filter |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - card target forex cross with M30 OHLC, tick volume, ATR, and Gator inputs available in DWX.
- `EURJPY.DWX` - card target forex cross with the same indicator and tick-volume data requirements.
- `XAUUSD.DWX` - card target metals symbol with DWX OHLC, tick volume, ATR, and Gator inputs available.

**Explicitly NOT for:**
- Non-DWX symbols - the build and setfiles use the framework `.DWX` research/backtest namespace.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `125` |
| Typical hold time | Intraday to two trading days; failsafe at 96 M30 bars |
| Expected drawdown profile | Trend-pullback drawdowns clustered during choppy volume-confirmation failures |
| Regime preference | Trend-following pullback continuation with volume confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/18946`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9289_mql5-gator-ad-pull.md`

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
| v1 | 2026-06-20 | Initial build from card | c63860e7-eb16-4181-9d58-672bf1ab3246 |
