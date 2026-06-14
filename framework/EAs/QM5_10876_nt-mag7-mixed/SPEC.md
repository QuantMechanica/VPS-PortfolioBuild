# QM5_10876_nt-mag7-mixed - Strategy Spec

**EA ID:** QM5_10876
**Slug:** nt-mag7-mixed
**Source:** 886c5c2e-a87b-5893-9dff-5833be8bc0a3 (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades a monthly long-only rebalance rule on D1 index proxies. On the first D1 bar after a new calendar month, it checks whether the last closed bar satisfies between one and two of three conditions: close above SMA(30), close within 5% of the 252-day low, and RSI(14) below 28 while the SP500.DWX proxy RSI(14) is above 33. If eligible and flat, it enters long with a 3.0 x ATR(20) stop; if ineligible during the monthly rebalance and a position is open, it closes the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_sma_period | 30 | 1+ | D1 SMA period for the close-above-average condition. |
| strategy_low_lookback_d1_bars | 252 | 1+ | Closed D1 bars used for the 52-week low proxy. |
| strategy_low_distance_mult | 1.05 | >0 | Maximum close-to-low multiple for the near-low condition. |
| strategy_rsi_period | 14 | 1+ | D1 RSI period for symbol and SP500 proxy RSI. |
| strategy_rsi_threshold | 28.0 | 0-100 | Symbol RSI must be below this level for the oversold condition. |
| strategy_proxy_rsi_threshold | 33.0 | 0-100 | SP500 proxy RSI must be above this level for the oversold condition. |
| strategy_atr_period | 20 | 1+ | D1 ATR period used for the catastrophic stop. |
| strategy_atr_sl_mult | 3.0 | >0 | ATR multiple subtracted from entry for the long stop. |
| strategy_min_history_d1_bars | 260 | 1+ | Minimum D1 history required before monthly decisions. |
| strategy_max_spread_points | 0 | 0+ | Optional spread ceiling; 0 disables this extra check. |
| strategy_enable_profit_take | false | true/false | Enables the card's optional P3 profit-taking variant. |
| strategy_profit_take_pct | 25.0 | >0 | Return threshold used only when optional profit-taking is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 proxy for the source's broad US large-cap universe; backtest-only per DWX discipline.
- NDX.DWX - Nasdaq 100 proxy for MAG7-heavy large-cap technology exposure.
- WS30.DWX - Dow 30 proxy for diversified US mega-cap exposure.

**Explicitly NOT for:**
- SPY.DWX - unavailable; the canonical S&P 500 custom symbol is SP500.DWX.
- SPX500.DWX - unavailable phantom variant; not present in the DWX matrix.
- ES.DWX - unavailable futures-style variant; not present in the DWX matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; cross-symbol SP500.DWX RSI proxy only |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | days to one month |
| Expected drawdown profile | Long-only large-cap tactical exposure; drawdown rises during broad equity selloffs. |
| Regime preference | mixed momentum and mean-reversion on large-cap indices |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 886c5c2e-a87b-5893-9dff-5833be8bc0a3
**Source type:** blog
**Pointer:** Austin Starks, NexusTrade, "This strategy has beaten the market for over 5 years. Here's how I created it", https://nexustrade.io/blog/this-strategy-has-beaten-the-market-for-over-5-years-heres-how-i-created-it-20250329
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10876_nt-mag7-mixed.md`

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
| v1 | 2026-06-14 | Initial build from card | 920766a4-1d3c-42ec-a9e7-686172fcbc04 |
