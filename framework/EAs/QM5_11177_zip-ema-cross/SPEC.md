# QM5_11177_zip-ema-cross - Strategy Spec

**EA ID:** QM5_11177
**Slug:** zip-ema-cross
**Source:** 260fe030-5ad9-5466-91f8-61ef5e23f334
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA runs on closed D1 bars and compares EMA(close, 20) with EMA(close, 40). It opens one long position when EMA20 is above EMA40 and no position is already open for the EA magic. It exits the long position when EMA20 falls below EMA40, or when the emergency 90 D1-bar time stop is reached. The initial safety stop is placed at 2.5 * ATR(20, D1) from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_fast_ema_period | 20 | 1+ and below slow period | Fast EMA period on D1 close. |
| strategy_slow_ema_period | 40 | Greater than fast period | Slow EMA period on D1 close. |
| strategy_atr_period | 20 | 1+ | ATR period used for the safety stop. |
| strategy_atr_sl_mult | 2.5 | > 0 | ATR multiplier for the initial stop loss. |
| strategy_time_stop_bars | 90 | 1+ | Maximum hold time in D1 bars before emergency exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - Card R3 S&P 500 target; available as backtest-only custom symbol.
- NDX.DWX - Card R3 Nasdaq 100 target.
- WS30.DWX - Card R3 Dow 30 target.
- GDAXI.DWX - Canonical DWX DAX symbol used for the card's GER40.DWX target.
- EURUSD.DWX - Card R3 forex target.
- GBPUSD.DWX - Card R3 forex target.
- XAUUSD.DWX - Canonical DWX gold symbol used for the card's XAUUSD target.

**Explicitly NOT for:**
- GER40.DWX - Not present in `dwx_symbol_matrix.csv`; registered as GDAXI.DWX.
- XAUUSD - Missing `.DWX` suffix; registered as XAUUSD.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10 |
| Typical hold time | Multi-day to multi-week; hard capped at 90 D1 bars |
| Expected drawdown profile | Medium-slow trend-following with whipsaw risk in sideways regimes |
| Regime preference | Trend |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 260fe030-5ad9-5466-91f8-61ef5e23f334
**Source type:** archived GitHub repository
**Pointer:** Quantopian Zipline example `dual_ema_talib.py`, https://github.com/quantopian/zipline/blob/master/zipline/examples/dual_ema_talib.py
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11177_zip-ema-cross.md`

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
| v1 | 2026-06-07 | Initial build from card | 3d88039c-0e5b-47dd-a6c9-e11671a7001f |
