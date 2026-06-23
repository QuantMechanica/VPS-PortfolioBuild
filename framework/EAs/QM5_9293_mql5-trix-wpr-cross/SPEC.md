# QM5_9293_mql5-trix-wpr-cross - Strategy Spec

**EA ID:** QM5_9293
**Slug:** `mql5-trix-wpr-cross`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades H4 closed-bar TRIX zero-line crosses, confirmed by Williams Percent Range. A long entry fires when TRIX crosses from below zero to above zero and WPR is above -50; a short entry fires when TRIX crosses from above zero to below zero and WPR is below -50. Long positions close on a reverse TRIX cross or WPR falling below -80; short positions close on a reverse TRIX cross or WPR rising above -20. The initial stop is placed at 1.5 times ATR(14) from the entry side.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trix_period` | 3 | 2-100 | Triple EMA TRIX smoothing period; card directs P3 tests of 3, 9, and 15. |
| `strategy_wpr_period` | 14 | 2-100 | Williams Percent Range lookback period. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for initial stop placement. |
| `strategy_atr_sl_mult` | 1.5 | > 0 | Multiplier applied to ATR for the initial stop distance. |
| `strategy_max_spread_points` | 0 | >= 0 | Optional extra spread cap; 0 leaves only framework spread/news filters active. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major available in the DWX matrix.
- `GBPJPY.DWX` - card-listed FX cross available in the DWX matrix.
- `CHFJPY.DWX` - card-listed FX cross available in the DWX matrix.

**Explicitly NOT for:**
- `SP500.DWX` - not listed by the card; this is an FX oscillator strategy.
- `XAUUSD.DWX` - not listed by the card and has different volatility behavior.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default skeleton gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | Not specified by card; H4 oscillator exits imply hours to days. |
| Expected drawdown profile | Momentum oscillator strategy with ATR-bounded single-position risk. |
| Regime preference | trend-following / momentum |
| Win rate target (qualitative) | medium |
| Expected trade frequency | Medium frequency; roughly 35-80 trades per year per symbol. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** MQL5 article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 67): Using Patterns of TRIX and the Williams Percent Range", 2025-05-29, https://www.mql5.com/en/articles/18251
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9293_mql5-trix-wpr-cross.md`

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
| v1 | 2026-06-23 | Initial build from card | 7d76d093-019f-42d1-9a31-be1f2af3a62e |
