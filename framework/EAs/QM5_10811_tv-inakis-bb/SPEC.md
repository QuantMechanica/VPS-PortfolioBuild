# QM5_10811_tv-inakis-bb - Strategy Spec

**EA ID:** QM5_10811
**Slug:** tv-inakis-bb
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades Bollinger Band extremes on the chart timeframe. A long signal requires the last closed bar to close below the lower Bollinger Band after the prior bar was not below it, Stochastic %K below the oversold threshold, ADX above the trend-strength threshold, ATR divided by close above the minimum volatility ratio, and the higher-timeframe EMA trend bullish. A short signal mirrors the rule above the upper Bollinger Band with overbought Stochastic and bearish higher-timeframe EMA trend. Exits are the fixed ATR stop, fixed ATR target, framework Friday close, and the optional higher-timeframe trend-flip exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_bb_period | 20 | 2+ | Bollinger Band lookback period. |
| strategy_bb_deviation | 2.0 | >0 | Bollinger Band standard-deviation multiplier. |
| strategy_stoch_k_period | 14 | 2+ | Stochastic %K lookback. |
| strategy_stoch_d_period | 3 | 1+ | Stochastic %D smoothing. |
| strategy_stoch_slowing | 3 | 1+ | Stochastic slowing parameter. |
| strategy_stoch_oversold | 30.0 | 0-100 | Long-entry oversold threshold. |
| strategy_stoch_overbought | 70.0 | 0-100 | Short-entry overbought threshold. |
| strategy_adx_period | 14 | 2+ | ADX lookback period. |
| strategy_adx_threshold | 20.0 | 0+ | Minimum ADX required for entries. |
| strategy_atr_period | 14 | 2+ | ATR lookback for volatility filter and stop geometry. |
| strategy_min_atr_close_ratio | 0.0005 | 0+ | Minimum ATR divided by close for trade eligibility. |
| strategy_atr_sl_mult | 1.5 | >0 | ATR multiplier for stop loss. |
| strategy_atr_tp_mult | 3.0 | >0 | ATR multiplier for take profit. |
| strategy_htf_tf | PERIOD_H4 | M15-W1 | Higher timeframe used for EMA trend. |
| strategy_htf_ema_fast | 50 | 1+ | Fast EMA for higher-timeframe trend. |
| strategy_htf_ema_slow | 200 | 2+ | Slow EMA for higher-timeframe trend. |
| strategy_cooldown_bars | 3 | 0+ | Minimum chart bars between generated signals. |
| strategy_use_session_filter | false | true/false | Optional session gate, disabled for baseline. |
| strategy_session_start_hour | 0 | 0-23 | Broker-hour session start when session gate is enabled. |
| strategy_session_end_hour | 24 | 1-24 | Broker-hour session end when session gate is enabled. |
| strategy_max_spread_points | 0 | 0+ | Optional spread cap in points, disabled at 0. |
| strategy_trailing_enabled | false | true/false | Optional ATR trailing stop, disabled for P2 baseline. |
| strategy_trailing_atr_mult | 1.5 | >0 | ATR multiplier used when trailing is enabled. |
| strategy_exit_on_htf_flip | true | true/false | Close when the H4 EMA trend flips against the open position. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 primary FX basket member with full DWX OHLC support.
- GBPUSD.DWX - card R3 primary FX basket member with full DWX OHLC support.
- USDJPY.DWX - card R3 primary FX basket member with full DWX OHLC support.
- XAUUSD.DWX - canonical DWX gold symbol corresponding to card R3 `XAUUSD`.
- GDAXI.DWX - canonical DWX DAX symbol corresponding to card R3 `GER40.DWX`.
- NDX.DWX - card R3 US index basket member with DWX OHLC support.
- WS30.DWX - card R3 US index basket member with DWX OHLC support.

**Explicitly NOT for:**
- SPX500.DWX - unavailable phantom symbol; SP500.DWX is the only S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 and H1 |
| Multi-timeframe refs | H4 EMA fast/slow trend filter |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Intraday to multi-day, bounded by ATR stop or target |
| Expected drawdown profile | Filtered mean-reversion drawdowns in persistent one-way trends |
| Regime preference | Mean-reversion with higher-timeframe trend filter |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView strategy script
**Pointer:** https://www.tradingview.com/script/XmD0yhBf-Inakis-BB-Stoch-ATR-ADX-Strategy/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10811_tv-inakis-bb.md`

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
| v1 | 2026-06-05 | Initial build from card | 39235ad6-1d85-4745-8b38-eae8ab18af9d |
