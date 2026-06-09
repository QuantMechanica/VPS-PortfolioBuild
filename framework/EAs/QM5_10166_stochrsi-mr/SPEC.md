# QM5_10166_stochrsi-mr - Strategy Spec

**EA ID:** QM5_10166
**Slug:** stochrsi-mr
**Source:** d3c009d7-a8d6-5251-b572-4777b207c2b9 (see `sources/raposa-python-backtests`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. It computes RSI(14), then computes StochRSI as the RSI value's position inside the rolling 14-bar RSI min/max range. It enters long when StochRSI crosses upward through 20 from below, and enters short when StochRSI crosses downward through 80 from above. It exits long when StochRSI crosses above 50, exits short when StochRSI crosses below 50, and also exits on the opposite entry signal before any possible reversal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 10-21 P3 sweep | RSI lookback used as the base oscillator. |
| `strategy_stochrsi_lookback` | 14 | 10-21 P3 sweep | Rolling RSI min/max window for StochRSI. |
| `strategy_entry_low` | 20.0 | 10.0-30.0 P3 sweep | Long trigger when StochRSI crosses upward through this level. |
| `strategy_entry_high` | 80.0 | 70.0-90.0 P3 sweep | Short trigger when StochRSI crosses downward through this level. |
| `strategy_exit_level` | 50.0 | 45.0-55.0 P3 sweep | Centerline exit threshold for open positions. |
| `strategy_atr_period` | 14 | fixed baseline | ATR lookback for the emergency stop. |
| `strategy_atr_sl_mult` | 2.5 | 1.5-3.0 P3 sweep | ATR multiple for stop loss distance from entry. |
| `strategy_min_warmup_bars` | 30 | fixed baseline | Minimum warmup window from the card; guards invalid StochRSI settings. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - R3 equity index example for S&P 500 exposure; backtest-only per infrastructure note.
- NDX.DWX - R3 equity index example for Nasdaq 100 exposure.
- WS30.DWX - R3 equity index example for Dow 30 exposure.
- AUDCAD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- AUDCHF.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- AUDJPY.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- AUDNZD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- AUDUSD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- CADCHF.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- CADJPY.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- CHFJPY.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- EURAUD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- EURCAD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- EURCHF.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- EURGBP.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- EURJPY.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- EURNZD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- EURUSD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- GBPAUD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- GBPCAD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- GBPCHF.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- GBPJPY.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- GBPNZD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- GBPUSD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- GDAXI.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- NZDCAD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- NZDCHF.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- NZDJPY.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- NZDUSD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- UK100.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- USDCAD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- USDCHF.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- USDJPY.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- XAGUSD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- XAUUSD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- XNGUSD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.
- XTIUSD.DWX - close-derived oscillator is symbol-agnostic and the symbol is in the verified DWX matrix.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the broker data matrix is the full allowed universe for this build.

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
| Trades / year / symbol | 40 |
| Typical hold time | Several days, until StochRSI crosses its centerline or the ATR emergency stop is hit. |
| Expected drawdown profile | Fast oscillator mean reversion can suffer during persistent trend regimes. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d3c009d7-a8d6-5251-b572-4777b207c2b9
**Source type:** blog
**Pointer:** https://raposa.trade/blog/2-ways-to-trade-the-stochastic-rsi-in-python/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10166_stochrsi-mr.md`

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
| v1 | 2026-06-10 | Initial build from card | 152f86cd-4031-4fb7-9266-1c0289cbde34 |
