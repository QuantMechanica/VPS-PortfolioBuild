# QM5_10788_tv-triple-ema-vol - Strategy Spec

**EA ID:** QM5_10788
**Slug:** tv-triple-ema-vol
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA is long-only. On each closed H4 bar it buys when EMA20 is above EMA50, EMA50 is above EMA200, the close is above EMA20, RSI(14) is between 50 and 70, and ATR(14) is between 30 and 100 percent of its fixed 100-bar ATR baseline. It exits at a fixed 5 percent stop, fixed 15 percent target, bearish EMA stack where EMA20 is below EMA50 and EMA50 is below EMA200, or RSI below 45.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_fast | 20 | 1-199 | Fast EMA in the triple-EMA stack. |
| strategy_ema_mid | 50 | 2-300 | Middle EMA in the triple-EMA stack. |
| strategy_ema_slow | 200 | 3-500 | Slow EMA trend filter. |
| strategy_rsi_period | 14 | 2-100 | RSI lookback used for entry and exit filters. |
| strategy_rsi_buy_min | 50.0 | 0-100 | Lower bound of the RSI buy zone. |
| strategy_rsi_buy_max | 70.0 | 0-100 | Upper bound of the RSI buy zone. |
| strategy_rsi_exit_below | 45.0 | 0-100 | Close long positions when RSI falls below this value. |
| strategy_vol_atr_period | 14 | 2-100 | ATR period for the deterministic volatility proxy. |
| strategy_vol_lookback_bars | 100 | 2-500 | ATR lookback used to normalize current ATR onto the volatility scale. |
| strategy_vol_min_norm | 30.0 | 0-100 | Minimum normalized volatility accepted for entry. |
| strategy_vol_max_norm | 100.0 | 0-200 | Maximum normalized volatility accepted for entry. |
| strategy_stop_mode | 0 | 0-1 | 0 uses fixed percent stop, 1 uses ATR multiple stop. |
| strategy_stop_fixed_pct | 5.0 | >0 | Fixed stop distance as percent of entry. |
| strategy_stop_atr_mult | 2.0 | >0 | ATR multiple when ATR stop mode is selected. |
| strategy_target_mode | 0 | 0-1 | 0 uses fixed percent target, 1 uses risk-multiple target. |
| strategy_target_fixed_pct | 15.0 | >0 | Fixed take-profit distance as percent of entry. |
| strategy_target_rr | 3.0 | >0 | Reward-risk multiple when RR target mode is selected. |
| strategy_exit_ema_enabled | true | true/false | Enables bearish triple-EMA stack exit. |
| strategy_exit_rsi_enabled | true | true/false | Enables RSI-below-45 exit. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid FX major with DWX OHLC data for EMA, RSI, and ATR.
- GBPUSD.DWX - liquid FX major with DWX OHLC data for the same trend and volatility rules.
- USDJPY.DWX - liquid FX major with DWX OHLC data and enough trend regimes for H4/D1 tests.
- XAUUSD.DWX - gold CFD port of the card's XAUUSD target.
- GDAXI.DWX - available DWX DAX proxy for the card's GER40.DWX target.
- NDX.DWX - Nasdaq 100 index CFD suitable for large-cap trend-following tests.
- WS30.DWX - Dow 30 index CFD suitable for large-cap trend-following tests.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | Multi-day |
| Expected drawdown profile | Low-to-moderate annual cadence with trend-regime drawdowns during range-bound periods. |
| Regime preference | Trend-following with momentum and volatility filter. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView protected-source strategy
**Pointer:** https://www.tradingview.com/script/vNko9qbN-Triple-EMA-RSI-Volatility-Index-by-Gozzs/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10788_tv-triple-ema-vol.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-05 | Initial build from card | 00fbc599-c1b2-4cf4-b81c-7543f49b3fa5 |
