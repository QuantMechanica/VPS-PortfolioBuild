# QM5_10286_cinar-supertrend - Strategy Spec

**EA ID:** QM5_10286
**Slug:** cinar-supertrend
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (GitHub cinar/indicator)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades a daily SuperTrend stop-and-reverse rule from the Cinar indicator repository. On each closed D1 bar it computes true range, applies a Hull moving average with period 14, builds bands from `(High + Low) / 2 +/- 2.5 * HMA(TR)`, and carries the SuperTrend band forward using standard final upper/lower band rules. It opens long when the closed bar is above the SuperTrend line and opens short when the closed bar is below it. If an opposite position is already open, that position is closed first and the reverse entry is then submitted.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 14 | 2-100 | Period for the true-range Hull moving average used by SuperTrend. |
| strategy_atr_multiplier | 2.5 | 0.1-10.0 | Multiplier applied to the HMA true range when forming SuperTrend bands. |
| strategy_warmup_bars | 180 | 40-1000 | Closed bars copied once per entry evaluation to warm up final bands. |
| strategy_fallback_atr_sl_mult | 2.0 | 0.1-10.0 | Catastrophic ATR stop multiplier used only if the SuperTrend line is not on the valid stop side. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- AUDCAD.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- AUDCHF.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- AUDJPY.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- AUDNZD.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- AUDUSD.DWX - Matrix-listed major FX pair; card allows major FX/cross portability.
- CADCHF.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- CADJPY.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- CHFJPY.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- EURAUD.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- EURCAD.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- EURCHF.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- EURGBP.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- EURJPY.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- EURNZD.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- EURUSD.DWX - Matrix-listed major FX pair; card allows major FX/cross portability.
- GBPAUD.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- GBPCAD.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- GBPCHF.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- GBPJPY.DWX - Explicitly named in the card.
- GBPNZD.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- GBPUSD.DWX - Matrix-listed major FX pair; card allows major FX/cross portability.
- GDAXI.DWX - Canonical matrix symbol for the card's DAX exposure.
- NDX.DWX - Explicitly named in the card.
- NZDCAD.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- NZDCHF.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- NZDJPY.DWX - Matrix-listed FX cross; card allows major FX/cross portability.
- NZDUSD.DWX - Matrix-listed major FX pair; card allows major FX/cross portability.
- SP500.DWX - Matrix-listed index CFD and available custom S&P 500 backtest symbol.
- UK100.DWX - Matrix-listed index CFD fitting the broad R3 index portability statement.
- USDCAD.DWX - Matrix-listed major FX pair; card allows major FX/cross portability.
- USDCHF.DWX - Matrix-listed major FX pair; card allows major FX/cross portability.
- USDJPY.DWX - Matrix-listed major FX pair; card allows major FX/cross portability.
- WS30.DWX - Explicitly named in the card.
- XAGUSD.DWX - Matrix-listed metal CFD; card allows metals portability.
- XAUUSD.DWX - Explicitly named in the card.
- XNGUSD.DWX - Matrix-listed commodity CFD fitting the broad R3 CFD portability statement.
- XTIUSD.DWX - Matrix-listed commodity CFD fitting the broad R3 CFD portability statement.

**Explicitly NOT for:**
- DAX.DWX - Not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the canonical registered DAX symbol.
- Any symbol outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol data guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Typical hold time | Not specified in card frontmatter; stop-and-reverse implies multi-day trend holds. |
| Expected drawdown profile | Trend-following losses during choppy/non-trending regimes. |
| Regime preference | Trend-following / volatility-stop |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** https://github.com/cinar/indicator/blob/master/strategy/volatility/super_trend_strategy.go and https://github.com/cinar/indicator/blob/master/volatility/super_trend.go
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10286_cinar-supertrend.md`

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
| v1 | 2026-06-12 | Initial build from card | 11e7be1d-3c13-444e-b14d-8886a4a99dbb |
