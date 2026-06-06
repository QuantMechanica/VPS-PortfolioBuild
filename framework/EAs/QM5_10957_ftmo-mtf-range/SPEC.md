# QM5_10957_ftmo-mtf-range - Strategy Spec

**EA ID:** QM5_10957
**Slug:** `ftmo-mtf-range`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H4 mean reversion at the edges of a D1 range. It builds the D1 range from the highest high and lowest low over the last 60 closed D1 bars, requires at least two ATR-tolerant touches on both boundaries, and only trades when the range width is between 2x and 8x D1 ATR(14). A long entry requires D1 EMA(50) >= EMA(200), H4 close near support, RSI(14) below 30, and a recent close below the lower Bollinger Band followed by the current H4 close back inside the band; shorts mirror this at resistance with RSI above 70. SL is beyond the active range boundary by 0.5x H4 ATR(14), TP is the opposite D1 boundary unless that is farther than 3R, in which case TP is 2R; positions are closed after 20 H4 bars if SL or TP has not fired.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_lookback_d1` | 60 | 2-200 | Closed D1 bars used to define the active support/resistance range. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for D1 range validation and H4 stop spacing. |
| `strategy_ema_fast_period` | 50 | 1-300 | Fast D1 EMA used for trend bias. |
| `strategy_ema_slow_period` | 200 | 1-500 | Slow D1 EMA used for trend bias. |
| `strategy_rsi_period` | 14 | 1-100 | H4 RSI period for overbought/oversold confirmation. |
| `strategy_bb_period` | 20 | 1-100 | H4 Bollinger Band period. |
| `strategy_bb_return_lookback_bars` | 3 | 1-10 | Prior H4 bars checked for a close outside the relevant Bollinger Band. |
| `strategy_max_hold_h4_bars` | 20 | 1-200 | Maximum hold time before strategy time exit. |
| `strategy_range_touch_atr_mult` | 0.35 | 0.01-2.00 | D1 ATR multiplier used as touch tolerance for both range boundaries. |
| `strategy_boundary_entry_atr_mult` | 0.25 | 0.01-2.00 | H4 ATR distance allowed between close and active range boundary. |
| `strategy_sl_atr_mult` | 0.50 | 0.01-5.00 | H4 ATR offset beyond support/resistance for the stop loss. |
| `strategy_min_range_atr_mult` | 2.00 | 0.10-20.00 | Minimum D1 range width in D1 ATR units. |
| `strategy_max_range_atr_mult` | 8.00 | 0.10-50.00 | Maximum D1 range width in D1 ATR units. |
| `strategy_rsi_long_max` | 30.0 | 1-50 | Long entries require H4 RSI below this value. |
| `strategy_rsi_short_min` | 70.0 | 50-99 | Short entries require H4 RSI above this value. |
| `strategy_bb_deviation` | 2.0 | 0.1-5.0 | H4 Bollinger Band standard-deviation multiplier. |
| `strategy_fallback_rr` | 2.0 | 0.1-10.0 | Fallback TP multiple when the opposite boundary is farther than the cap. |
| `strategy_opposite_boundary_max_rr` | 3.0 | 0.1-20.0 | Opposite-boundary distance cap in R before fallback TP is used. |
| `strategy_max_spread_stop_fraction` | 0.10 | 0.0-1.0 | Maximum allowed spread as a fraction of planned stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Major FX pair in the card's portable DWX basket.
- `GBPUSD.DWX` - Major FX pair in the card's portable DWX basket.
- `USDJPY.DWX` - Major FX pair in the card's portable DWX basket.
- `XAUUSD.DWX` - Liquid metals symbol in the card's portable DWX basket.

**Explicitly NOT for:**
- `SP500.DWX` - Not part of this FX/metals range-reversion card.
- `NDX.DWX` - Not part of this FX/metals range-reversion card.
- `WS30.DWX` - Not part of this FX/metals range-reversion card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` range, `D1` EMA(50/200), `D1` ATR(14), `H4` RSI/Bollinger/ATR |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Up to 20 H4 bars. |
| Expected drawdown profile | Mean-reversion drawdowns during persistent breakouts through D1 range boundaries. |
| Regime preference | Range-bound mean reversion with D1 trend/range confirmation. |
| Win rate target (qualitative) | Medium to high, driven by support/resistance mean reversion. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `blog`
**Pointer:** `https://ftmo.com/en/blog/multi-timeframe-range-strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10957_ftmo-mtf-range.md`

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
| v1 | 2026-06-06 | Initial build from card | 8282ad33-99ef-4971-86d6-c1b22701c4a7 |
