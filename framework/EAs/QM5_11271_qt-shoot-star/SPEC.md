# QM5_11271_qt-shoot-star - Strategy Spec

**EA ID:** QM5_11271
**Slug:** qt-shoot-star
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA looks for a completed bearish shooting-star candle after a short uptrend, then waits for the next completed candle to confirm that price did not trade above the shooting-star high and did not close above the shooting-star close. The shooting-star candle must have a red body, a small lower wick, a body smaller than the recent average body, and an upper wick at least twice the body. When all conditions are true, the EA enters short with a 5 percent stop, a 5 percent take profit, and a 7-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_lower_wick_bound | 0.20 | 0.10-0.30 tested | Maximum lower wick as a multiple of the real body. |
| strategy_body_size_mult | 0.50 | 0.40-0.70 tested | Maximum shooting-star body relative to the mean recent body. |
| strategy_body_mean_lookback | 20 | >=1 | Number of prior bars used for the mean real-body size. |
| strategy_uptrend_lookback | 2 | 2-5 tested | Number of rising closes required into the shooting-star candle. |
| strategy_exit_pct | 0.05 | >0 | Source stop and profit threshold as a fraction of entry price. |
| strategy_holding_bars | 7 | 5-10 tested | Maximum bars to hold before a strategy time-stop exit. |
| strategy_atr_period | 14 | >=1 | ATR period used for the gap filter and optional ATR threshold. |
| strategy_gap_atr_mult | 0.75 | >=0 | Maximum confirmation open gap from the pattern close, in ATR units. |
| strategy_use_atr_threshold | false | true/false | Uses ATR stop/profit distance instead of source percentage threshold when true. |
| strategy_atr_exit_mult | 2.0 | 1.5-2.5 tested | ATR multiple for optional ATR stop/profit threshold. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed liquid FX major with portable OHLC candle data.
- GBPUSD.DWX - Card-listed liquid FX major with portable OHLC candle data.
- XAUUSD.DWX - Card-listed metal CFD with portable OHLC candle data.
- NDX.DWX - Card-listed liquid equity index CFD with portable OHLC candle data.
- GDAXI.DWX - DAX proxy used because card-listed GER40.DWX is not present in the DWX symbol matrix.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 15 |
| Typical hold time | Up to 7 bars |
| Expected drawdown profile | Medium; single-candle reversal entries can be noisy despite confirmation. |
| Regime preference | Short-bias candlestick reversal after a short uptrend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository script
**Pointer:** https://github.com/je-suis-tm/quant-trading/blob/master/Shooting%20Star%20backtest.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11271_qt-shoot-star.md`

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
| v1 | 2026-06-08 | Initial build from card | 3ce595c3-e3dd-47c0-a6b7-3dbef37d1c5b |
