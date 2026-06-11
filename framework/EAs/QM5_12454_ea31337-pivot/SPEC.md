# QM5_12454_ea31337-pivot - Strategy Spec

**EA ID:** QM5_12454
**Slug:** ea31337-pivot
**Source:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades Camarilla pivot-zone mean reversion. On each closed H1 bar it computes prior daily Camarilla levels and opens long when the typical price is in the deeper half of an S1/S2, S2/S3, or S3/S4 support zone while S1 has decreased over the four-day check. It opens short when the typical price is in the deeper half of an R1/R2, R2/R3, or R3/R4 resistance zone while R1 has increased over the same check. Exits are broker SL/TP, a 30-bar time stop, Friday close, or a cached opposite pivot-zone signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_max_spread_pips | 4.0 | >0 | Maximum allowed spread before entry is blocked. |
| strategy_signal_shift | 1 | >=1 | Closed chart bar used for the typical-price zone test. |
| strategy_pivot_shift | 1 | >=1 | Closed D1 bar used to compute Camarilla levels. |
| strategy_pivot_threshold | 0.0 | >=0 | Percent threshold for the four-day R1/S1 direction check. |
| strategy_close_profit_pips | 80.0 | >0 | Fixed take-profit distance, matching the source close-profit default. |
| strategy_close_after_bars | 30 | >0 | Maximum hold time in chart bars, matching source close time -30 bars. |
| strategy_atr_period | 14 | >0 | ATR period used only when pivot stop spacing is too tight. |
| strategy_atr_sl_mult | 1.5 | >0 | ATR multiplier for the fallback protective stop. |
| strategy_min_stop_pips | 8.0 | >0 | Minimum stop distance before switching to the ATR fallback. |
| strategy_stop_buffer_pips | 1.0 | >=0 | Buffer beyond the next deeper pivot level for protective stops. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair in the card's suggested first universe.
- GBPUSD.DWX - liquid major FX pair in the card's suggested first universe.
- USDJPY.DWX - liquid major FX pair in the card's suggested first universe.
- XAUUSD.DWX - liquid metal CFD in the card's suggested first universe.
- GDAXI.DWX - verified DWX DAX 40 equivalent for the card's unavailable DAX.DWX symbol.

**Explicitly NOT for:**
- DAX.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 Camarilla pivot calculation |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Up to 30 H1 bars |
| Expected drawdown profile | Mean-reversion losses cluster when price trends through pivot zones. |
| Regime preference | Mean-reverting sessions around daily pivot support and resistance bands. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Source type:** GitHub repository
**Pointer:** https://github.com/EA31337/Strategy-Pivot/blob/master/Stg_Pivot.mqh
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12454_ea31337-pivot.md`

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
| v1 | 2026-06-11 | Initial build from card | 03cafdc9-5305-421b-b9dc-5782de28c72c |
