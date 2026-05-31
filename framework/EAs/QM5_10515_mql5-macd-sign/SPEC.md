# QM5_10515_mql5-macd-sign - Strategy Spec

**EA ID:** QM5_10515
**Slug:** `mql5-macd-sign`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates completed H1 bars. It opens a long position when both the MACD main line and MACD signal line are above zero, and opens a short position when both lines are below zero. It closes an open position when the two MACD lines no longer share the same sign. Each entry uses an ATR(14) stop at 1.5 times ATR and a fixed target at 1.5R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast_period` | 12 | 1-100 | Fast EMA period for the MACD calculation. |
| `strategy_macd_slow_period` | 26 | 2-200 | Slow EMA period for the MACD calculation; must be greater than fast period. |
| `strategy_macd_signal_period` | 9 | 1-100 | Signal smoothing period for the MACD signal line. |
| `strategy_atr_period` | 14 | 1-200 | ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiplier for the stop-loss distance. |
| `strategy_tp_r_multiple` | 1.5 | 0.1-10.0 | Take-profit distance as a multiple of initial risk. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 primary FX basket member for portable MACD OHLC testing.
- `GBPUSD.DWX` - card R3 primary FX basket member for portable MACD OHLC testing.
- `USDJPY.DWX` - card R3 primary FX basket member for portable MACD OHLC testing.
- `XAUUSD.DWX` - card R3 metals member for portable MACD OHLC testing.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtesting.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `75` |
| Typical hold time | `hours to days; until MACD line signs diverge or SL/TP is hit` |
| Expected drawdown profile | `ATR-normalized fixed-risk trend-following drawdowns during MACD whipsaw regimes` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `forum`
**Pointer:** `https://www.mql5.com/en/code/19977`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10515_mql5-macd-sign.md`

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
| v1 | 2026-05-28 | Initial build from card | 49a72bd4-0d78-446c-ae47-0fdf8f0df99e |
