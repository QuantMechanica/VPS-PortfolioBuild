# QM5_10196_tv-dual-st-macd - Strategy Spec

**EA ID:** QM5_10196
**Slug:** `tv-dual-st-macd`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA evaluates closed H4 bars. It calculates two Supertrend states, one using ATR(10) with factor 3.0 and one using ATR(20) with factor 5.0. It enters long when both Supertrends are bullish and the MACD(12,26,9) histogram is above zero; it enters short when both Supertrends are bearish and the histogram is below zero. Open positions exit when the cached closed-bar signal no longer supports the position direction, with a protective 2.0 x ATR(14) stop at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_st1_atr_period` | 10 | 2-100 | ATR period for the first Supertrend engine. |
| `strategy_st1_factor` | 3.0 | 0.1-20.0 | ATR multiplier for the first Supertrend engine. |
| `strategy_st2_atr_period` | 20 | 2-100 | ATR period for the second Supertrend engine. |
| `strategy_st2_factor` | 5.0 | 0.1-20.0 | ATR multiplier for the second Supertrend engine. |
| `strategy_macd_fast` | 12 | 2-100 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 3-200 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 2-100 | MACD signal EMA period. |
| `strategy_stop_atr_period` | 14 | 2-100 | ATR period for the protective stop. |
| `strategy_stop_atr_mult` | 2.0 | 0.1-20.0 | ATR multiplier for the protective stop. |
| `strategy_supertrend_bars` | 220 | 50-1000 | Closed-bar warmup depth for the Supertrend state. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-stated FX port for OHLC-derived trend and momentum logic.
- `GBPUSD.DWX` - card-stated FX port for the same liquid major-FX behavior.
- `XAUUSD.DWX` - card-stated gold CFD port for trend-following and momentum behavior.
- `GDAXI.DWX` - canonical DWX matrix name for the card's DAX target.
- `NDX.DWX` - card-stated large-cap index CFD port.

**Explicitly NOT for:**
- Any symbol absent from `framework/registry/dwx_symbol_matrix.csv` - no phantom DWX symbols are registered.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | multi-bar H4 trend holds |
| Expected drawdown profile | bounded per trade by the V5 fixed-risk backtest model and ATR stop |
| Regime preference | trend-following / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView public script page
**Pointer:** `https://www.tradingview.com/script/zFKRj4Gi-Dual-Supertrend-with-MACD-Strategy-presentTrading/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10196_tv-dual-st-macd.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-09 | Initial build from card | 708a8b44-d79a-4495-a296-32f5bfa84859 |
