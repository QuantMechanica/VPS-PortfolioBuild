# QM5_9934_bandy-ulcer-index-spike-rsi2-mr-index — Strategy Spec

**EA ID:** QM5_9934
**Slug:** andy-ulcer-index-spike-rsi2-mr-index
**Source:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Author of this spec:** Gemini Orchestration
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

Mechanical long-only equity-index mean reversion strategy based on Howard Bandy's *Quantitative Technical Analysis* (2015) using the Peter Martin (1987) Ulcer Index (UI) drawdown-pain metric and Larry Connors (2008) 2-period RSI oversold confirmation.
On each completed D1 bar close:
1. Calculates 14-period Ulcer Index across trailing 14 bars: dd_i = 100 * (high_max_14 - close_i) / high_max_14, UI = sqrt(mean(dd_i^2)).
2. Computes the rolling 80th-percentile of UI over the last 252 daily readings: UI_p80 = percentile(UI_series, 80, lookback=252).
3. Calculates 2-period RSI on close: 
si2 = RSI(close, 2).
4. Calculates 200-period simple moving average regime gate on close: 
egime = SMA(close, 200).
5. Long entry at next bar open when UI >= UI_p80, 
si2 <= 10, close > regime, and no position currently open.
6. Short entry is not used; long-only by design for equity-index post-panic snap-backs.
7. One position per magic.
8. Attaches a catastrophic stop loss at 3.0 * ATR(14) below ask at fill, fixed for trade duration.
9. Exit on mean reversion snap-back at next bar open when 
si2 >= 70, or when 10 trading days have elapsed (time stop), or when catastrophic stop is hit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ui_period | 14 | 10 / 14 / 21 | Lookback period in D1 bars for Ulcer Index calculation. |
| strategy_percentile_lookback | 252 | 126 / 252 | Trailing sample size in D1 bars for rolling UI percentile threshold. |
| strategy_percentile_threshold | 80.0 | 70.0 / 80.0 / 90.0 | Percentile threshold of UI distribution required to signal panic spike. |
| strategy_rsi_period | 2 | 2 / 3 | D1 RSI period for short-term swing timing. |
| strategy_rsi_entry_threshold | 10.0 | 5.0 / 10.0 / 15.0 | RSI threshold for oversold entry trigger. |
| strategy_rsi_exit_threshold | 70.0 | 60.0 / 70.0 / 80.0 | RSI threshold for mean-reversion recovery exit. |
| strategy_regime_sma_period | 200 | 100 / 200 / 300 | D1 simple moving average regime filter period. |
| strategy_atr_period | 14 | fixed | D1 ATR period for catastrophic stop loss. |
| strategy_atr_stop_mult | 3.0 | 2.5 / 3.0 / 3.5 | ATR multiplier for catastrophic stop loss distance. |
| strategy_time_stop_bars | 10 | 7 / 10 / 14 | Maximum holding duration in completed D1 bars. |
| strategy_warmup_bars | 270 | 252 .. 300 | Minimum D1 bars required before trading. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_*, qm_rng_seed, qm_friday_close_*) are documented in ramework/V5_FRAMEWORK_DESIGN.md and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- GDAXI.DWX — liquid equity index CFD.
- NDX.DWX — liquid equity index CFD.
- SP500.DWX — canonical equity index backtest instrument.
- UK100.DWX — liquid equity index CFD.
- WS30.DWX — liquid equity index CFD.
- XAUUSD.DWX — liquid precious metals CFD.
- EURUSD.DWX — liquid FX major.
- GBPUSD.DWX — liquid FX major.
- USDJPY.DWX — liquid FX major.
- USDCHF.DWX — liquid FX major.
- AUDUSD.DWX — liquid FX major.
- USDCAD.DWX — liquid FX major.
- NZDUSD.DWX — liquid FX major.

**Explicitly NOT for:**
Any symbol not registered in ramework/registry/magic_numbers.csv.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) for entries; QM_IsNewCalendarPeriod(PERIOD_D1) for restart-safe D1 exits |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 10 |
| Expected trade frequency | approximately 0.5–1.0 entries per month during volatile drawdown periods |
| Typical hold time | 2 to 10 trading days |
| Expected drawdown profile | catastrophic stop hits during protracted regime shifts or extended bear markets |
| Regime preference | bull market pullbacks / temporary panic sell-offs above 200 SMA |
| Win rate target (qualitative) | high (65–75%) with short holding duration typical of Connors-style mean reversion |

---

## 6. Source Citation

This strategy was mechanised from:

**Source ID:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Source type:** book
**Citation:** Howard B. Bandy, *Quantitative Technical Analysis: An Integrated Approach to Trading System Development and Trade Management*, Blue Owl Press, 2015, ISBN 9780979183850; Peter G. Martin and Byron B. McCann, *The Investor's Guide to Fidelity Funds*, John Wiley & Sons, 1989, ISBN 0471515264; Larry Connors and Cesar Alvarez, *Short Term Trading Strategies That Work*, TradingMarkets Publishing, 2008.
**Approved card:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_9934_bandy-ulcer-index-spike-rsi2-mr-index.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | ,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV to mode validation is enforced by QM_FrameworkInit.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | Initial build from card | Gemini Orchestration cycle |
