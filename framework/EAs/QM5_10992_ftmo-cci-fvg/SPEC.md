# QM5_10992_ftmo-cci-fvg - Strategy Spec

**EA ID:** QM5_10992
**Slug:** ftmo-cci-fvg
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades H1 continuation after price is aligned with EMA(50), CCI(20) has crossed the zero line in the trend direction within the last three closed bars, and a recent three-candle fair value gap is present. It buys after a bullish FVG retrace into the upper half closes back above the gap midpoint, and sells after a bearish FVG retrace into the lower half closes back below the gap midpoint. The stop is placed beyond the FVG boundary by 0.35 ATR(14), the target is 2.0R, the stop moves to breakeven after 1.0R, and positions close early on a CCI zero-line reversal or after 36 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_timeframe | PERIOD_H1 | H1 intended | Signal timeframe from the card. |
| strategy_cci_period | 20 | 2-200 | CCI lookback for trend confirmation and early exit. |
| strategy_ema_period | 50 | 2-300 | EMA trend filter. |
| strategy_atr_period | 14 | 2-200 | ATR lookback for FVG height filter and stop buffer. |
| strategy_cci_cross_lookback | 3 | 1-20 | Number of closed bars in which CCI must have crossed zero. |
| strategy_fvg_lookback_bars | 8 | 3-50 | Recent closed bars scanned for a three-candle FVG. |
| strategy_fvg_min_atr_mult | 0.25 | 0.01-5.0 | Minimum FVG height as ATR multiple. |
| strategy_fvg_max_atr_mult | 1.50 | 0.01-10.0 | Maximum FVG height as ATR multiple. |
| strategy_sl_atr_mult | 0.35 | 0.0-5.0 | ATR buffer beyond the FVG boundary for SL. |
| strategy_rr | 2.0 | 0.1-10.0 | Take-profit multiple of initial risk. |
| strategy_max_hold_bars | 36 | 1-500 | Time exit in H1 bars. |
| strategy_spread_median_bars | 20 | 1-200 | Median historical spread lookback. |
| strategy_spread_median_mult | 1.5 | 0.1-10.0 | Maximum current spread versus median spread. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed liquid FX major with DWX H1 OHLC and spread history.
- GBPUSD.DWX - Card-listed liquid FX major with DWX H1 OHLC and spread history.
- XAUUSD.DWX - Card-listed gold market suitable for CCI/EMA/FVG continuation tests.
- NDX.DWX - Card-listed liquid index CFD proxy suitable for H1 continuation tests.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not registered because DWX data availability is required.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Intraday to 36 H1 bars |
| Expected drawdown profile | Moderate trend-continuation drawdowns controlled by fixed 1R stop and 2R target. |
| Regime preference | Trend continuation with pullback into fair value gap. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** article
**Pointer:** FTMO Academy, CCI: Technical Indicator, 2025, https://academy.ftmo.com/lesson/cci-technical-indicator/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10992_ftmo-cci-fvg.md`

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
| v1 | 2026-06-07 | Initial build from card | e950f311-0472-4c68-8acb-c2f2a98ef716 |
