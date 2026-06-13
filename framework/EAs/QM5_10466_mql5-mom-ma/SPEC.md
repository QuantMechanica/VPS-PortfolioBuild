# QM5_10466_mql5-mom-ma - Strategy Spec

**EA ID:** QM5_10466
**Slug:** mql5-mom-ma
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see MQL5 CodeBase page)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades a Momentum line against a moving-average-smoothed Momentum line on the H1 baseline. It opens long when Momentum crosses above its smoothed line while both lines are below 100, and opens short when Momentum crosses below its smoothed line while both lines are above 100. Entries are market orders on the next framework-gated bar. Exits use a 1.5 x ATR(14) stop, a 2R take profit, framework Friday close, and early close on the opposite qualifying Momentum/MA cross.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_signal_tf | PERIOD_H1 | MT5 timeframe enum | Timeframe used for Momentum and smoothed Momentum signals. |
| strategy_momentum_period | 14 | 1-200 | Period for the Momentum indicator. |
| strategy_momentum_ma_period | 14 | 1-200 | Simple moving average length applied to Momentum values. |
| strategy_signal_level | 100.0 | 0.0-200.0 | Level filter for qualifying crosses. |
| strategy_atr_period | 14 | 1-200 | ATR period for stop placement. |
| strategy_atr_sl_mult | 1.50 | 0.1-10.0 | Stop distance as a multiple of ATR. |
| strategy_tp_r_mult | 2.00 | 0.1-10.0 | Take-profit distance in units of initial risk. |
| strategy_max_spread_points | 250.0 | 0.0-disabled, positive points | Maximum allowed spread before the strategy no-trade filter blocks entry. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card target symbol; liquid forex pair with OHLC history for Momentum and ATR.
- GBPUSD.DWX - Card target symbol; liquid forex pair with OHLC history for Momentum and ATR.
- XAUUSD.DWX - Card target symbol; liquid metal CFD with OHLC history for Momentum and ATR.

**Explicitly NOT for:**
- Non-DWX symbols - V5 build and backtest artifacts require canonical `.DWX` symbols.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - broker/custom-symbol data is not available for Q01/P2 registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Expected trade frequency | conservative H1 Momentum/MA crosses |
| Typical hold time | not specified in card |
| Expected drawdown profile | fixed-risk ATR stop with no trailing; drawdown depends on cross frequency and 2R target realization |
| Regime preference | momentum with mean-reversion level filter around Momentum 100 |
| Win rate target (qualitative) | not specified in card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/39175 and approved card `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10466_mql5-mom-ma.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10466_mql5-mom-ma.md`

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
| v1 | 2026-06-13 | Initial build from card | 371fc6da-97fe-4fc6-8b97-fa0bc67ba83c |
