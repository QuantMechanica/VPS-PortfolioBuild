# QM5_9166_aa-vol-ma-timing — Strategy Spec

**EA ID:** QM5_9166
**Slug:** a-vol-ma-timing
**Source:** de348b4-0fa7-5be1-baa8-09e9089b67b7 (see D:/QM/strategy_farm/artifacts/cards_approved/QM5_9166_aa-vol-ma-timing.md)
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The strategy implements Wesley Gray / Alpha Architect's Volatility-Sorted Moving Average Timing model, evaluating on monthly rebalance boundaries from completed daily (D1) bars with a 10-month simple moving average (210 trading days).

On monthly rebalance boundaries (completed month-end):
1. Compute trailing 12-month realized volatility over 252 closed D1 bars ( = \ln(\text{Close}_t / \text{Close}_{t-1})$, $\text{vol} = \text{std\_dev}(r) \times \sqrt{252}$).
2. Compute 10-month SMA of closed prices ( \times 21 = 210$ trading days).
3. Long entry when the closed price is above the 10-month SMA ($\text{Close}_1 > \text{SMA}_{210}$).
4. Long exit when the closed price falls below or equals the 10-month SMA ($\text{Close}_1 \le \text{SMA}_{210}$).
5. Optional short trading if strategy_enable_shorts is enabled (default: false, long/cash).
6. Catastrophic / Initial Stop Loss: .0 \times \text{ATR}(20, D1)$ via QM_StopATR.
7. Spread guard: skip entry when current spread exceeds .5 \times \text{MedianSpreadD1}(20)$.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_sma_months | 10 | locked | Moving average lookback in months (210 D1 days) |
| strategy_vol_lookback_days | 252 | locked | Trailing lookback days for realized volatility |
| strategy_atr_period | 20 | locked | ATR period for initial Stop Loss |
| strategy_atr_sl_mult | 3.0 | locked | ATR multiplier for initial Stop Loss |
| strategy_min_warmup_bars | 252 | locked | Minimum completed D1 bars before trading |
| strategy_enable_shorts | false | true/false | Enable short entries (default: long/cash) |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> ramework/V5_FRAMEWORK_DESIGN.md — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- Multi-asset D1 trend: FX pairs (EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX), Indices (GDAXI.DWX, NDX.DWX, SP500.DWX, UK100.DWX, WS30.DWX), Commodities (XAUUSD.DWX).

**Explicitly NOT for:** any symbol not registered in magic_numbers.csv for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) with monthly rebalance check |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 2 - 6 |
| Cadence note | Monthly rebalanced long/cash trend-following on D1 |
| Typical hold time | 30 - 180 days |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Trending / risk-on market environments |
| Win rate target (qualitative) | 40% - 55% |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** de348b4-0fa7-5be1-baa8-09e9089b67b7
**Pointer:** Wesley Gray, PhD, "Technical Analysis may actually work!", 2011-05-02, https://alphaarchitect.com/technical-analysis-may-actually-work/
**R1–R4 verdict (Q00):** all PASS — see rtifacts/cards_approved/QM5_9166_aa-vol-ma-timing.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | ,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by QM_FrameworkInit (EA_INPUT_RISK_MODE_MISMATCH).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-22 | Initial draft build and spec | Gemini drafting for Codex review |

