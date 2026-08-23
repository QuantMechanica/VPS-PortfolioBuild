# QM5_9946_bandy-supertrend-flip-trend - Strategy Spec

**EA ID:** QM5_9946
**Slug:** andy-supertrend-flip-trend
**Source:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Author of this spec:** Gemini
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

This EA trades ATR-band Supertrend flips on D1 bars per Howard Bandy\'s quantitative trend-following benchmarks in Quantitative Technical Analysis (substrate attributed to Olivier Seban). On each completed D1 bar, the Supertrend state is computed with period 10 and multiplier 3.0. When Supertrend flips from bearish to bullish and price closes above SMA(200), the EA enters long at the next bar\'s open. When Supertrend flips from bullish to bearish and price closes below SMA(200), the EA enters short at the next bar\'s open. Positions exit upon an opposite Supertrend flip, or via a 3.0 * ATR(14) catastrophic stop loss or 60 D1-bar time stop fallback.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_supertrend_period | 10 | 5-25 | ATR period used for Supertrend calculation. |
| strategy_supertrend_mult | 3.0 | 1.0-6.0 | ATR multiplier for Supertrend upper and lower bands. |
| strategy_regime_sma_period | 200 | 50-300 | Macro regime SMA filter period. |
| strategy_atr_period | 14 | 10-20 | ATR period for catastrophic stop loss. |
| strategy_stop_atr_mult | 3.0 | 1.5-5.0 | ATR multiplier for catastrophic stop loss. |
| strategy_max_hold_bars | 60 | 20-120 | Maximum D1 hold bars before time stop exit. |
| strategy_warmup_bars | 200 | 50-500 | Lookback depth for Supertrend historical state reconstruction. |
| strategy_max_spread_points | 0 | 0-10000 | Optional spread filter; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - US large cap equity index.
- NDX.DWX - US tech index CFD.
- WS30.DWX - US Dow index CFD.
- GDAXI.DWX - German DAX index CFD.
- UK100.DWX - UK FTSE index CFD.
- EURUSD.DWX - liquid FX major.
- GBPUSD.DWX - liquid FX major.
- USDJPY.DWX - liquid FX major.
- USDCHF.DWX - liquid FX major.
- USDCAD.DWX - liquid FX major.
- AUDUSD.DWX - liquid FX major.
- NZDUSD.DWX - liquid FX major.
- XAUUSD.DWX - liquid gold CFD.

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
| Trades / year / symbol | approximately 12 |
| Typical hold time | weeks to months (trend-following horizon) |
| Expected drawdown profile | Whip-saw losses in choppy range-bound regimes; trend capture in strong trends. |
| Regime preference | Persistent directional bull/bear trends aligned with 200 SMA. |
| Win rate target (qualitative) | 35% - 45% with >1.5 profit factor / reward-to-risk |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Source type:** book / approved internal extraction
**Pointer:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_9946_bandy-supertrend-flip-trend.md
**R1-R4 verdict (Q00):** all PASS per approved card.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | ,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3% - 0.5% |

ENV to mode validation is enforced by QM_FrameworkInit (EA_INPUT_RISK_MODE_MISMATCH).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | Initial build from approved card | Gemini build EA task |
