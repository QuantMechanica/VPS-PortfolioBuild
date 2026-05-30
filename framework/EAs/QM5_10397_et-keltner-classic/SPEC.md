# QM5_10397_et-keltner-classic - Strategy Spec

**EA ID:** QM5_10397
**Slug:** et-keltner-classic
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA runs on D1 bars. It computes a moving average from closing prices and a range band from the average of high minus low over the same lookback. It enters long after a closed bar finishes above the upper band and enters short after a closed bar finishes below the lower band. It exits long when the closed bar returns below the moving average and exits short when the closed bar returns above the moving average.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_slen | 20 | 2-200 | Lookback length for SMA(close) and SMA(high-low). |
| strategy_band_mult | 1.5 | 0.1-5.0 | Multiplier applied to the average range band. |
| strategy_atr_period | 20 | 2-200 | ATR period used for the protective stop. |
| strategy_atr_sl_mult | 2.0 | 0.5-10.0 | ATR multiple used for stop distance. |
| strategy_min_range_spreads | 4.0 | 1.0-20.0 | Minimum average range as a multiple of current spread. |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 index exposure named directly by the card; backtest-only at T6 gate.
- NDX.DWX - Nasdaq 100 index exposure named directly by the card.
- WS30.DWX - Dow 30 index exposure named directly by the card.
- GDAXI.DWX - DAX custom symbol port for the card's GER40.DWX target.
- EURUSD.DWX - major FX pair named directly by the card.
- XAUUSD.DWX - gold metal exposure named directly by the card.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to GDAXI.DWX.

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
| Trades / year / symbol | 25 |
| Typical hold time | days |
| Expected drawdown profile | Daily breakout strategy with broad symbol overlap and ATR-defined loss per trade. |
| Regime preference | breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/free-new-trading-systems-fully-disclosed.218842/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10397_et-keltner-classic.md`

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
| v1 | 2026-05-25 | Initial build from card | 9f8a996f-75d8-41a0-aa18-30814ffb60fe |
