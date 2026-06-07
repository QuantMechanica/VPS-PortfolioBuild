# QM5_11134_clenow-50d-break - Strategy Spec

**EA ID:** QM5_11134
**Slug:** `clenow-50d-break`
**Source:** `f2c83ece-d932-5e08-a923-1f63034348ee` (see `strategy-seeds/sources/f2c83ece-d932-5e08-a923-1f63034348ee/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA evaluates completed D1 bars only. It opens a long position when SMA(50) is above SMA(100) and the latest completed D1 close is the highest close of the last 50 completed D1 bars. It opens a short position when SMA(50) is below SMA(100) and the latest completed D1 close is the lowest close of the last 50 completed D1 bars. Open positions close at market when a completed D1 close breaches a 3.0 x ATR(20) close-based trail from the best close since entry; the emergency hard stop is set at entry at 3.5 x ATR(20).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_breakout_lookback | 50 | 40-60 | Completed D1 closes used for the breakout high or low. |
| strategy_trend_fast_sma | 50 | 40-50 | Fast SMA period for the trend filter. |
| strategy_trend_slow_sma | 100 | 100-150 | Slow SMA period for the trend filter. |
| strategy_atr_period | 20 | 14-30 | D1 ATR period used for stop sizing and trailing exit distance. |
| strategy_trail_atr_mult | 3.0 | 2.5-3.5 | ATR multiple for the close-based trailing exit. |
| strategy_stop_atr_mult | 3.5 | 3.0-4.0 | ATR multiple for the emergency hard stop from entry. |
| strategy_warmup_bars | 120 | 120+ | Minimum completed D1 bars required before entries. |
| strategy_spread_median_days | 60 | 1-120 | D1 spread samples used for the median spread filter. |
| strategy_spread_median_mult | 2.0 | 1.0-5.0 | Maximum current spread as a multiple of the 60D median spread. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major suited to diversified trend following.
- `GBPUSD.DWX` - liquid FX major suited to diversified trend following.
- `USDJPY.DWX` - liquid FX major suited to diversified trend following.
- `AUDUSD.DWX` - liquid FX major suited to diversified trend following.
- `NDX.DWX` - major US equity index CFD for index trend exposure.
- `WS30.DWX` - major US equity index CFD for index trend exposure.
- `XAUUSD.DWX` - gold CFD for metals trend exposure.
- `XTIUSD.DWX` - crude oil CFD for energy trend exposure.

**Explicitly NOT for:**
- Non-`.DWX` symbols - the V5 backtest framework requires canonical DWX symbols.
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - the broker/custom-symbol matrix is the build-time universe.

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
| Trades / year / symbol | 8 |
| Typical hold time | days to weeks |
| Expected drawdown profile | Medium-high trend-following drawdowns with infrequent large winners. |
| Regime preference | breakout / trend |
| Win rate target (qualitative) | low to medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `f2c83ece-d932-5e08-a923-1f63034348ee`
**Source type:** book / public rules page
**Pointer:** Andreas F. Clenow, *Following the Trend*, Wiley, 2012; public rules page `https://www.followingthetrend.com/the-trading-system/trading-system-rules/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11134_clenow-50d-break.md`

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
| v1 | 2026-06-07 | Initial build from card | 062f5775-031d-43d1-8139-e1b16d96f45e |
