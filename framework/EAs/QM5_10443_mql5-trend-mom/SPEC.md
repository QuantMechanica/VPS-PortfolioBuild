# QM5_10443_mql5-trend-mom - Strategy Spec

**EA ID:** QM5_10443
**Slug:** `mql5-trend-mom`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA evaluates only the last closed candle. It opens long when the close is above EMA50 and EMA200, RSI is inside the bullish range, and Stochastic %K crosses above %D during either the configured London or New York broker-time session. It opens short when the close is below EMA50 and EMA200, RSI is inside the bearish range, and Stochastic %K crosses below %D during the configured sessions. Exits are the fixed stop loss and fixed take profit, with the framework Friday close still active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast` | 50 | `1+` | Fast trend EMA used for the close-above/below trend filter. |
| `strategy_ema_slow` | 200 | `1+` | Slow trend EMA used for the close-above/below trend filter. |
| `strategy_rsi_period` | 14 | `1+` | RSI lookback period. |
| `strategy_rsi_bull_min` | 50.0 | `0-100` | Lower RSI bound for long entries. |
| `strategy_rsi_bull_max` | 70.0 | `0-100` | Upper RSI bound for long entries. |
| `strategy_rsi_bear_min` | 30.0 | `0-100` | Lower RSI bound for short entries. |
| `strategy_rsi_bear_max` | 50.0 | `0-100` | Upper RSI bound for short entries. |
| `strategy_stoch_k` | 5 | `1+` | Stochastic K period. |
| `strategy_stoch_d` | 3 | `1+` | Stochastic D period. |
| `strategy_stoch_slowing` | 3 | `1+` | Stochastic slowing period. |
| `strategy_sl_pips` | 50 | `1+` | Fixed stop distance; 50 pips equals 500 points on 5-digit FX. |
| `strategy_tp_pips` | 100 | `1+` | Fixed take-profit distance; 100 pips equals 1000 points on 5-digit FX. |
| `strategy_session_filter_enabled` | true | `true/false` | Enables the London/New York broker-time session filter. |
| `strategy_london_start_hour_broker` | 8 | `0-23` | London session start hour in broker-server time. |
| `strategy_london_end_hour_broker` | 12 | `0-23` | London session end hour in broker-server time. |
| `strategy_ny_start_hour_broker` | 13 | `0-23` | New York session start hour in broker-server time. |
| `strategy_ny_end_hour_broker` | 17 | `0-23` | New York session end hour in broker-server time. |
| `strategy_ma_deadband_points` | 0.0 | `0+` | Optional deadband around EMA trend checks, in points. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; major FX pair with DWX custom symbol coverage.
- `GBPUSD.DWX` - card target; major FX pair with DWX custom symbol coverage.
- `USDJPY.DWX` - card target; major FX pair with DWX custom symbol coverage.
- `GDAXI.DWX` - DAX-equivalent DWX custom symbol used because `GER40.DWX` is not in the matrix.
- `XAUUSD.DWX` - card target; gold custom symbol with DWX coverage.

**Explicitly NOT for:**
- `GER40.DWX` - card name is not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Non-DWX symbols - research and backtest artifacts must keep the `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` and `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | intraday to multi-hour |
| Expected drawdown profile | controlled by fixed SL/TP and one open position per magic. |
| Regime preference | trend / momentum-confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/68512`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10443_mql5-trend-mom.md`

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
| v1 | 2026-06-13 | Initial build from card | 118020f2-271c-46e0-88ad-8d4236272b09 |
