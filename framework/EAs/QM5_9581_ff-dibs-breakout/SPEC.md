# QM5_9581_ff-dibs-breakout - Strategy Spec

**EA ID:** QM5_9581
**Slug:** ff-dibs-breakout
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA builds a 0000 GMT reference close from H1 bars and trades only from 0600 GMT until the 1600 GMT cancellation time. On each closed H1 bar, it looks for an inside bar where the last closed high is below the prior high and the last closed low is above the prior low. If current price is above the midnight close, it places a buy stop at the inside-bar high plus 0.1 ATR(14); if current price is below the midnight close, it places a sell stop at the inside-bar low minus 0.1 ATR(14). The stop is on the opposite side of the inside bar with the same ATR buffer, the target is 2.0R, unfilled orders expire at 1600 GMT, and open positions close after 10 H1 bars or on an opposite valid DIBS breakout.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 14 | 2-100 | H1 ATR period used for entry buffer and inside-bar range filter. |
| strategy_entry_atr_fraction | 0.10 | 0.01-1.00 | ATR fraction added beyond the inside-bar high/low for stop-order entry and SL buffer. |
| strategy_min_inside_atr | 0.15 | 0.00-2.00 | Minimum inside-bar range as a multiple of ATR. |
| strategy_max_inside_atr | 1.25 | 0.10-5.00 | Maximum inside-bar range as a multiple of ATR. |
| strategy_take_rr | 2.0 | 0.5-10.0 | Take-profit reward/risk multiple. |
| strategy_start_gmt_hour | 6 | 0-23 | First UTC hour where DIBS entries are allowed. |
| strategy_cancel_gmt_hour | 16 | 1-24 | UTC hour where unfilled pending orders are cancelled or expire. |
| strategy_time_stop_bars | 10 | 1-200 | Maximum H1 bars to hold a filled position before strategy close. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Major FX pair named in the approved card R3 basket.
- GBPUSD.DWX - Major FX pair named in the approved card R3 basket.
- USDJPY.DWX - Major FX pair named in the approved card R3 basket.
- XAUUSD.DWX - Gold symbol named in the approved card R3 basket.

**Explicitly NOT for:**
- SP500.DWX - The card explicitly states no SP500.DWX dependency.
- NDX.DWX - Not part of the approved FX/metals R3 basket.
- WS30.DWX - Not part of the approved FX/metals R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Expected trade frequency | Medium; post-0600 GMT inside-bar breakouts filtered by midnight-close bias should generate roughly 40-90 trades/year/symbol. |
| Typical hold time | Up to 10 H1 bars after fill unless SL, TP, Friday close, or opposite breakout exits first. |
| Expected drawdown profile | Stop-first breakout profile with fixed 2.0R target and one position per magic-symbol. |
| Regime preference | H1 volatility expansion / breakout after same-session inside-bar compression. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/86766-the-dibs-method-no-free-lunch-continues
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_9581_ff-dibs-breakout.md`

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
| v1 | 2026-06-25 | Initial build from card | 8354c2c0-d48c-41eb-84c2-bc434c541e7c |
