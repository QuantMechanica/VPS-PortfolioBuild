# QM5_9294_mql5-trix-wpr-break - Strategy Spec

**EA ID:** QM5_9294
**Slug:** mql5-trix-wpr-break
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades H4 TRIX zero-line breakouts only when the breakout bar is also the rolling TRIX extreme and Williams Percent Range is in the matching neutral zone. A long entry requires TRIX to cross from below zero to above zero, the current TRIX to be the maximum over the lookback window, WPR between -50 and -20, and absolute TRIX slope above its 20-bar median absolute slope. A short entry mirrors this with TRIX crossing below zero, current TRIX at the rolling minimum, and WPR between -80 and -50.

Long exits trigger when TRIX crosses below zero, WPR falls below -80, or the closed-bar close is below EMA(20). Short exits trigger when TRIX crosses above zero, WPR rises above -20, or the closed-bar close is above EMA(20). Initial stop is 1.5 x ATR(14); no take-profit, trailing, break-even, scaling, grid, or adaptive logic is used.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_trix_period | 14 | >=2 | Period for the triple EMA used to compute TRIX. |
| strategy_trix_extreme_lookback | 20 | >=2 | Rolling window used to test whether current TRIX is the max or min. |
| strategy_wpr_period | 14 | >=2 | Williams Percent Range period. |
| strategy_ema_period | 20 | >=2 | EMA period used by the exit guard. |
| strategy_atr_period | 14 | >=1 | ATR period used for the initial stop. |
| strategy_atr_sl_mult | 1.5 | >0 | ATR multiple for the initial stop. |
| strategy_slope_median_lookback | 20 | >=1 | Lookback for median absolute TRIX slope filter. |
| strategy_max_spread_points | 0 | >=0 | Optional spread cap in points; 0 disables it and never blocks zero-spread DWX tests. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed DWX FX symbol with OHLC data for TRIX, WPR, EMA, and ATR.
- GBPJPY.DWX - card-listed DWX FX symbol with OHLC data for TRIX, WPR, EMA, and ATR.
- CHFJPY.DWX - card-listed DWX FX symbol with OHLC data for TRIX, WPR, EMA, and ATR.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 research and backtest pipeline requires canonical `.DWX` symbols.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the broker/tester data matrix is the build-time universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Not specified by the card; expected to be multiple H4 bars until oscillator or EMA exit. |
| Expected drawdown profile | Momentum-breakout strategy with ATR-defined per-trade risk and no averaging. |
| Regime preference | Breakout / momentum |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** MQL5 article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 67): Using Patterns of TRIX and the Williams Percent Range", 2025-05-29, https://www.mql5.com/en/articles/18251
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9294_mql5-trix-wpr-break.md`

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
| v1 | 2026-06-20 | Initial build from card | 87e7a085-da60-44e0-9168-e34195f80835 |
