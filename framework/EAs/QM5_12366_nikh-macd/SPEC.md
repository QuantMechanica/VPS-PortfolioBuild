# QM5_12366_nikh-macd - Strategy Spec

**EA ID:** QM5_12366
**Slug:** nikh-macd
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades long-only D1 MACD signal-line crossovers. It computes MACD main as EMA(12) minus EMA(26), computes the signal line as EMA(9) of MACD, and opens a long position when the last completed D1 bar has MACD main above the signal line while the prior completed bar was not above it. It closes the long position when the last completed D1 bar has MACD main below the signal line. Each entry uses a hard stop at 2.0 times ATR(14) from the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_macd_fast_period | 12 | 1 to strategy_macd_slow_period - 1 | Fast EMA period for the MACD main line. |
| strategy_macd_slow_period | 26 | strategy_macd_fast_period + 1 and above | Slow EMA period for the MACD main line. |
| strategy_macd_signal_period | 9 | 1 and above | EMA period for the MACD signal line. |
| strategy_atr_period | 14 | 1 and above | ATR period used for the protective hard stop. |
| strategy_atr_sl_mult | 2.0 | greater than 0 | ATR multiple used to place the hard stop from entry. |
| strategy_warmup_bars | 120 | at least slow MACD period plus signal period | Minimum D1 indicator warmup before entries are allowed. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - R3 PASS FX major with DWX close-series data.
- GBPUSD.DWX - R3 PASS FX major with DWX close-series data.
- USDJPY.DWX - R3 PASS FX major with DWX close-series data.
- XAUUSD.DWX - R3 PASS metal market with DWX close-series data.
- GDAXI.DWX - available DWX DAX custom symbol used as the matrix-verified replacement for the card's GER40.DWX target.
- NDX.DWX - R3 PASS US large-cap index with DWX close-series data.
- WS30.DWX - R3 PASS US large-cap index with DWX close-series data.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX.
- SP500.DWX - optional in the card, but not part of the primary P2 basket for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 16 |
| Typical hold time | Daily crossover holds; usually days to weeks depending on trend persistence |
| Expected drawdown profile | Range markets can produce repeated whipsaw exits and ATR stop losses |
| Regime preference | momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository
**Pointer:** https://github.com/Nikhil-Adithyan/Algorithmic-Trading-with-Python/blob/main/Momentum/MACD.py
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12366_nikh-macd.md`

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
| v1 | 2026-06-11 | Initial build from card | 9a9fe8c5-69c0-4a38-92af-4a5f4056f657 |
