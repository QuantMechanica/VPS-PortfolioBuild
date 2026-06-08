# QM5_11267_qt-macd-ma - Strategy Spec

**EA ID:** QM5_11267
**Slug:** qt-macd-ma
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA compares a fast SMA of close to a slow SMA of close on the last closed bar. It enters long when the fast SMA is greater than or equal to the slow SMA, and enters short when the fast SMA is below the slow SMA. Entries are skipped when the absolute SMA spread is smaller than the configured ATR deadband. Open positions close when the SMA state flips against the position or when the configured maximum hold time is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma_period` | 10 | 10-15 | Fast SMA period from the card test set. |
| `strategy_slow_sma_period` | 21 | 21-34 | Slow SMA period from the card test set. |
| `strategy_atr_period` | 14 | 14 | ATR period for the hard stop and deadband. |
| `strategy_deadband_atr_mult` | 0.05 | 0.00-0.10 | Minimum SMA spread as a multiple of ATR. |
| `strategy_atr_stop_mult` | 2.5 | 2.0-3.0 | Hard stop distance in ATR multiples. |
| `strategy_max_hold_bars_h4` | 30 | 30 | Maximum hold in bars for H4 and non-D1 test frames. |
| `strategy_max_hold_bars_d1` | 20 | 20 | Maximum hold in bars for D1 test frames. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with DWX close-price history.
- `GBPUSD.DWX` - card-listed FX major with DWX close-price history.
- `XAUUSD.DWX` - card-listed metal with DWX close-price history.
- `NDX.DWX` - card-listed index with DWX close-price history.
- `GDAXI.DWX` - DAX DWX equivalent used because the card's `GER40.DWX` name is not in the DWX matrix.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; registered as `GDAXI.DWX` instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | up to 30 H4 bars or 20 D1 bars if no crossover occurs |
| Expected drawdown profile | Medium risk; moving-average crossover systems can lose during range-bound regimes. |
| Regime preference | trend-following / moving-average-crossover |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository script
**Pointer:** https://github.com/je-suis-tm/quant-trading/blob/master/MACD%20Oscillator%20backtest.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11267_qt-macd-ma.md`

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
| v1 | 2026-06-08 | Initial build from card | 4fb4658f-9276-4da7-a5aa-0a1d9d622aeb |
