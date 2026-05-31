# QM5_10553_mql5-rsioma - Strategy Spec

**EA ID:** QM5_10553
**Slug:** `mql5-rsioma`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA reads an RSIOMA-style oscillator on closed H4 bars and builds a signal line from a short average of that oscillator. It opens a long position when the oscillator crosses upward through its signal line or through the resistance level, and it opens a short position when the oscillator crosses downward through its signal line or through the support level. A long is closed on the opposite bearish oscillator break, and a short is closed on the opposite bullish oscillator break. Every entry also carries the P2 baseline ATR(14) 2.0 hard stop and a 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H1-H6 sweep target | Timeframe used for RSIOMA, signal-line, optional MA filter, and ATR reads. |
| `strategy_rsi_period` | `14` | 2-100 | Period used for the RSIOMA oscillator read. |
| `strategy_signal_period` | `9` | 1-50 | Number of oscillator samples averaged into the signal line. |
| `strategy_support_level` | `30.0` | 0-50 | Support level crossed downward for short entries. |
| `strategy_resistance_level` | `70.0` | 50-100 | Resistance level crossed upward for long entries. |
| `strategy_use_signal_cross` | `true` | true/false | Enables histogram/signal-line cross entries and exits. |
| `strategy_use_level_break` | `true` | true/false | Enables support/resistance level breakout entries. |
| `strategy_atr_period` | `14` | 2-100 | ATR period used for hard stop sizing. |
| `strategy_atr_sl_mult` | `2.0` | 0.1-10 | Stop distance in ATR multiples. |
| `strategy_reward_r_multiple` | `1.5` | 0.1-10 | Profit target multiple of the stop distance. |
| `strategy_ma_filter_enabled` | `false` | true/false | Optional card-authorized MA trend filter switch. |
| `strategy_ma_fast_period` | `50` | 2-300 | Fast EMA period when the optional trend filter is enabled. |
| `strategy_ma_slow_period` | `200` | 3-500 | Slow EMA period when the optional trend filter is enabled. |
| `strategy_max_spread_points` | `0` | 0-10000 | Optional spread ceiling in points; 0 disables the filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Liquid FX major from the card's R3 portable basket.
- `GBPUSD.DWX` - Liquid FX major from the card's R3 portable basket.
- `USDJPY.DWX` - Liquid FX major from the card's R3 portable basket.
- `XAUUSD.DWX` - Liquid metal CFD from the card's R3 portable basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build registry only admits verified `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | hours to several days |
| Expected drawdown profile | Medium oscillator-breakout drawdown profile from repeated histogram reversals. |
| Regime preference | oscillator breakout / histogram reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/17054`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10553_mql5-rsioma.md`

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
| v1 | 2026-05-29 | Initial build from card | 4d2776da-2fba-4cec-986b-c1d67141b86f |
