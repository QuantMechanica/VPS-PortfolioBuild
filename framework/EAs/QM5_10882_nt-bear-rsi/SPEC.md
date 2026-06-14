# QM5_10882_nt-bear-rsi - Strategy Spec

**EA ID:** QM5_10882
**Slug:** nt-bear-rsi
**Source:** 886c5c2e-a87b-5893-9dff-5833be8bc0a3 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades a daily long-only RSI mean-reversion proxy across SP500.DWX, NDX.DWX, and WS30.DWX. On each D1 close, it requires a weak market regime where SP500.DWX is below its 200-day SMA or the chart symbol is below its 100-day SMA. It enters the chart symbol when that symbol has the lowest RSI(14) in the proxy basket, or when single-symbol mode is enabled and RSI(14) is at or below 32. It exits when RSI(14) reaches 50, when the D1 close breaches the ATR stop level, or after 20 D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_rsi_period | 14 | >= 2 | RSI period used for ranking, entry threshold, and exit threshold. |
| strategy_rsi_entry_threshold | 32.0 | > 0 and below exit threshold | Single-symbol oversold threshold. |
| strategy_rsi_exit_threshold | 50.0 | above entry threshold | RSI level that triggers strategy exit. |
| strategy_sp500_sma_period | 200 | >= 2 | SP500.DWX regime SMA period. |
| strategy_chart_sma_period | 100 | >= 2 | Chart-symbol weak-regime SMA period. |
| strategy_atr_period | 14 | >= 2 | ATR period for stop distance and volatility filter. |
| strategy_atr_stop_mult | 2.5 | > 0 | ATR multiple for initial stop and ATR exit check. |
| strategy_atr_median_lookback | 252 | >= 20 | Number of D1 ATR samples for the median volatility filter. |
| strategy_atr_median_max_mult | 2.5 | > 0 | Blocks entry when ATR is above this multiple of its median. |
| strategy_time_stop_d1_bars | 20 | >= 1 | Maximum holding period measured in D1 bars. |
| strategy_cooldown_d1_bars | 5 | >= 0 | Cooldown after exit measured in D1 bars. |
| strategy_single_symbol_mode | false | true/false | Uses RSI threshold instead of basket-lowest RSI when true. |
| strategy_max_spread_points | 0 | >= 0 | Optional spread cap; 0 disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 proxy named in the approved card and present in the DWX matrix.
- NDX.DWX - Nasdaq 100 proxy named in the approved card and present in the DWX matrix.
- WS30.DWX - Dow 30 proxy named in the approved card and present in the DWX matrix.

**Explicitly NOT for:**
- SPX500.DWX - not the canonical available S&P 500 custom symbol.
- SPY.DWX - not present in the DWX symbol matrix.
- ES.DWX - not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | Up to 20 D1 bars by card time stop |
| Expected drawdown profile | Counter-trend mean reversion during weak regimes; drawdown risk during sustained crashes. |
| Regime preference | Mean-reversion in bear or weak regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 886c5c2e-a87b-5893-9dff-5833be8bc0a3
**Source type:** blog
**Pointer:** NexusTrade article by Austin Starks, 2026-02-04, cited in the approved card.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10882_nt-bear-rsi.md`

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
| v1 | 2026-06-14 | Initial build from card | 42eea01e-7238-4e8d-83ff-f34459061f0c |
