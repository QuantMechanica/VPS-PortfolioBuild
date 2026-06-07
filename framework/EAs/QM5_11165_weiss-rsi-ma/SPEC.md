# QM5_11165_weiss-rsi-ma - Strategy Spec

**EA ID:** QM5_11165
**Slug:** weiss-rsi-ma
**Source:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades H1 mean reversion only in the direction of a long moving-average filter. A long entry is opened at the next bar when the last completed close is above SMA(200) and RSI(9) crosses below 25; a short entry is opened when the last completed close is below SMA(200) and RSI(9) crosses above 75. Long positions close when RSI(9) crosses above 50, short positions close when RSI(9) crosses below 50, and both sides also close after 60 H1 bars if no RSI exit or stop has fired. Each trade uses a 1.0% fixed price stop from entry and no fixed take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_timeframe | PERIOD_H1 | H1 expected | Timeframe used for RSI, SMA, and time-exit bars. |
| strategy_rsi_period | 9 | 1+ | RSI lookback period. |
| strategy_sma_period | 200 | 1+ | SMA trend-filter period. |
| strategy_long_rsi | 25.0 | 0-100 | Long entry threshold crossed downward. |
| strategy_short_rsi | 75.0 | 0-100 | Short entry threshold crossed upward. |
| strategy_exit_rsi | 50.0 | 0-100 | RSI midpoint exit threshold. |
| strategy_stop_pct | 1.0 | >0 | Percent price distance for the initial stop. |
| strategy_max_hold_bars | 60 | 1+ | Maximum holding period in strategy timeframe bars. |
| strategy_max_spread_pts | 0 | 0+ | Optional spread cap in points; 0 leaves the cap disabled. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`; only strategy-specific inputs are listed here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair named in the approved card basket.
- EURJPY.DWX - liquid EUR cross named in the approved card basket.
- AUDCAD.DWX - liquid FX cross named in the approved card basket.
- NDX.DWX - liquid Nasdaq 100 index CFD named in the approved card basket.
- SP500.DWX - S&P 500 custom symbol named in the approved card basket; backtest-only per DWX discipline.

**Explicitly NOT for:**
- SPX500.DWX - not present in the DWX symbol matrix; SP500.DWX is the canonical S&P 500 custom symbol.
- SPY.DWX - not present in the DWX symbol matrix.
- ES.DWX - not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Up to 60 H1 bars, with earlier RSI midpoint exits expected. |
| Expected drawdown profile | Moderate mean-reversion drawdowns during persistent one-way moves despite the SMA filter. |
| Regime preference | Trend-filtered mean reversion. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Source type:** book
**Pointer:** Richard L. Weissman, Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis, Wiley, 2005, Chapters 4-5, pp. 77-80 and 95-101; https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11165_weiss-rsi-ma.md`

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
| v1 | 2026-06-07 | Initial build from card | 7bde6536-d1e7-4af2-9087-e86b9e15a78e |
