# QM5_1235_connors-rsi2 - Strategy Spec

**EA ID:** QM5_1235
**Slug:** connors-rsi2
**Source:** manual-owner-request-connors-rsi2
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades the Connors RSI-2 daily mean-reversion rule. On each new D1 bar it reads the prior closed daily close, SMA(200), RSI(2), and ATR(14). It buys when the close is above SMA(200) and RSI(2) is below 10, with a protective stop 3.0 ATR below entry. Optional shorts are enabled for FX and oil only: sell when the close is below SMA(200) and RSI(2) is above 90, with a protective stop 3.0 ATR above entry. Open trades exit when the prior close normalises through SMA(5), RSI(2) reaches the exit threshold, or 10 D1 bars have elapsed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_timeframe | PERIOD_D1 | D1 only | Base timeframe for all signal, stop, and exit reads. |
| strategy_rsi_period | 2 | >= 1 | RSI lookback used for entry and exit thresholds. |
| strategy_sma_trend_period | 200 | >= 1 | Long-term trend filter moving average. |
| strategy_sma_exit_period | 5 | >= 1 | Short moving average used for normalisation exits. |
| strategy_atr_period | 14 | >= 1 | ATR lookback for protective stop distance. |
| strategy_entry_rsi_long | 10.0 | 0-100 | Long entry threshold: RSI below this value. |
| strategy_entry_rsi_short | 90.0 | 0-100 | Short entry threshold: RSI above this value. |
| strategy_exit_rsi_long | 70.0 | 0-100 | Long exit threshold: RSI above this value. |
| strategy_exit_rsi_short | 30.0 | 0-100 | Short exit threshold: RSI below this value. |
| strategy_atr_stop_mult | 3.0 | > 0 | ATR multiple for initial protective stop. |
| strategy_max_hold_bars | 10 | >= 1 | Maximum holding time in D1 bars. |
| strategy_min_history_bars | 220 | >= 200 | Minimum effective history before entries are allowed. |
| strategy_enable_shorts | true | true / false | Enables the card's optional symmetric short rule. |
| strategy_use_sma_slope | false | true / false | Optional SMA(200) slope filter from the card. |
| strategy_sma_slope_bars | 20 | >= 1 | Lookback for optional SMA(200) slope check. |
| strategy_max_spread_points | 0.0 | >= 0 | Zero-safe current-spread cap; 0 disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - listed in the card universe; D1 RSI/SMA/ATR data available.
- GBPUSD.DWX - listed in the card universe; D1 RSI/SMA/ATR data available.
- USDJPY.DWX - listed in the card universe; D1 RSI/SMA/ATR data available.
- AUDUSD.DWX - listed in the card universe; D1 RSI/SMA/ATR data available.
- USDCAD.DWX - listed in the card universe; D1 RSI/SMA/ATR data available.
- NZDUSD.DWX - listed in the card universe; D1 RSI/SMA/ATR data available.
- XAUUSD.DWX - listed in the card universe; metal mean-reversion target.
- XTIUSD.DWX - listed in the card universe; oil commodity mean-reversion target.
- NDX.DWX - listed in the card universe; liquid US index target.
- WS30.DWX - listed in the card universe; liquid US index target.
- GDAXI.DWX - listed in the card universe; liquid DAX index target.
- UK100.DWX - listed in the card universe; liquid FTSE index target.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no canonical DWX tester data is available.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_timeframe)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | 1-10 D1 bars |
| Expected drawdown profile | Mean-reversion pullback strategy with ATR-bounded single-position risk. |
| Regime preference | Long-term trend with short-term mean reversion. |
| Win rate target (qualitative) | medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** manual-owner-request-connors-rsi2
**Source type:** OWNER / book family
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1235_connors-rsi2.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1235_connors-rsi2.md`

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
| v1 | 2026-06-18 | Initial build from card | 3def51b1-553e-4070-8f0e-2a71895512b8 |
