# QM5_11004_the5ers-ema-rsi-pullback - Strategy Spec

**EA ID:** QM5_11004
**Slug:** the5ers-ema-rsi-pullback
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see `sources/the5ers-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades a short-term EMA trend pullback on M15 forex bars. It buys when EMA(9) is above EMA(20), price is above EMA(20), and RSI(14) recovers up through 30 after being oversold on the prior closed bar. It sells the symmetric setup when EMA(9) is below EMA(20), price is below EMA(20), and RSI(14) recovers down through 70 after being overbought. Exits are the fixed 20-pip stop, fixed 40-pip take profit, an adverse EMA(9/20) cross, a 32-bar time stop, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_fast_period | 9 | >= 1 | Fast EMA period for trend state and adverse cross exit. |
| strategy_ema_slow_period | 20 | > fast period | Slow EMA period for trend and price-position filter. |
| strategy_rsi_period | 14 | >= 2 | RSI lookback period. |
| strategy_rsi_lo | 30.0 | 1-50 | Long trigger threshold; RSI must recover up through this level. |
| strategy_rsi_hi | 70.0 | 50-99 | Short trigger threshold; RSI must recover down through this level. |
| strategy_sl_pips | 20 | >= 1 | Fixed stop-loss distance in pips. |
| strategy_tp_pips | 40 | >= 1 | Fixed take-profit distance in pips. |
| strategy_time_stop_bars | 32 | >= 1 | Maximum holding period in base-timeframe bars. |
| strategy_session_start_h | 6 | 0-23 | Broker-time entry session start hour, inclusive. |
| strategy_session_end_h | 20 | 1-24 | Broker-time entry session end hour, exclusive. |
| strategy_spread_pct_of_stop | 10.0 | >= 0 | Entry is skipped when modeled spread exceeds this percentage of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - major FX pair with DWX M15 OHLC coverage and standard EMA/RSI applicability.
- GBPUSD.DWX - major FX pair with DWX M15 OHLC coverage and standard EMA/RSI applicability.
- USDJPY.DWX - major FX pair with DWX M15 OHLC coverage and pip conversion handled by the framework.
- AUDUSD.DWX - major FX pair with DWX M15 OHLC coverage and standard EMA/RSI applicability.
- EURJPY.DWX - major FX cross with DWX M15 OHLC coverage and pip conversion handled by the framework.

**Explicitly NOT for:**
- SP500.DWX - index CFD, outside the card's forex-specific source and target-symbol list.
- XAUUSD.DWX - metal CFD, outside the card's forex-major/cross target universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | intraday, up to 32 M15 bars |
| Expected drawdown profile | fixed 20-pip per-trade stop with framework fixed-risk sizing |
| Regime preference | trend pullback |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** blog
**Pointer:** https://the5ers.com/short-term-trading-strategies/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11004_the5ers-ema-rsi-pullback.md`

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
| v1 | 2026-06-18 | Initial build from card | f25af024-3adc-45da-9257-ceeb25aca7a3 |
