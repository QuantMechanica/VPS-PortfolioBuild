# QM5_10280_whc-rsrs - Strategy Spec

**EA ID:** QM5_10280
**Slug:** whc-rsrs
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades a long-only daily RSRS support-resistance trend signal. On each closed D1 bar it computes a 20-bar ordinary least squares regression of High on Low and uses the slope as RSRS. It opens long when RSRS is greater than 0.80 and exits when RSRS falls below 0.50. The source has no explicit stop, so the build adds the card-requested catastrophic stop at 2.0 times ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_signal_tf | PERIOD_D1 | D1 expected | Timeframe used for RSRS and ATR reads |
| strategy_rsrs_period | 20 | >= 2 | Number of closed bars in the High-on-Low regression |
| strategy_entry_threshold | 0.80 | > 0 | Open long when RSRS is above this value |
| strategy_exit_threshold | 0.50 | > 0 | Close long when RSRS is below this value |
| strategy_atr_period | 14 | >= 1 | ATR period for the catastrophic stop |
| strategy_atr_sl_mult | 2.00 | > 0 | ATR multiplier for the catastrophic stop distance |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - liquid US large-cap index proxy with OHLC history.
- WS30.DWX - liquid US large-cap index proxy with OHLC history.
- SP500.DWX - S&P 500 custom symbol, valid for backtest-only baseline coverage.
- XAUUSD.DWX - liquid metal symbol using only OHLC inputs.
- EURUSD.DWX - major FX pair using only OHLC inputs.
- GBPUSD.DWX - major FX pair using only OHLC inputs.
- USDJPY.DWX - major FX pair using only OHLC inputs.
- AUDUSD.DWX - major FX pair using only OHLC inputs.
- USDCAD.DWX - major FX pair using only OHLC inputs.
- USDCHF.DWX - major FX pair using only OHLC inputs.
- NZDUSD.DWX - major FX pair using only OHLC inputs.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - DWX data availability is mandatory.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entry and `QM_IsNewBar(_Symbol, strategy_signal_tf)` for open-position exits |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | days to weeks |
| Expected drawdown profile | Trend-following drawdowns during flat or mean-reverting regimes |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository strategy
**Pointer:** https://github.com/whchien/ai-trader/blob/main/ai_trader/backtesting/strategies/classic/rsrs.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10280_whc-rsrs.md`

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
| v1 | 2026-06-12 | Initial build from card | 31c130e4-2a5f-4501-85d9-d827b13aa136 |
