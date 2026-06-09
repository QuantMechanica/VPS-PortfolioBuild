# QM5_10118_tv-rsi-trend-cont - Strategy Spec

**EA ID:** QM5_10118
**Slug:** `tv-rsi-trend-cont`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades long-only trend continuation on the chart timeframe. It opens a long position when the last closed candle has RSI(14) above 50, MACD(12,26,9) main above signal, Stochastic %K and %D at or below 80, and the candle low above EMA(200). The initial stop is entry minus 1.75 * ATR(14). Once the last closed candle reaches entry plus 2.25 * ATR(14), trailing mode is marked active and the EA closes the long when the last closed candle closes below EMA(20).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 1+ | RSI lookback for the momentum filter. |
| `strategy_rsi_min` | 50.0 | 0-100 | Minimum RSI value required for long entry. |
| `strategy_macd_fast` | 12 | 1+ | Fast EMA period for MACD. |
| `strategy_macd_slow` | 26 | 1+ | Slow EMA period for MACD. |
| `strategy_macd_signal` | 9 | 1+ | Signal EMA period for MACD. |
| `strategy_stoch_k_period` | 14 | 1+ | Stochastic %K period. |
| `strategy_stoch_d_period` | 3 | 1+ | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | 1+ | Stochastic slowing period. |
| `strategy_stoch_max` | 80.0 | 0-100 | Maximum %K and %D value allowed at entry. |
| `strategy_ema_trend_period` | 200 | 1+ | EMA trend filter period. |
| `strategy_ema_exit_period` | 20 | 1+ | EMA trailing-exit period after profit activation. |
| `strategy_atr_period` | 14 | 1+ | ATR period for stop and profit activation. |
| `strategy_atr_sl_mult` | 1.75 | 0+ | ATR multiplier for initial long stop distance. |
| `strategy_profit_atr_mult` | 2.25 | 0+ | ATR multiple above entry required to activate trailing mode. |
| `strategy_max_spread_frac` | 0.10 | 0+ | Blocks entries when spread exceeds this fraction of ATR stop distance. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-approved liquid FX target for RSI/MACD trend continuation.
- `GBPUSD.DWX` - card-approved liquid FX target for RSI/MACD trend continuation.
- `XAUUSD.DWX` - card-approved gold CFD target for momentum trend continuation.
- `NDX.DWX` - card-approved liquid index CFD target for momentum trend continuation.

**Explicitly NOT for:**
- Symbols not registered for QM5_10118 in `magic_numbers.csv` - no implicit universe expansion at runtime.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H2` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | Variable H2 trend-continuation hold, until SL, Friday close, or EMA20 trailing exit after 2.25 ATR activation. |
| Expected drawdown profile | Fixed $1,000 backtest risk per trade, long-only trend-following drawdowns during non-trending regimes. |
| Regime preference | Trend continuation with positive momentum confirmation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView public script`
**Pointer:** `https://in.tradingview.com/script/mwyj1IWU-RSI-Trend-Following-Strategy/`
**R1-R4 verdict (Q00):** all PASS - see `artifacts/cards_approved/QM5_10118_tv-rsi-trend-cont.md`

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
| v1 | 2026-06-09 | Initial build from card | 842e3a72-f99a-44ff-816c-84d0062c4000 |
