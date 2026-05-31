# QM5_10522_mql5-billy - Strategy Spec

**EA ID:** QM5_10522
**Slug:** `mql5-billy`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

This EA trades long only on the close of M15 bars. It opens a buy trade when the last three closed bars are all bearish and the Stochastic main line is above the signal line on both configured confirmation timeframes. The baseline exit is a hard stop at 1.5 x ATR(14), a take profit at 1.25R, plus the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_stoch_k_period` | 5 | 1+ | Stochastic K period used on both confirmation timeframes. |
| `strategy_stoch_d_period` | 3 | 1+ | Stochastic D period used on both confirmation timeframes. |
| `strategy_stoch_slowing` | 3 | 1+ | Stochastic slowing value used on both confirmation timeframes. |
| `strategy_stoch_tf_1` | `PERIOD_M30` | MT5 timeframe enum | First Stochastic confirmation timeframe. |
| `strategy_stoch_tf_2` | `PERIOD_H1` | MT5 timeframe enum | Second Stochastic confirmation timeframe. |
| `strategy_atr_period` | 14 | 1+ | ATR period for stop distance. |
| `strategy_atr_sl_mult` | 1.5 | >0 | Stop-loss distance as a multiple of ATR. |
| `strategy_tp_r_multiple` | 1.25 | >0 | Take-profit distance as a multiple of initial risk. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - cited source test symbol and present in the R3 portable FX basket.
- `GBPUSD.DWX` - cited source test symbol and present in the R3 portable FX basket.
- `USDJPY.DWX` - cited source test symbol and present in the R3 portable FX basket.
- `XAUUSD.DWX` - R3 portable DWX symbol for broad liquid metal exposure.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no validated DWX backtest data.
- `SPY.DWX`, `SPX500.DWX`, `ES.DWX` - unavailable/non-canonical S&P variants.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | Stochastic confirmations default to `M30` and `H1` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Intraday M15 pullback trades; optional 5-bar time stop is P3 only, not baseline. |
| Expected drawdown profile | Fixed-risk mean-reversion pullback profile with no pyramiding or averaging. |
| Regime preference | Mean-reversion pullback with multi-timeframe bullish confirmation. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/19467`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10522_mql5-billy.md`

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
| v1 | 2026-05-29 | Initial build from card | b125bdee-9f67-49c9-9788-e74ef6e07fb9 |
