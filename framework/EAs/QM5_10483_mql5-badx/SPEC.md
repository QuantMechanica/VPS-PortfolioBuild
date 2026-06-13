# QM5_10483_mql5-badx - Strategy Spec

**EA ID:** QM5_10483
**Slug:** `mql5-badx`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA evaluates once per new M30 bar. A long entry requires ADX above the configured threshold, +DI above -DI, and the last closed candle either at or above the Bollinger middle band or rebounding upward from below the lower band. A short entry requires ADX above the threshold, -DI above +DI, and the last closed candle either at or below the Bollinger middle band or rejecting downward from above the upper band. Open positions close on the opposite ADX/Bollinger signal, at a 1.5 ATR protective stop, at a 2.0R take-profit, or after 48 M30 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_adx_period` | 30 | >=2 | ADX and DI averaging period. |
| `strategy_adx_threshold` | 20.0 | >0 | Minimum ADX value required for entry and opposite-signal exit. |
| `strategy_bb_period` | 10 | >=2 | Bollinger Bands period. |
| `strategy_bb_deviation` | 1.5 | >0 | Bollinger Bands standard-deviation multiplier. |
| `strategy_atr_period` | 14 | >=1 | ATR period for protective stop placement. |
| `strategy_atr_sl_mult` | 1.5 | >0 | ATR multiple used for stop loss distance. |
| `strategy_rr_target` | 2.0 | >0 | Take-profit multiple of initial risk. |
| `strategy_time_stop_bars` | 48 | >=0 | Maximum holding period in chart bars; 0 disables the time stop. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card primary example and DWX-available major forex pair.
- `GBPUSD.DWX` - card R3 portable major forex pair.
- `USDJPY.DWX` - card R3 portable major forex pair.
- `XAUUSD.DWX` - card R3 portable liquid metal symbol.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts must retain the `.DWX` suffix.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol evidence is available for this build.

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
| Trades / year / symbol | `80` |
| Typical hold time | Up to 48 M30 bars if no opposite signal or SL/TP fires. |
| Expected drawdown profile | Bounded by fixed-risk sizing and ATR stop distance. |
| Regime preference | ADX trend filter with Bollinger continuation/rebound conditions. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/23029 and `artifacts/cards_approved/QM5_10483_mql5-badx.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10483_mql5-badx.md`

Implementation note for review: the downloaded `BADX.mq5` source uses `ADX < level` with ask below lower band / bid above upper band, while the approved card specifies `ADX > level`, DI direction, and middle/rebound logic. This build follows the approved card literally.

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
| v1 | 2026-06-13 | Initial build from card | ba0b0257-d4a4-4065-b7ac-1eae6967aa21 |
