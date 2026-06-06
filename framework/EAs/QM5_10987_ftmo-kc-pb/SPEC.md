# QM5_10987_ftmo-kc-pb - Strategy Spec

**EA ID:** QM5_10987
**Slug:** `ftmo-kc-pb`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA builds a Keltner Channel on H1 with EMA(20) as the middle line and ATR(20) bands at 2.0 ATR. A long setup starts when a closed H1 candle closes above the upper band; within the next 8 H1 bars price must touch the EMA middle line without closing below the lower band, then the first bullish close back above the EMA opens long. Shorts mirror this: a close below the lower band, an EMA pullback without closing above the upper band, then a bearish close back below the EMA. Stops use the opposite Keltner stop band at entry, target uses the far band unless it is closer than 1.2R, in which case the target is 2.0R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_keltner_period` | 20 | 1-200 | EMA and ATR period for the Keltner Channel. |
| `strategy_keltner_atr_mult` | 2.0 | 0.1-10.0 | ATR multiple used to build the upper and lower bands. |
| `strategy_pullback_window_bars` | 8 | 1-48 | Maximum H1 bars allowed after breakout to complete the EMA pullback. |
| `strategy_min_band_tp_rr` | 1.2 | 0.1-10.0 | Minimum reward-to-risk distance required for the band target. |
| `strategy_tp_rr_fallback` | 2.0 | 0.1-10.0 | Fixed R multiple used when the band target is too close. |
| `strategy_max_entry_risk_atr` | 2.5 | 0.1-10.0 | Maximum allowed entry risk measured in ATR(20,H1). |
| `strategy_be_trigger_r` | 1.0 | 0.1-10.0 | Favorable R move required before moving SL to breakeven. |
| `strategy_trail_trigger_r` | 1.5 | 0.1-10.0 | Favorable R move required before two-bar swing trailing starts. |
| `strategy_max_hold_bars` | 48 | 1-240 | Maximum H1 bars to hold before a time exit. |
| `strategy_spread_median_mult` | 1.5 | 0.1-10.0 | Blocks new trading when current spread exceeds this multiple of 20-bar median spread. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair named by the approved card.
- `GBPUSD.DWX` - liquid major FX pair named by the approved card.
- `XAUUSD.DWX` - liquid gold/metal CFD named by the approved card.
- `NDX.DWX` - liquid Nasdaq 100 index CFD named by the approved card.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not valid DarwinexZero backtest symbols.
- Symbols not registered for `QM5_10987` in `magic_numbers.csv` - no active magic slot exists for this EA.

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
| Trades / year / symbol | `50` |
| Typical hold time | Intraday to 48 H1 bars, with breakeven after 1.0R and swing trailing after 1.5R. |
| Expected drawdown profile | Trend-following pullback losses bounded by Keltner-band stops and fixed risk sizing. |
| Regime preference | Breakout / trend-following pullback after volatility expansion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `blog / academy article`
**Pointer:** `https://academy.ftmo.com/lesson/keltner-channels-technical-indicator/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10987_ftmo-kc-pb.md`

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
| v1 | 2026-06-06 | Initial build from card | 6a718d6b-2142-4368-a2a6-f740c0318a55 |
