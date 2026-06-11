# QM5_9700_ff-roadmap-channel-m15 - Strategy Spec

**EA ID:** QM5_9700
**Slug:** ff-roadmap-channel-m15
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see ForexFactory Roadmap source)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades completed M15 bar closes that break out of a Roadmap EMA channel built from EMA(34, high), EMA(34, close), and EMA(34, low). A long trade requires the channel midline to be rising over eight bars, the last close to cross above the upper channel after at least three prior closes were not above it, RSI(14) to be above 52 and rising, and price to be above EMA(200). Shorts mirror the same logic below the lower channel with RSI below 48 and price below EMA(200). Positions exit at 1.7R, on a close back inside the EMA channel, on a 20 M15-bar time stop, or through the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_channel_ema_period | 34 | 2+ | EMA period for the high, close, and low Roadmap channel. |
| strategy_trend_ema_period | 200 | 2+ | Trend filter EMA period on M15 close. |
| strategy_slope_lookback_bars | 8 | 1+ | Number of closed M15 bars used to test channel midline slope. |
| strategy_prior_inside_bars | 3 | 1+ | Required prior closes inside or on the correct side of the channel before breakout. |
| strategy_rsi_period | 14 | 2+ | RSI lookback period on M15 close. |
| strategy_rsi_long_threshold | 52.0 | 0-100 | Minimum RSI value for long entries. |
| strategy_rsi_short_threshold | 48.0 | 0-100 | Maximum RSI value for short entries. |
| strategy_atr_period | 14 | 1+ | ATR period used for channel-width filter and SL buffer. |
| strategy_min_channel_width_atr | 0.35 | 0+ | Minimum channel width as a multiple of ATR(14). |
| strategy_sl_atr_buffer | 0.25 | 0+ | ATR buffer beyond the opposite channel boundary for SL. |
| strategy_tp_r_multiple | 1.70 | 0+ | Take-profit distance as R multiple from entry to SL. |
| strategy_time_stop_bars | 20 | 0+ | Maximum holding time in M15 bars; 0 disables. |
| strategy_late_friday_cutoff_hour | 16 | 0-23 | Broker-hour cutoff for new Friday entries. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - major FX pair directly listed in the card's R3 P2 basket.
- GBPUSD.DWX - major FX pair directly listed in the card's R3 P2 basket.
- USDJPY.DWX - major FX pair directly listed in the card's R3 P2 basket.
- XAUUSD.DWX - liquid metal symbol directly listed in the card's R3 P2 basket.

**Explicitly NOT for:**
- Non-DWX symbols - pipeline and registry require canonical `.DWX` symbols.
- Symbols outside the card's R3 basket - not part of this approved build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 75 |
| Typical hold time | Up to 20 M15 bars, about 5 hours, unless TP/SL or channel reentry exits first. |
| Expected drawdown profile | Intraday channel-breakout system with fixed $1,000 backtest risk per trade. |
| Regime preference | Intraday momentum and volatility expansion through EMA channel breakouts. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/993524-roadmap-a-way-to-read-markets
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9700_ff-roadmap-channel-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | efb3ce9b-a389-422e-bbd4-0aa55f6c8ab0 |
