# QM5_10251_tv-nova-rev - Strategy Spec

**EA ID:** QM5_10251
**Slug:** `tv-nova-rev`
**Source:** `c84ae47e-8ea0-56f1-8b25-4436b6dda5b5` (see `strategy-seeds/sources/c84ae47e-8ea0-56f1-8b25-4436b6dda5b5/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades mean reversion from Nova Reversal Bands. It computes fair value as `0.5 * HMA(50) + 0.5 * WMA(50)`, then places upper and lower bands around that center using the 85th percentile closed-candle range plus ATR(14), multiplied by 2.4. A long entry requires a lower-band touch, one to four recent lower-band touches, at least two score components from deep penetration, ATR expansion, and band widening, plus a bullish pin bar or bullish engulfing candle. A short entry mirrors the same logic at the upper band; exits are by the fair-value take profit, stop beyond the touched band, or a 30-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fair_period` | 50 | 4+ | HMA/WMA period for the fair-value center line. |
| `strategy_atr_period` | 14 | 1+ | ATR period used in band width and stop offset. |
| `strategy_range_lookback` | 50 | 2+ | Closed-bar sample size for percentile candle range. |
| `strategy_range_percentile` | 85.0 | 0-100 | Percentile range used in the volatility band width. |
| `strategy_band_mult` | 2.4 | >0 | Multiplier applied to percentile range plus ATR. |
| `strategy_sl_atr_mult` | 0.25 | >=0 | ATR offset beyond the touched band for stop placement. |
| `strategy_touch_lookback` | 20 | 1+ | Closed bars used to count band touch memory. |
| `strategy_min_touches` | 1 | 0+ | Minimum touches required before a reversal trade. |
| `strategy_max_touches` | 4 | 1+ | Maximum touches allowed before the setup is treated as exhausted. |
| `strategy_pin_wick_ratio` | 0.50 | 0-1 | Minimum rejection wick share of the full candle range. |
| `strategy_deep_penetration_atr` | 0.10 | >=0 | ATR fraction required for the deep-penetration score component. |
| `strategy_max_hold_bars` | 30 | 0+ | Time stop measured in current-chart bars; 0 disables. |
| `strategy_max_spread_points` | 0.0 | 0+ | Optional spread blocker in points; 0 leaves it disabled. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - primary symbol from the approved card and suitable for volatility-band mean reversion.
- `EURUSD.DWX` - card-listed P2 portable FX symbol with liquid OHLC data.
- `GBPUSD.DWX` - card-listed P2 portable FX symbol with liquid OHLC data.
- `NDX.DWX` - card-listed P2 portable index symbol with volatile reversal behavior.

**Explicitly NOT for:**
- Any symbol outside the registered basket - no implicit runtime expansion is intended.

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
| Trades / year / symbol | 80 |
| Typical hold time | Up to 30 bars; target is fair-value reversion. |
| Expected drawdown profile | Mean-reversion losses bounded by fixed per-trade risk and band-based stops. |
| Regime preference | Mean-revert / reversal after volatility-band extremes. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c84ae47e-8ea0-56f1-8b25-4436b6dda5b5`
**Source type:** `TradingView Pine script`
**Pointer:** `https://www.tradingview.com/script/LhrZrzve-Nova-Reversal-Bands-by-LunqFX/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10251_tv-nova-rev.md`

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
| v1 | 2026-06-09 | Initial build from card | 901d84cf-6c31-4899-8874-b73ee6c41db2 |
