# QM5_10322_realized-moments - Strategy Spec

**EA ID:** QM5_10322
**Slug:** realized-moments
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9 (see `strategy-seeds/sources/fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

At the weekly entry window, the EA reads the configured H1 basket and computes five-trading-day realized volatility, skewness, and kurtosis from closed intraday returns. Each symbol receives a composite score equal to z(skewness) + z(kurtosis) + 0.5 * z(volatility). The chart symbol trades long when it is in the top quartile and at least 0.5 basket standard deviations above the median score, or short when it is in the bottom quartile and at least 0.5 standard deviations below the median. Positions use a 1.25 * ATR(14, D1) stop and close at the next weekly rebalance or the max-hold guard.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_moment_tf | PERIOD_H1 | M30-H1 intended | Intraday timeframe used for realized moments. |
| strategy_moment_bars | 120 | >= 41 | Closed intraday bars used for five-trading-day returns. |
| strategy_min_intraday_bars | 40 | >= 1 | Minimum complete intraday bars required per symbol. |
| strategy_vol_z_coef | 0.50 | >= 0 | Coefficient on realized-volatility z-score. |
| strategy_median_score_buffer_sd | 0.50 | >= 0 | Required distance from basket median in score standard deviations. |
| strategy_quantile_frac | 0.25 | 0.05-0.50 | Top/bottom basket fraction eligible to trade. |
| strategy_stop_tf | PERIOD_D1 | D1 intended | Timeframe for ATR stop placement. |
| strategy_atr_period | 14 | >= 1 | ATR period for stop placement. |
| strategy_atr_sl_mult | 1.25 | > 0 | ATR stop-loss multiplier. |
| strategy_entry_day_of_week | 1 | 0-6 | Broker day for weekly entry, Monday = 1. |
| strategy_entry_hour_broker | 0 | 0-23 | First broker hour of the weekly entry window. |
| strategy_entry_window_hours | 4 | >= 1 | Number of broker hours after entry hour where entries can fire. |
| strategy_exit_day_of_week | 5 | 0-6 | Broker day for weekly rebalance exit, Friday = 5. |
| strategy_exit_hour_broker | 20 | 0-23 | Broker hour for strategy weekly exit before framework Friday close. |
| strategy_max_hold_days | 7 | >= 1 | Failsafe maximum holding period. |
| strategy_spread_min_samples | 20 | >= 1 | Minimum spread observations for percentile filter. |
| strategy_spread_percentile | 80.0 | 0-100 | Maximum allowed current spread percentile. |

---

## 3. Symbol Universe

**Designed for:**
- WS30.DWX - Dow 30 CFD from the card's DWX index basket.
- NDX.DWX - Nasdaq 100 CFD from the card's DWX index basket.
- GDAXI.DWX - DAX CFD port for the card's GER40 reference; GER40.DWX is not in the DWX matrix.
- XAUUSD.DWX - Gold CFD from the card's metals basket.
- EURUSD.DWX - Major FX pair from the card's major FX basket.
- GBPUSD.DWX - Major FX pair from the card's major FX basket.
- USDJPY.DWX - Major FX pair from the card's major FX basket.
- USDCHF.DWX - Major FX pair from the card's major FX basket.
- USDCAD.DWX - Major FX pair from the card's major FX basket.
- AUDUSD.DWX - Major FX pair from the card's major FX basket.
- NZDUSD.DWX - Major FX pair from the card's major FX basket.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.
- SP500.DWX - Not named by this card's R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | H1 basket returns plus D1 ATR stop through framework helper on the chart symbol |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 52 |
| Typical hold time | Up to one week |
| Expected drawdown profile | Weekly ATR-defined loss cap with one open position per magic and symbol |
| Regime preference | Cross-sectional realized-moment momentum |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3702835
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10322_realized-moments.md`

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
| v1 | 2026-06-12 | Initial build from card | 75646717-99b0-4df1-b494-0cf49f147e3d |
