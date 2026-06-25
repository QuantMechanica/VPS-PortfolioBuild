# QM5_11377_vegas-wave-ema144-169-fractal-h1 - Strategy Spec

**EA ID:** QM5_11377
**Slug:** `vegas-wave-ema144-169-fractal-h1`
**Source:** `c2622cef-77e4-5653-b39e-8ae8f69221d3` (see `strategy-seeds/sources/c2622cef-77e4-5653-b39e-8ae8f69221d3/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades the Vegas Wave H1 tunnel formed by EMA(144) and EMA(169). A long setup is active when the last closed H1 candle closes above EMA(169), then a newly confirmed down Williams fractal places a buy stop one pip plus current positive spread above the fractal bar high. A short setup is active when the last closed candle closes below EMA(144), then a newly confirmed up Williams fractal places a sell stop one pip below the fractal bar low. Pending stops expire after 4 H1 candles. The stop is fixed at the opposite EMA boundary at order placement and capped to 30 pips; half the position is closed at ATR(14) x 3, the remainder targets ATR(14) x 5 and moves to break-even after TP1 is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 144 | 100-200 | Vegas tunnel fast EMA and short-side stop boundary |
| `strategy_ema_slow_period` | 169 | 120-220 | Vegas tunnel slow EMA and long-side stop boundary |
| `strategy_fractal_side_bars` | 2 | 2-3 | Bars required on each side of the Williams fractal pivot |
| `strategy_atr_period` | 14 | 7-21 | ATR period for TP1, TP2, and break-even trigger |
| `strategy_tp1_atr_mult` | 3.0 | 2.0-4.0 | First target distance; closes 50% and triggers break-even |
| `strategy_tp2_atr_mult` | 5.0 | 4.0-6.0 | Final target distance for the remaining position |
| `strategy_entry_buffer_pips` | 1.0 | 1-3 | Stop-order offset beyond the fractal extreme, in pips |
| `strategy_sl_max_pips` | 30.0 | 15-50 | Maximum EMA-boundary stop distance, in pips |
| `strategy_pending_bars` | 4 | 1-8 | Pending stop expiry in H1 candles |
| `strategy_session_start_hr` | 8 | 0-23 | Broker-hour session start, inclusive |
| `strategy_session_end_hr` | 19 | 0-23 | Broker-hour session end, exclusive |
| `strategy_spread_cap_pips` | 20.0 | 5-40 | Blocks only genuinely wide positive spread; zero modeled spread passes |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary FX major listed in the card R3 PASS basket.
- `GBPUSD.DWX` - primary FX major listed in the card R3 PASS basket.
- `USDJPY.DWX` - secondary FX major listed in the card R3 PASS basket.
- `GBPJPY.DWX` - secondary FX cross listed in the card R3 PASS basket.

**Explicitly NOT for:**
- Index and commodity `.DWX` symbols - the card declares an H1 FX basket and pip-scaled Vegas tunnel parameters.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `moderate; EMA-boundary stops are capped at 30 pips` |
| Regime preference | `breakout / trend-following` |
| Win rate target (qualitative) | `low-medium with ATR runner payoff` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c2622cef-77e4-5653-b39e-8ae8f69221d3`
**Source type:** `forum / local PDF archive`
**Pointer:** `Anonymous (Vegas), Forex Strategy Vegas Wave, local PDF; card path D:\QM\strategy_farm\artifacts\cards_approved\QM5_11377_vegas-wave-ema144-169-fractal-h1.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11377_vegas-wave-ema144-169-fractal-h1.md`

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
| v1 | 2026-06-26 | Initial build from card | 0cf48e2f-3822-4697-99e0-78328cdcf72e |
