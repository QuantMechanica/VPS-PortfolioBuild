# QM5_10997_the5ers-ema-rsi-stoch - Strategy Spec

**EA ID:** QM5_10997
**Slug:** the5ers-ema-rsi-stoch
**Source:** 1d445184-7c47-57da-9856-a123682a932d
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades H1 EMA crossover momentum on forex majors. It opens long when EMA(5) crosses above EMA(10) on the last closed bar, RSI(14) is above 50, and Stochastic %K(14,3,3) is rising but still below 80. It opens short on the symmetric inverse: EMA(5) crosses below EMA(10), RSI(14) is below 50, and %K is falling but still above 20. Positions exit on the reverse EMA cross, an RSI close back through 50, the 48-bar time stop, the ATR catastrophic stop, or the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_fast_period | 5 | 2-20 | Fast EMA period used for crossover trigger. |
| strategy_ema_slow_period | 10 | 3-50 | Slow EMA period used for crossover trigger. |
| strategy_rsi_period | 14 | 2-50 | RSI lookback period. |
| strategy_rsi_level | 50.0 | 1.0-99.0 | RSI directional threshold for long/short state. |
| strategy_stoch_k_period | 14 | 2-50 | Stochastic %K period. |
| strategy_stoch_d_period | 3 | 1-20 | Stochastic %D period. |
| strategy_stoch_slowing | 3 | 1-20 | Stochastic slowing period. |
| strategy_stoch_overbought | 80.0 | 50.0-100.0 | Long entries require %K below this cap. |
| strategy_stoch_oversold | 20.0 | 0.0-50.0 | Short entries require %K above this floor. |
| strategy_atr_period | 14 | 2-100 | ATR period for initial stop distance. |
| strategy_sl_atr_mult | 2.0 | 0.5-10.0 | Initial stop distance as ATR multiple. |
| strategy_time_stop_bars | 48 | 1-240 | Maximum hold in H1 bars. |
| strategy_spread_pct_of_stop | 15.0 | 0.0-100.0 | Blocks only a genuinely wide spread above this percent of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid DWX forex major matching the source's generic MetaTrader FX setup.
- GBPUSD.DWX - liquid DWX forex major matching the crossover and oscillator mechanics.
- USDJPY.DWX - liquid DWX forex major with adequate H1 history for two-sided testing.
- AUDUSD.DWX - liquid DWX forex major included in the approved card basket.
- EURJPY.DWX - liquid DWX FX cross included in the approved card basket.

**Explicitly NOT for:**
- SP500.DWX - index exposure is outside the forex-oriented source and approved R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | up to 48 H1 bars |
| Expected drawdown profile | momentum crossover drawdowns during range-bound markets |
| Regime preference | trend / momentum-confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** article
**Pointer:** https://the5ers.com/simple-trading-strategy/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10997_the5ers-ema-rsi-stoch.md`

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
| v1 | 2026-06-26 | Initial build from card | e1e2928d-84e1-4ff3-8cf2-1227ae6c447f |
