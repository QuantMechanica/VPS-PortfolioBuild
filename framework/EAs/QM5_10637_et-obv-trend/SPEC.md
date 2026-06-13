# QM5_10637_et-obv-trend - Strategy Spec

**EA ID:** QM5_10637
**Slug:** `et-obv-trend`
**Source:** `cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. It enters long when price is above the long trend SMA, the pullback SMA is above the mid trend SMA, price is within one ATR of the pullback SMA while still above the mid SMA, ROC(6) crosses above zero, OBV over 25 D1 bars slopes upward, and the latest swing highs do not show bearish MACD-histogram divergence. It enters short with mirrored conditions. Exits occur on MACD histogram zero-line cross against the position, opposite ROC(6) zero cross, or after 20 D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pullback_sma_period` | 20 | 2+ | SMA used as the lower trend-area pullback reference. |
| `strategy_trend_mid_sma` | 50 | 2+ | Mid trend SMA; pullback SMA must be above or below this by side. |
| `strategy_trend_long_sma` | 100 | 2+ | Long trend SMA; close must be above or below this by side. |
| `strategy_atr_period` | 14 | 2+ | ATR period for pullback distance, volatility filter, and stop buffer. |
| `strategy_pullback_atr_mult` | 1.0 | >0 | Maximum distance from pullback SMA in ATR units. |
| `strategy_macd_fast` | 12 | 1+ | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | > fast | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 1+ | MACD signal EMA period. |
| `strategy_divergence_lookback` | 20 | 6+ | D1 bars searched for the MACD divergence veto. |
| `strategy_roc_period` | 6 | 1+ | ROC proxy period for the proprietary Hausse Index. |
| `strategy_obv_slope_window` | 25 | 2+ | D1 bars used for OBV slope confirmation. |
| `strategy_swing_lookback` | 10 | 2+ | Closed D1 bars used for structural stop reference. |
| `strategy_swing_atr_buffer` | 0.50 | >=0 | ATR buffer added beyond the structural stop. |
| `strategy_atr_percentile_bars` | 252 | 20+ | Prior D1 ATR samples used for high-volatility exclusion. |
| `strategy_atr_percentile_max` | 0.90 | 0-1 | Skip entries when ATR rank is above this percentile. |
| `strategy_max_spread_stop_pct` | 0.10 | >0 | Maximum spread as a share of stop distance. |
| `strategy_time_exit_bars` | 20 | 1+ | Maximum D1 holding period. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Liquid US large-cap growth index proxy from the card basket.
- `SP500.DWX` - S&P 500 custom symbol, valid for backtest registration.
- `GDAXI.DWX` - Matrix-verified DAX equivalent for the card's `GER40.DWX`.
- `EURUSD.DWX` - Liquid FX major included in the card basket.
- `XAUUSD.DWX` - Gold CFD included in the card basket.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; registered as `GDAXI.DWX`.
- `SPX500.DWX` - Not a canonical DWX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `20` |
| Typical hold time | Up to 20 D1 bars by time exit. |
| Expected drawdown profile | Trend-continuation with ATR stop distance and no averaging. |
| Regime preference | Trend continuation with pullback and OBV confirmation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/my-profitable-trading-strategy.64148/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10637_et-obv-trend.md`

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
| v1 | 2026-06-13 | Initial build from card | feab015b-e633-41b1-ba60-a9c4ca3f4adc |
