# QM5_10896_brown-ema-trend - Strategy Spec

**EA ID:** QM5_10896
**Slug:** brown-ema-trend
**Source:** 6facee24-8a58-5bbf-88e9-38d44291db50 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades Brown's EMA trend-bounce continuation on M15. A long setup requires the close, EMA(10), and Bollinger middle line to be above EMA(50), a closed-bar pullback touch of EMA(10), Bollinger middle, or EMA(50) without closing below EMA(50), and confirmation from MACD histogram improvement, RSI holding above 50, and a Slow Stochastic bullish cross. A short setup mirrors those rules below EMA(50). Entries are market orders on the next bar; exits are fixed by SL, TP, framework Friday close, or a 16-bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_signal_tf | PERIOD_M15 | M1-MN1 | Timeframe used for all strategy indicator and OHLC reads. |
| strategy_fast_ema_period | 10 | >0 | Fast EMA used for trend bias and pullback support or resistance. |
| strategy_slow_ema_period | 50 | > fast EMA | Slow EMA trend filter and deepest pullback line. |
| strategy_bb_period | 20 | >0 | Bollinger Band period for the middle-line pullback test. |
| strategy_bb_deviation | 2.0 | >0 | Bollinger Band deviation parameter. |
| strategy_macd_fast | 12 | >0 | MACD fast EMA period. |
| strategy_macd_slow | 26 | > fast MACD | MACD slow EMA period. |
| strategy_macd_signal | 9 | >0 | MACD signal smoothing period. |
| strategy_rsi_period | 14 | >0 | RSI period. |
| strategy_rsi_midline | 50.0 | 0-100 | RSI confirmation threshold. |
| strategy_stoch_k | 5 | >0 | Slow Stochastic K period. |
| strategy_stoch_d | 3 | >0 | Slow Stochastic D period. |
| strategy_stoch_slowing | 3 | >0 | Slow Stochastic slowing period. |
| strategy_atr_period | 14 | >0 | ATR period for minimum SL and variable TP. |
| strategy_sl_atr_min_mult | 0.8 | >0 | Minimum stop distance as a multiple of ATR. |
| strategy_tp_atr_mult | 1.2 | >0 | Variable take-profit distance as a multiple of ATR. |
| strategy_stop_buffer_pips | 5.0 | >0 | Buffer behind the touched support or resistance line. |
| strategy_fixed_tp_pips | 20.0 | >0 | Fixed take-profit floor in pips. |
| strategy_spread_sl_frac | 0.20 | 0-1 | Maximum spread as a fraction of planned SL distance. |
| strategy_max_hold_bars | 16 | >0 | Time exit after this many signal-timeframe bars. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 forex basket member with DWX M15 data available.
- GBPUSD.DWX - card R3 forex basket member with DWX M15 data available.
- USDJPY.DWX - card R3 forex basket member with DWX M15 data available.

**Explicitly NOT for:**
- Index and commodity `.DWX` symbols - the card specifies a forex trend-pullback basket only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | Intraday, capped at 16 M15 bars or about 4 hours |
| Expected drawdown profile | Medium, because entries wait for trend continuation confirmation but stops are close to pullback support or resistance. |
| Regime preference | Trend-pullback continuation with momentum confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Source type:** book
**Pointer:** Jim Brown, FOREX TRADING the Basics Explained, local PDF file:///G:/My%20Drive/QuantMechanica/Ebook/PDF%20resources/FOREX%20TRADING%20the%20Basics%20Explai%20-%20Jim%20Brown.pdf, pp. 25-27, 32
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10896_brown-ema-trend.md`

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
| v1 | 2026-06-14 | Initial build from card | 60bc3a3d-19eb-4919-b9c8-86376106719e |
