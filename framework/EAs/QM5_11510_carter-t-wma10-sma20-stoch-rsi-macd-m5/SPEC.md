# QM5_11510_carter-t-wma10-sma20-stoch-rsi-macd-m5 - Strategy Spec

**EA ID:** QM5_11510
**Slug:** carter-t-wma10-sma20-stoch-rsi-macd-m5
**Source:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf (see sources/carter-thomas-20-forex-trend-following-systems)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades M5 trend-following entries when a WMA(10) and SMA(20) cross agrees with three momentum filters. A long entry requires WMA(10) crossing above SMA(20) within the last three closed M5 bars, Stochastic(10,6,6) K above D, RSI(28) above 50, and MACD(24,52,18) histogram above zero. A short entry uses the inverse conditions. Exits are broker-side 10-pip fixed stop loss, 1:1 take profit, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_wma_period | 10 | 1+ | Linear weighted moving average period for the cross trigger |
| strategy_sma_period | 20 | 1+ | Simple moving average period for the cross trigger |
| strategy_cross_lookback | 3 | 1+ | Closed-bar lookback window for a recent WMA/SMA cross |
| strategy_stoch_k | 10 | 1+ | Stochastic K period |
| strategy_stoch_d | 6 | 1+ | Stochastic D period |
| strategy_stoch_slowing | 6 | 1+ | Stochastic slowing parameter |
| strategy_rsi_period | 28 | 1+ | RSI period for the momentum filter |
| strategy_rsi_midline | 50.0 | 0-100 | RSI threshold separating long and short bias |
| strategy_macd_fast | 24 | 1+ | MACD fast EMA period |
| strategy_macd_slow | 52 | 1+ | MACD slow EMA period |
| strategy_macd_signal | 18 | 1+ | MACD signal period |
| strategy_sl_pips | 10 | 1+ | Fixed stop loss in pips |
| strategy_rr | 1.0 | greater than 0 | Take-profit multiple of initial risk |
| strategy_spread_cap_pips | 10 | 1+ | Entry spread cap in pips |

Framework-level inputs are documented in framework/V5_FRAMEWORK_DESIGN.md.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed M5 DWX forex instrument.
- GBPUSD.DWX - card-listed M5 DWX forex instrument.
- AUDUSD.DWX - card-listed M5 DWX forex instrument.

**Explicitly NOT for:**
- SP500.DWX - not in the card's forex symbol universe.
- NDX.DWX - not in the card's forex symbol universe.
- XAUUSD.DWX - not in the card's forex symbol universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none; the card's M15 MACD note is implemented as doubled MACD(24,52,18) on M5 |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via the V5 framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 300 |
| Typical hold time | Not specified in card frontmatter; expected intraday M5 holds bounded by 10-pip SL and 1R TP |
| Expected drawdown profile | Not specified in card frontmatter; fixed 10-pip stop produces frequent small-loss trend-filtered trades |
| Regime preference | Trend-following momentum |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Source type:** book
**Pointer:** Thomas Carter, Forex Trend Following Strategies: 20 Trend Following Systems, System 5; local source record sources/carter-thomas-20-forex-trend-following-systems
**R1-R4 verdict (Q00):** all R1-R4 PASS per artifacts/cards_approved/QM5_11510_carter-t-wma10-sma20-stoch-rsi-macd-m5.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by QM_FrameworkInit (EA_INPUT_RISK_MODE_MISMATCH).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | a3393cda-9adf-4e19-92a4-882f5c3ce225 |
