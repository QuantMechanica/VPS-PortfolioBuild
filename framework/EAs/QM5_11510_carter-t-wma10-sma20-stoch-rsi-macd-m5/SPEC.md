# QM5_11510_carter-t-wma10-sma20-stoch-rsi-macd-m5 - Strategy Spec

**EA ID:** QM5_11510
**Slug:** `carter-t-wma10-sma20-stoch-rsi-macd-m5`
**Source:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf` (see `sources/carter-thomas-20-forex-trend-following-systems`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades on M5 when WMA(10) crosses SMA(20) on the closed bar and the other momentum filters agree. A long entry requires the WMA to cross above the SMA, Stochastic(10,6,6) K above D, RSI(28) above 50, and MACD(24,52,18) histogram above zero. A short entry uses the mirrored conditions. Each trade has a fixed 10-pip stop and a 1:1 reward-to-risk take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wma_period` | 10 | 2-100 | Fast weighted moving average period. |
| `strategy_sma_period` | 20 | 2-200 | Slow simple moving average period. |
| `strategy_stoch_k` | 10 | 2-100 | Stochastic %K period. |
| `strategy_stoch_d` | 6 | 1-50 | Stochastic %D period. |
| `strategy_stoch_slowing` | 6 | 1-50 | Stochastic slowing period. |
| `strategy_rsi_period` | 28 | 2-100 | RSI momentum lookback. |
| `strategy_rsi_level` | 50.0 | 0-100 | RSI long/short dividing line. |
| `strategy_macd_fast` | 24 | 2-100 | MACD fast EMA period. |
| `strategy_macd_slow` | 52 | 3-200 | MACD slow EMA period. |
| `strategy_macd_signal` | 18 | 1-100 | MACD signal period. |
| `strategy_sl_pips` | 10 | 1-15 | Fixed stop-loss distance in pips. |
| `strategy_tp_rr` | 1.0 | 0.1-5.0 | Take-profit reward-to-risk multiple. |
| `strategy_no_friday_entry` | true | true/false | Suppress new entries on Fridays. |
| `strategy_spread_cap_pips` | 10 | 0-50 | Maximum modeled spread in pips before blocking entries. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-approved M5 DWX forex target.
- `GBPUSD.DWX` - card-approved M5 DWX forex target.
- `AUDUSD.DWX` - card-approved M5 DWX forex target.

**Explicitly NOT for:**
- Non-DWX symbols - the Q01/P2 workflow requires DWX tester symbols from `framework/registry/dwx_symbol_matrix.csv`.
- Index and commodity CFDs - the approved card is FX-specific and lists only EURUSD, GBPUSD, and AUDUSD.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `300` |
| Typical hold time | Intraday, usually minutes to hours because the strategy uses M5 signals with fixed SL/TP. |
| Expected drawdown profile | Frequent small fixed-risk wins and losses from 1:1 bracket exits. |
| Regime preference | Trend-following momentum. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf`
**Source type:** book
**Pointer:** `sources/carter-thomas-20-forex-trend-following-systems`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11510_carter-t-wma10-sma20-stoch-rsi-macd-m5.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | a3393cda-9adf-4e19-92a4-882f5c3ce225 |
