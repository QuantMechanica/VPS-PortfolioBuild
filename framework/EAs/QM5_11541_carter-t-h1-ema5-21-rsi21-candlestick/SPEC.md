# QM5_11541_carter-t-h1-ema5-21-rsi21-candlestick - Strategy Spec

**EA ID:** QM5_11541
**Slug:** carter-t-h1-ema5-21-rsi21-candlestick
**Source:** 3001a121-97a0-5db0-b6ff-69b89a0fc07d (see `sources/carter-thomas-20-forex-strategies-1h`)
**Author of this spec:** Codex
**Last revised:** 2026-06-24

---

## 1. Strategy Logic

The EA trades H1 EMA(5) and EMA(21) crosses confirmed by RSI(21) and a candlestick pattern. A long entry is allowed when EMA(5) crossed above EMA(21) within the last three closed bars, RSI(21) is above 50, and the last closed bar is either a bullish engulfing bar or a hammer. A short entry is the mirror: EMA(5) crossed below EMA(21) within the last three closed bars, RSI(21) is below 50, and the last closed bar is either a bearish engulfing bar or an inverted hammer. The stop is the recent 5-bar swing low or swing high capped at 40 pips, the target is 2R, and discretionary exit occurs when EMA(5) crosses back through EMA(21) against the trade or RSI returns through 50.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 5 | 2-50 | Fast EMA period used for entry and exit crosses. |
| `strategy_ema_slow_period` | 21 | 5-200 | Slow EMA period used for entry and exit crosses. |
| `strategy_rsi_period` | 21 | 2-100 | RSI lookback period. |
| `strategy_rsi_mid` | 50.0 | 1.0-99.0 | RSI midline used for long/short confirmation and exit. |
| `strategy_sl_lookback` | 5 | 1-50 | Closed-bar swing window for the structure stop. |
| `strategy_sl_cap_pips` | 40.0 | 1.0-500.0 | Maximum stop distance in pips. |
| `strategy_tp_rr` | 2.0 | 0.1-10.0 | Take-profit multiple of stop distance. |
| `strategy_hammer_body_pips` | 3.0 | 0.1-100.0 | Minimum hammer or inverted-hammer body size in pips. |
| `strategy_cross_lookback` | 3 | 1-10 | Number of closed bars in which the EMA cross may have occurred. |
| `strategy_block_friday` | true | true/false | Blocks new entries on Friday. |
| `strategy_spread_cap_pips` | 15.0 | 0.0-100.0 | Blocks only genuinely wide positive spread; zero modeled spread passes. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - listed directly in the card R3 data-availability statement and present in the DWX matrix.
- `GBPUSD.DWX` - listed directly in the card R3 data-availability statement and present in the DWX matrix.

**Explicitly NOT for:**
- Non-FX `.DWX` indices, commodities, and energies - the source strategy is an H1 forex system and the approved card only names EURUSD and GBPUSD.

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
| Trades / year / symbol | 50 |
| Typical hold time | H1 swing trades; hours to a few days |
| Expected drawdown profile | Moderate trend-following drawdown with fixed 2R target and 40-pip capped structure stop. |
| Regime preference | trend continuation with candlestick confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3001a121-97a0-5db0-b6ff-69b89a0fc07d
**Source type:** book
**Pointer:** `sources/carter-thomas-20-forex-strategies-1h`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11541_carter-t-h1-ema5-21-rsi21-candlestick.md`

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
| v1 | 2026-06-24 | Initial build from card | 42b5447b-9cb0-443f-936b-5e448c71b7f6 |
