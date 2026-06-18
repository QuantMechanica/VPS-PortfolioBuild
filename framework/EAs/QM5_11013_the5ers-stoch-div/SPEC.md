# QM5_11013_the5ers-stoch-div - Strategy Spec

**EA ID:** QM5_11013
**Slug:** the5ers-stoch-div
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see `sources/the5ers-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades H4 stochastic divergence at confirmed 2-left / 2-right swing points. A long signal requires the latest confirmed swing low to make a lower price low while Stochastic %K makes a higher low, with oversold confirmation and a bullish signal candle. A short signal mirrors that rule at confirmed swing highs with overbought confirmation and a bearish signal candle. Exits use 1.5R take profit, a stochastic mean-reversion exit, a failure close beyond the entry swing by 0.25 ATR, and a 24-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_stoch_k | 14 | 5-30 | Stochastic %K period. |
| strategy_stoch_d | 3 | 1-10 | Stochastic %D period. |
| strategy_stoch_slow | 3 | 1-10 | Stochastic slowing period. |
| strategy_swing_width | 2 | 1-5 | Left/right bars used to confirm swing pivots. |
| strategy_osc_lo | 30.0 | 10-40 | Latest swing-low %K threshold for long oversold state. |
| strategy_osc_hi | 70.0 | 60-90 | Latest swing-high %K threshold for short overbought state. |
| strategy_osc_cross_lo | 20.0 | 10-40 | Long cross-up level checked over the last three bars. |
| strategy_osc_cross_hi | 80.0 | 60-90 | Short cross-down level checked over the last three bars. |
| strategy_osc_exit_hi | 70.0 | 50-90 | Close long when %K closes above this level. |
| strategy_osc_exit_lo | 30.0 | 10-50 | Close short when %K closes below this level. |
| strategy_min_swing_gap | 5 | 1-30 | Minimum bars between divergence swing anchors. |
| strategy_max_swing_gap | 60 | 10-120 | Maximum bars between divergence swing anchors. |
| strategy_swing_scan_bars | 80 | 20-200 | Bounded lookback for confirmed swing discovery. |
| strategy_atr_period | 14 | 5-50 | ATR period for stop, failure exit, and volatility floor. |
| strategy_sl_atr_mult | 0.5 | 0.1-3.0 | ATR buffer beyond the entry swing for the initial stop. |
| strategy_tp_rr | 1.5 | 0.5-5.0 | Take-profit multiple of initial risk. |
| strategy_fail_atr_mult | 0.25 | 0.0-2.0 | Failure-exit buffer beyond the entry swing. |
| strategy_time_stop_bars | 24 | 1-100 | Maximum H4 bars to hold a trade. |
| strategy_atr_pctile_bars | 100 | 20-300 | ATR sample window for the flat-range filter. |
| strategy_atr_pctile | 20.0 | 0-50 | Reject entries below this ATR percentile. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card target; liquid FX major with H4 OHLC and stochastic data.
- GBPUSD.DWX - card target; liquid FX major with H4 OHLC and stochastic data.
- USDJPY.DWX - card target; liquid FX major with H4 OHLC and stochastic data.
- XAUUSD.DWX - card target; liquid metal CFD with H4 OHLC and stochastic data.
- GDAXI.DWX - DWX matrix-valid DAX proxy for card target GER40.DWX.

**Explicitly NOT for:**
- GER40.DWX - card target name is not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX symbol.
- Non-DWX symbols - research and backtest artifacts must use canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Up to 24 H4 bars by time stop; shorter on 1.5R, oscillator, or failure exits. |
| Expected drawdown profile | Mean-reversion drawdowns during persistent one-way trends. |
| Regime preference | Mean-reversion / momentum-reversal after divergence at confirmed swings. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** blog
**Pointer:** https://the5ers.com/stochastic-oscillator/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11013_the5ers-stoch-div.md`

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
| v1 | 2026-06-18 | Initial build from card | 4d0ba286-5409-45e8-9a91-442e162c59e0 |
