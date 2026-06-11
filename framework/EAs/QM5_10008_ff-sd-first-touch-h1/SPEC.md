# QM5_10008_ff-sd-first-touch-h1 - Strategy Spec

**EA ID:** QM5_10008
**Slug:** ff-sd-first-touch-h1
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA scans closed H1 bars for a 2-6 candle base whose total high-low zone height is no more than 1.0 ATR(14). A demand setup requires a prior drop into the base and a three-bar rally at least 1.5 ATR above the zone high with at least two bullish closes; a supply setup requires a prior rally into the base and a three-bar drop at least 1.5 ATR below the zone low with at least two bearish closes. If the zone has not been touched after the impulse, the EA places a buy limit at the demand zone high or a sell limit at the supply zone low. The stop is beyond the opposite side of the zone by 0.15 ATR, the target is 2.0R, pending orders expire after 20 H1 bars, and live positions close after 30 H1 bars if neither SL nor TP has fired.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 14 | 2-100 | ATR period used for zone height, impulse distance, and SL buffer. |
| strategy_min_base_bars | 2 | 1-6 | Minimum number of consecutive H1 candles in the base. |
| strategy_max_base_bars | 6 | 2-12 | Maximum number of consecutive H1 candles in the base. |
| strategy_base_atr_mult | 1.0 | 0.25-3.0 | Maximum base height as a multiple of ATR. |
| strategy_impulse_bars | 3 | 1-6 | Number of H1 candles allowed for impulse departure after the base. |
| strategy_impulse_atr_mult | 1.5 | 0.5-5.0 | Required impulse distance from the zone edge. |
| strategy_min_impulse_closes | 2 | 1-3 | Minimum directional closes inside the impulse window. |
| strategy_stop_atr_buffer_mult | 0.15 | 0.0-1.0 | ATR buffer added beyond the zone for SL placement. |
| strategy_max_zone_atr_mult | 2.0 | 0.5-5.0 | Hard skip threshold for excessive zone height. |
| strategy_reward_risk | 2.0 | 1.0-5.0 | Take-profit multiple of initial risk. |
| strategy_pending_expiry_bars | 20 | 1-100 | H1 bars after which unfilled pending orders are cancelled. |
| strategy_trade_time_stop_bars | 30 | 1-200 | H1 bars after which open trades are closed. |
| strategy_lookback_bars | 72 | 20-300 | Closed H1 bars scanned for fresh zones. |

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
- SP500.DWX - Not part of this ForexFactory FX/metals card.
- NDX.DWX - Not part of this ForexFactory FX/metals card.
- WS30.DWX - Not part of this ForexFactory FX/metals card.

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
| Trades / year / symbol | 40 |
| Expected trade frequency | Fresh H1 supply/demand first-touch zones should be selective; estimate 25-60 trades/year/symbol after impulse/base filters. |
| Typical hold time | Pending orders can wait up to 20 H1 bars; filled trades can hold up to 30 H1 bars. |
| Expected drawdown profile | Stop-first mean-reversion profile with losses bounded beyond the supply/demand zone. |
| Regime preference | price-action mean reversion after strong supply/demand impulse departure |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/452780-price-action-made-simple-with-supply-and-demand
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10008_ff-sd-first-touch-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | 29a07ad6-09fc-4953-8d26-9759b394a467 |
