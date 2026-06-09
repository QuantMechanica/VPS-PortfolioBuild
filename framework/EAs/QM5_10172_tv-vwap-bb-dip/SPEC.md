# QM5_10172_tv-vwap-bb-dip - Strategy Spec

**EA ID:** QM5_10172
**Slug:** tv-vwap-bb-dip
**Source:** 30591366-874b-5bee-b47c-da2fca20b728
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades long-only H1 pullbacks after a bullish trend has recovered above session VWAP. A new long entry is allowed when EMA(13) is above EMA(55), the latest completed close is above the same-day session VWAP, and price touched or closed below the lower Bollinger Band within the last 10 completed candles. The protective stop is the tighter of 5 percent from entry or 2.5 * ATR(14). Open longs close when a completed bar closes above the upper Bollinger Band, or through the protective stop and framework exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_H1 | H1 baseline | Timeframe used for EMA, VWAP, Bollinger, ATR, and close checks. |
| strategy_ema_fast | 13 | >0 and < slow | Fast EMA trend filter from the card's latest visible release note. |
| strategy_ema_slow | 55 | > fast | Slow EMA trend filter from the card's latest visible release note. |
| strategy_bb_period | 20 | >1 | Bollinger moving-average period. |
| strategy_bb_deviation | 2.0 | >0 | Bollinger standard-deviation multiplier. |
| strategy_dip_lookback | 10 | >0 | Completed candles checked for a lower-band touch or close. |
| strategy_atr_period | 14 | >0 | ATR period for the volatility stop. |
| strategy_atr_stop_mult | 2.5 | >0 | ATR multiplier for the volatility stop candidate. |
| strategy_percent_stop | 5.0 | >0 | Percent stop candidate; final stop uses the tighter distance. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - card names SP500 as the S&P 500 equity-index port; this custom symbol is valid for backtest.
- NDX.DWX - card names NDX as the Nasdaq equity-index port.

**Explicitly NOT for:**
- Symbols outside the active QM5_10172 registry rows - no implicit runtime expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` from the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Expected trade frequency | About 70 trades per year per symbol, from card frontmatter. |
| Typical hold time | Not specified in frontmatter; held until upper Bollinger close, stop, Friday close, or kill-switch. |
| Expected drawdown profile | Mean-reversion pullback losses during persistent downside trends; bounded per-trade by fixed-risk sizing and stop. |
| Regime preference | Bullish trend-filtered mean reversion above session VWAP. |
| Win rate target (qualitative) | Not specified in frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView script page
**Pointer:** https://www.tradingview.com/script/oZYSB6Ui-VWAP-and-BB-strategy-EEMANI/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10172_tv-vwap-bb-dip.md`

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
| v1 | 2026-06-09 | Initial build from card | 611dc835-8357-4f46-9c3e-55d1d7c01853 |
