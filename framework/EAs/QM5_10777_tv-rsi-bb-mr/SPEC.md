# QM5_10777_tv-rsi-bb-mr - Strategy Spec

**EA ID:** QM5_10777
**Slug:** tv-rsi-bb-mr
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView script pointer below)
**Author of this spec:** Codex
**Last revised:** 2026-06-01

---

## 1. Strategy Logic

This EA trades M15 mean reversion after an exhaustion move. It opens long when RSI(19) is below 20 and the last closed bar is below the lower Bollinger Band(20, 1.5). It opens short when RSI(19) is above 72 and the last closed bar is above the upper Bollinger Band(20, 1.5). It exits on the opposite signal, a 2.0 ATR(14) safety stop, the 96-bar time stop, or the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_rsi_period | 19 | 2+ | RSI lookback on the current chart timeframe. |
| strategy_rsi_long_level | 20.0 | 0-50 | Long threshold for oversold exhaustion. |
| strategy_rsi_short_level | 72.0 | 50-100 | Short threshold for overbought exhaustion. |
| strategy_bb_period | 20 | 2+ | Bollinger Band lookback on the current chart timeframe. |
| strategy_bb_deviation | 1.5 | >0 | Bollinger standard deviation multiplier. |
| strategy_atr_period | 14 | 2+ | ATR lookback for safety stop placement. |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for the hard safety stop. |
| strategy_time_stop_bars | 96 | 0+ | Maximum hold in bars; 0 disables the time stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 FX basket member with DWX matrix support.
- GBPUSD.DWX - card R3 FX basket member with DWX matrix support.
- USDJPY.DWX - card R3 FX basket member with DWX matrix support.
- XAUUSD.DWX - card R3 metals member normalized from `XAUUSD` to the matrix symbol.
- GDAXI.DWX - DAX exposure ported from card `GER40.DWX` because `GER40.DWX` is not in `dwx_symbol_matrix.csv`.
- NDX.DWX - card R3 index basket member with DWX matrix support.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX for DAX exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | M15 bars until opposite signal, safety stop, or 96-bar time stop |
| Expected drawdown profile | Selective mean reversion can suffer during runaway trends; ATR safety stop bounds per-trade loss. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView protected-source public script page
**Pointer:** TradingView script `RSI Mean Reversion`, author handle `truenordiccapital`, Mar 14, https://www.tradingview.com/script/2qjlEzOH-RSI-Mean-Reversion/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10777_tv-rsi-bb-mr.md`

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
| v1 | 2026-06-01 | Initial build from card | c7a2c553-c313-4cc5-9729-a5f0e503df1d |
