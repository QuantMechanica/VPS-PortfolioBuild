# QM5_11047_roman-sar-break - Strategy Spec

**EA ID:** QM5_11047
**Slug:** roman-sar-break
**Source:** 9441393d-5ffc-5b43-87be-bd532110f204 (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades a fixed Parabolic SAR crossover against H1 bar open prices. On each new H1 bar it compares the latest completed bar and the prior completed bar: a long signal fires when SAR is above the latest completed open and below the prior completed open, while a short signal fires when SAR is below the latest completed open and above the prior completed open. Positions use an ATR(14) stop, a fixed reward/risk take-profit, optional break-even after 0.75R, opposite SAR/open cross exit, and a maximum hold of 24 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sar_step` | 0.02 | 0.01-0.03 | Parabolic SAR acceleration step. |
| `strategy_sar_maximum` | 0.20 | 0.10-0.30 | Parabolic SAR maximum acceleration. |
| `strategy_atr_period` | 14 | 5-50 | ATR lookback used for stop distance and volatility filter. |
| `strategy_atr_sl_mult` | 1.50 | 1.00-2.00 | Stop-loss distance as ATR multiple. |
| `strategy_tp_sl_ratio` | 1.00 | 0.75-1.25 | Take-profit distance as reward/risk multiple. |
| `strategy_max_bars_in_trade` | 24 | 12-48 | Time exit after this many H1 bars. |
| `strategy_atr_percentile_lookback` | 100 | 20-300 | ATR sample size for the low-volatility filter. |
| `strategy_atr_min_percentile` | 20.0 | 0-50 | Minimum ATR percentile required for entry. |
| `strategy_median_spread_points` | 20 | 1-200 | Baseline median spread in points for the spread filter. |
| `strategy_spread_limit_mult` | 2.00 | 1-5 | Maximum current spread as a multiple of baseline median spread. |
| `strategy_session_filter_enabled` | false | true/false | Enables the optional London plus New York session filter. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker hour when the optional session window starts. |
| `strategy_session_end_hour` | 21 | 0-23 | Broker hour when the optional session window ends. |
| `strategy_breakeven_enabled` | true | true/false | Enables optional break-even management. |
| `strategy_breakeven_rr` | 0.75 | 0.25-2.00 | Favorable R multiple that triggers break-even. |
| `strategy_breakeven_buffer_points` | 2 | 0-50 | Point buffer added beyond entry when moving SL to break-even. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source and card include EURUSD H1 in the tested FX basket.
- `GBPUSD.DWX` - source and card include GBPUSD H1 in the tested FX basket.
- `USDCHF.DWX` - source and card include USDCHF H1 in the tested FX basket.
- `USDJPY.DWX` - source and card include USDJPY H1 in the tested FX basket.

**Explicitly NOT for:**
- `SP500.DWX` - this card is an FX Parabolic SAR module, not an equity-index strategy.
- `XAUUSD.DWX` - not listed by the source card's R3 portable basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | Up to 24 H1 bars |
| Expected drawdown profile | Whipsaw-prone in range-bound periods, bounded by fixed ATR SL and TP. |
| Regime preference | trend-following / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9441393d-5ffc-5b43-87be-bd532110f204
**Source type:** article
**Pointer:** https://www.mql5.com/en/articles/350 and attachment `strategysar.mqh`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11047_roman-sar-break.md`

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
| v1 | 2026-06-07 | Initial build from card | e865d357-5096-40ee-9320-da12c20a8731 |
