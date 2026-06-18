# QM5_10991_ftmo-season - Strategy Spec

**EA ID:** QM5_10991
**Slug:** ftmo-season
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades a D1 trend breakout only when the current calendar month has a fixed seasonal bias. A long entry requires bullish monthly bias, D1 close above EMA(50), EMA(50) above EMA(200), and a D1 close above the prior 20-bar Donchian high; a short entry mirrors this for bearish bias and a Donchian low break. The initial stop is 2.0 x ATR(14), the take profit is 3.0R, and discretionary exits occur when the D1 close crosses back across EMA(50), at the final calendar session of the month, or after 20 D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bias_jan | 0 | -1, 0, 1 | Fixed January seasonal bias: bearish, neutral, bullish. |
| strategy_bias_feb | 0 | -1, 0, 1 | Fixed February seasonal bias. |
| strategy_bias_mar | 0 | -1, 0, 1 | Fixed March seasonal bias. |
| strategy_bias_apr | 0 | -1, 0, 1 | Fixed April seasonal bias. |
| strategy_bias_may | 0 | -1, 0, 1 | Fixed May seasonal bias. |
| strategy_bias_jun | 0 | -1, 0, 1 | Fixed June seasonal bias. |
| strategy_bias_jul | 0 | -1, 0, 1 | Fixed July seasonal bias. |
| strategy_bias_aug | 0 | -1, 0, 1 | Fixed August seasonal bias. |
| strategy_bias_sep | 0 | -1, 0, 1 | Fixed September seasonal bias. |
| strategy_bias_oct | 0 | -1, 0, 1 | Fixed October seasonal bias. |
| strategy_bias_nov | 0 | -1, 0, 1 | Fixed November seasonal bias. |
| strategy_bias_dec | 0 | -1, 0, 1 | Fixed December seasonal bias. |
| strategy_ema_fast_period | 50 | >= 1 | Fast trend EMA period on D1. |
| strategy_ema_slow_period | 200 | >= 1 | Slow trend EMA period on D1. |
| strategy_donchian_period | 20 | >= 1 | Prior-bar Donchian breakout lookback. |
| strategy_atr_period | 14 | >= 1 | ATR period for stop placement. |
| strategy_sl_atr_mult | 2.0 | > 0 | Stop distance in ATR multiples. |
| strategy_tp_rr | 3.0 | > 0 | Take-profit reward/risk multiple. |
| strategy_month_end_skip | 2 | >= 0 | Skip new entries this many calendar days before month end. |
| strategy_time_stop_bars | 20 | >= 1 | Maximum holding period in D1-bar calendar-day proxy. |
| strategy_spread_pct_of_stop | 15.0 | >= 0 | Blocks only positive spread wider than this percent of ATR stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - Card target for gold seasonal trend behavior.
- NDX.DWX - Card target for Nasdaq 100 large-cap index exposure.
- WS30.DWX - Card target for Dow 30 large-cap index exposure.
- SP500.DWX - Card target for S&P 500 exposure; backtest-only custom symbol per registry policy.

**Explicitly NOT for:**
- SPX500.DWX - Not in `dwx_symbol_matrix.csv`; SP500.DWX is the canonical S&P 500 custom symbol.
- SPY.DWX - Not in `dwx_symbol_matrix.csv`; SP500.DWX is the approved proxy.

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
| Trades / year / symbol | 24 |
| Typical hold time | Several D1 bars, capped at 20 D1 bars or month end |
| Expected drawdown profile | Trend-breakout losses are bounded by ATR stop and fixed risk per trade |
| Regime preference | Seasonal trend-following breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** blog
**Pointer:** FTMO, 2026-01-23, "How to Apply Seasonality to Your Trading Strategy", https://ftmo.com/en/blog/how-to-apply-seasonality-to-your-trading-strategy/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10991_ftmo-season.md`

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
| v1 | 2026-06-18 | Initial build from card | b2e018cb-0e87-49fd-ac22-32eb0ef52c89 |
