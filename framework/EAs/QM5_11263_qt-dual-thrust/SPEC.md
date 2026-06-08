# QM5_11263_qt-dual-thrust - Strategy Spec

**EA ID:** QM5_11263
**Slug:** qt-dual-thrust
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

At each source session open, the EA computes the Dual Thrust range from the prior five completed source sessions: range1 is the rolling high minus the minimum close, range2 is the maximum close minus the rolling low, and the active range is the larger of the two. The long threshold is session open plus 0.50 times that range; the short threshold is session open minus 0.50 times that range. The EA enters long when price exceeds the upper threshold, enters short when price falls below the lower threshold, closes and reverses when the opposite threshold is crossed, and force-closes any open position at the source session close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_range_sessions | 5 | 3-10 | Number of completed source sessions used for the rolling Dual Thrust range. |
| strategy_threshold_param | 0.50 | 0.35-0.65 | Threshold split used in upper and lower breakout formulas. |
| strategy_source_open_hhmm_est | 300 | 0000-2359 | Fixed EST source-session open used to set the daily thresholds. |
| strategy_source_close_hhmm_est | 1200 | 0000-2359 | Fixed EST source-session close used for force-flat exits. |
| strategy_atr_period | 14 | 14 | ATR period for the catastrophic M30 stop. |
| strategy_atr_sl_mult | 1.50 | 1.0-2.0 | ATR multiplier for the catastrophic stop. |
| strategy_spread_max_frac | 0.10 | 0.0-0.25 | Maximum current spread as a fraction of the upper-lower threshold distance. |

Framework-level inputs are documented in framework/V5_FRAMEWORK_DESIGN.md and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- GBPUSD.DWX - Card R3 primary FX symbol with liquid M1 DWX data for intraday breakouts.
- EURUSD.DWX - Card R3 FX symbol with liquid M1 DWX data for intraday breakouts.
- XAUUSD.DWX - Card R3 metals symbol with liquid M1 DWX data for range expansion.
- GDAXI.DWX - Matrix-available DAX custom symbol used for the card's GER40 exposure.

**Explicitly NOT for:**
- GER40.DWX - Card-stated name is not present in dwx_symbol_matrix.csv; GDAXI.DWX is the available DAX port.
- Non-DWX symbols - Research and backtest artifacts must use the broker/custom `.DWX` names.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | M30 ATR for catastrophic stop |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday; closed by the 12:00 EST source-session close |
| Expected drawdown profile | Medium-high because daily breakouts can overtrade in choppy sessions and the source has no native stop. |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository script
**Pointer:** je-suis-tm quant-trading Dual Thrust backtest.py
**R1-R4 verdict (Q00):** all PASS / see artifacts/cards_approved/QM5_11263_qt-dual-thrust.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by QM_FrameworkInit (EA_INPUT_RISK_MODE_MISMATCH).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-08 | Initial build from card | bf45d336-fba5-4b4c-a795-edec2649b385 |
