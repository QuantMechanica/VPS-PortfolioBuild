# QM5_10984_ftmo-rsi-macd - Strategy Spec

**EA ID:** QM5_10984
**Slug:** ftmo-rsi-macd
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades H1 RSI extreme recoveries that are confirmed by a MACD signal-line cross. A long setup requires RSI(14) to recover above 30 after an oversold sequence, a bullish MACD(12,26,9) cross on the latest closed candle, and that candle closing above its midpoint. A short setup mirrors the rule above 70 with a bearish MACD cross and a close below midpoint. Exits are the 2R target, the initial structural/ATR stop, an opposite MACD cross, or a 36-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 2-100 | RSI lookback used for oversold and overbought recovery. |
| `strategy_rsi_oversold` | 30.0 | 1-50 | Long recovery threshold. |
| `strategy_rsi_overbought` | 70.0 | 50-99 | Short recovery threshold. |
| `strategy_rsi_sequence_bars` | 3 | 1-20 | Prior closed bars used to define the RSI extreme sequence. |
| `strategy_macd_fast` | 12 | 2-100 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 3-200 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 2-100 | MACD signal period. |
| `strategy_confirm_bars` | 2 | 0-10 | Maximum bars between RSI recovery and MACD confirmation. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for stop and volatility filter. |
| `strategy_sl_atr_buffer` | 0.25 | 0.0-2.0 | ATR buffer beyond the RSI sequence high or low. |
| `strategy_min_sl_atr` | 0.80 | 0.1-5.0 | Minimum stop distance in ATR units. |
| `strategy_max_sl_atr` | 2.50 | 0.5-10.0 | Maximum allowed stop distance in ATR units. |
| `strategy_tp_r_multiple` | 2.0 | 0.5-10.0 | Profit target as R multiple. |
| `strategy_max_hold_bars` | 36 | 1-500 | Time exit after this many H1 bars. |
| `strategy_atr_percentile_bars` | 250 | 20-1000 | Lookback for the ATR percentile filter. |
| `strategy_min_atr_percentile` | 20.0 | 0-100 | Skip entries when current ATR is below this percentile. |
| `strategy_spread_median_bars` | 20 | 2-200 | Lookback for median spread filter. |
| `strategy_spread_median_mult` | 1.5 | 0.1-10.0 | Maximum current spread as a multiple of recent median spread. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair in the card's R3 P2 basket.
- `GBPUSD.DWX` - liquid major FX pair in the card's R3 P2 basket.
- `USDJPY.DWX` - liquid major FX pair in the card's R3 P2 basket.
- `XAUUSD.DWX` - liquid metal symbol in the card's R3 P2 basket.

**Explicitly NOT for:**
- `SP500.DWX` - not part of the card's FX/metals R3 basket.

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
| Trades / year / symbol | `55` |
| Typical hold time | `up to 36 H1 bars` |
| Expected drawdown profile | `moderate fixed-risk drawdown from 2R reversal trades` |
| Regime preference | `momentum-reversal / volatility-normal` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `blog`
**Pointer:** `https://ftmo.com/en/blog/10-steps-to-building-a-trading-strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10984_ftmo-rsi-macd.md`

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
| v1 | 2026-06-06 | Initial build from card | 642e4836-e3be-4102-97fa-3fd35b35c721 |
