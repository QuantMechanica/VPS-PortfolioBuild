# QM5_11048_cs2011-macd - Strategy Spec

**EA ID:** QM5_11048
**Slug:** cs2011-macd
**Source:** 9441393d-5ffc-5b43-87be-bd532110f204
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades a fixed MACD main-line and signal-line cross on H1. It opens long when MACD main crosses above signal on the completed bar, and opens short when MACD main crosses below signal on the completed bar. Optional zero-line confirmation can require long signals above zero and short signals below zero, but this is disabled by default for P2. Positions close on an opposite MACD cross, by protective SL/TP, or after the configured maximum number of H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_timeframe | PERIOD_H1 | M1-MN1 | Base timeframe for MACD, ATR, filters, and hold-time bars |
| strategy_macd_fast | 12 | >0 and < slow | MACD fast EMA period |
| strategy_macd_slow | 26 | > fast | MACD slow EMA period |
| strategy_macd_signal | 9 | >0 | MACD signal SMA period |
| strategy_zero_confirm | false | true/false | Require MACD main above zero for long and below zero for short |
| strategy_atr_period | 14 | >0 | ATR period used for volatility filter and SL distance |
| strategy_sl_atr_mult | 1.5 | >0 | Stop loss distance in ATR multiples |
| strategy_tp_sl_ratio | 1.0 | >0 | Take profit as a multiple of initial stop distance |
| strategy_max_bars_in_trade | 24 | >=0 | Time exit after this many base-timeframe bars, with 0 disabling it |
| strategy_enable_breakeven | true | true/false | Move SL to entry after the configured R trigger |
| strategy_breakeven_trigger_r | 0.75 | >0 | Break-even trigger in initial-risk units |
| strategy_atr_percentile_bars | 100 | >=20 | Lookback used for the ATR percentile filter |
| strategy_min_atr_percentile | 20.0 | 0-100 | Minimum ATR percentile allowed for entries |
| strategy_spread_lookback_bars | 480 | >=20 | Lookback used for median historical spread |
| strategy_spread_median_mult | 2.0 | >0 | Current spread must be at most this multiple of median spread |
| strategy_session_filter | false | true/false | Enable optional London plus NY session gate |
| strategy_session_start_hour | 7 | 0-23 | Broker hour when optional session gate starts |
| strategy_session_end_hour | 21 | 0-23 | Broker hour when optional session gate ends |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 primary FX basket symbol with DWX H1 data.
- GBPUSD.DWX - Card R3 primary FX basket symbol with DWX H1 data.
- AUDUSD.DWX - Card R3 primary FX basket symbol with DWX H1 data.
- USDJPY.DWX - Card R3 primary FX basket symbol with DWX H1 data.

**Explicitly NOT for:**
- Non-DWX symbols - research and backtest artifacts must use the canonical `.DWX` names.
- Non-FX index and commodity symbols - the card scopes this MACD baseline to the listed FX basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | Up to 24 H1 bars by default |
| Expected drawdown profile | Whipsaw-sensitive in low-volatility ranges; bounded by fixed ATR SL and 1R TP |
| Regime preference | trend-following momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9441393d-5ffc-5b43-87be-bd532110f204
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/611
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11048_cs2011-macd.md`

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
| v1 | 2026-06-07 | Initial build from card | 3e87e0c5-4c3f-4221-afe4-6d2450edc571 |
