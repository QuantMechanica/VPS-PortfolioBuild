# QM5_10753_tv-three-musk - Strategy Spec

**EA ID:** QM5_10753
**Slug:** `tv-three-musk`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades the last closed M15 bar when at least two of three conditions agree. A long signal needs EMA(50) above EMA(200), RSI(14) crossing above 30, or price crossing back above the lower Bollinger Band; a short signal mirrors those rules with EMA(50) below EMA(200), RSI crossing below 70, or price crossing back below the upper Bollinger Band. Each entry uses an ATR(14) x 1.5 hard stop and a fixed 2R take-profit. Open positions are closed early on an opposite two-of-three signal or after 48 M15 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M15` | `PERIOD_M15` | Card execution timeframe. |
| `strategy_fast_ema_period` | 50 | 1-199 | Fast trend EMA. |
| `strategy_slow_ema_period` | 200 | > fast EMA | Slow trend EMA. |
| `strategy_rsi_period` | 14 | >= 1 | RSI lookback. |
| `strategy_rsi_lower` | 30.0 | > 0 | Bullish RSI cross threshold. |
| `strategy_rsi_upper` | 70.0 | > lower threshold | Bearish RSI cross threshold. |
| `strategy_bb_period` | 20 | >= 1 | Bollinger Band lookback. |
| `strategy_bb_deviation` | 2.0 | > 0 | Bollinger Band standard-deviation multiplier. |
| `strategy_atr_period` | 14 | >= 1 | ATR stop lookback. |
| `strategy_atr_sl_mult` | 1.5 | > 0 | Initial stop multiplier. |
| `strategy_take_profit_rr` | 2.0 | > 0 | Fixed reward-to-risk take-profit. |
| `strategy_max_hold_bars` | 48 | >= 1 | M15 bars before time-stop close. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with full DWX coverage and liquid M15 data.
- `GBPUSD.DWX` - FX major with full DWX coverage and liquid M15 data.
- `XAUUSD.DWX` - DWX metal symbol named by the card's portable basket.
- `NDX.DWX` - US large-cap index CFD named by the card.
- `WS30.DWX` - US large-cap index CFD named by the card's R3 P2 basket.

**Explicitly NOT for:**
- Non-DWX symbols - the build and pipeline require canonical DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | `up to 48 M15 bars` |
| Expected drawdown profile | `Broad confluence baseline; drawdown depends on whipsaw frequency around the EMA and Bollinger triggers.` |
| Regime preference | `mean-reversion with trend confirmation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView script`
**Pointer:** `https://www.tradingview.com/script/QTxR4wWi-Scott-Barclay-s-Three-Musksteers/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10753_tv-three-musk.md`

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
| v1 | 2026-05-31 | Initial build from card | 7354acc0-916e-4306-aefc-d47fb9910258 |
