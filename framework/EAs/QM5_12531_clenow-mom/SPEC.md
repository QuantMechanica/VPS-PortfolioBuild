# QM5_12531_clenow-mom - Strategy Spec

**EA ID:** QM5_12531
**Slug:** clenow-mom
**Source:** cfeee113-154e-549a-9fba-501b7e3160c0
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA evaluates a fixed DWX macro basket once per week on D1 bars. For each basket symbol it computes 90-day exponential-regression momentum from log closes, annualizes the slope, multiplies it by regression R-squared, and ranks the symbols from strongest to weakest. It opens long positions only when the chart symbol is in the top 20% of the active basket and SP500.DWX is above its 200-day SMA. It exits weekly when the held symbol falls out of that top segment or closes below its own 100-day SMA.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_momentum_lookback_d1 | 90 | 60-120 | D1 close count used in the exponential-regression momentum score. |
| strategy_top_percent | 20.0 | 15.0-25.0 | Percent of ranked active symbols eligible for long entry. |
| strategy_market_sma_period | 200 | 150-250 | SP500.DWX D1 SMA regime-filter period. |
| strategy_exit_sma_period | 100 | 80-120 | Per-symbol D1 SMA exit filter. |
| strategy_atr_period | 20 | 20 | ATR period for emergency stop placement. |
| strategy_atr_stop_mult | 3.0 | 2.5-3.5 | ATR multiple used for the emergency stop distance. |
| strategy_rebalance_weekday | 1 | 0-6 | Broker weekday for weekly entry and exit checks; Sunday=0, Monday=1. |
| strategy_min_active_basket | 5 | 5-8 | Minimum number of symbols with valid ranking data before new entries are allowed. |
| strategy_spread_lookback_d1 | 60 | 60 | D1 bars used to compute the median modeled spread guard. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX member of the card's macro momentum basket.
- GBPUSD.DWX - liquid major FX member of the card's macro momentum basket.
- USDJPY.DWX - liquid major FX member of the card's macro momentum basket.
- AUDUSD.DWX - liquid major FX member of the card's macro momentum basket.
- USDCAD.DWX - liquid major FX member of the card's macro momentum basket.
- NDX.DWX - liquid US equity-index member of the card's macro momentum basket.
- WS30.DWX - liquid US equity-index member of the card's macro momentum basket.
- XAUUSD.DWX - liquid metal member of the card's macro momentum basket.

**Explicitly NOT for:**
- SP500.DWX - used only as the source-style market regime filter; it is not a traded member of this EA's registered target basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | SP500.DWX D1 regime filter and D1 ranking reads across the registered basket |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Multi-week trend holds with weekly rebalance checks |
| Expected drawdown profile | Medium turnover with drawdowns during broad trend reversals and regime whipsaw |
| Regime preference | Cross-sectional trend momentum with positive equity-market regime |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** cfeee113-154e-549a-9fba-501b7e3160c0
**Source type:** blog article
**Pointer:** https://teddykoker.com/2019/05/momentum-strategy-from-stocks-on-the-move-in-python/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12531_clenow-mom.md`

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
| v1 | 2026-06-18 | Initial build from card | 4425ff56-b02e-4c26-a305-f0943aad2e2b |
