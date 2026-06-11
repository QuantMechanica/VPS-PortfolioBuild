# QM5_10077_gh-kai-setup91 - Strategy Spec

**EA ID:** QM5_10077
**Slug:** `gh-kai-setup91`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA watches a 9-period EMA on the M5 chart and stores the last EMA slope direction for the broker day. When the EMA flips from falling to rising during the entry window, it places a buy stop at the signal candle high with stop loss at that candle low. When the EMA flips from rising to falling, it places a sell stop at the signal candle low with stop loss at that candle high. Pending orders are cancelled on the opposite EMA flip or at the flat time; open positions use a fixed 1000-point take profit and are closed at the configured flat time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 9 | 1+ | EMA period applied to close price. |
| `strategy_entry_start_hhmm` | 900 | 0-2359 | Broker-time start of the entry window. |
| `strategy_entry_end_hhmm` | 1600 | 0-2359 | Broker-time end of the entry window. |
| `strategy_flat_hhmm` | 1730 | 0-2359 | Broker time to cancel pending orders and close open positions. |
| `strategy_take_profit_points` | 1000 | 1+ | Fixed take-profit distance from entry in symbol points. |
| `strategy_pending_expiry_minutes` | 480 | 1+ | Native pending-order expiry in minutes. |
| `strategy_reset_signal_daily` | true | true/false | Reset the stored prior EMA signal at each new broker day. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 target; liquid FX major with M5 OHLC and EMA data.
- `GBPUSD.DWX` - card R3 target; liquid FX major with M5 OHLC and EMA data.
- `USDJPY.DWX` - card R3 target; liquid FX major with M5 OHLC and EMA data.
- `XAUUSD.DWX` - card R3 target; liquid metal CFD with M5 OHLC and EMA data.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must use the registered `.DWX` universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Intraday, flat by 17:30 broker time |
| Expected drawdown profile | Breakout pending-stop losses are bounded by signal candle high/low distance and fixed framework risk. |
| Regime preference | EMA turn breakout during active session |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub source-code card
**Pointer:** `https://github.com/kaiovalente/mql5/blob/master/9_1.mq5`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10077_gh-kai-setup91.md`

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
| v1 | 2026-06-11 | Initial build from card | 07ce097c-5047-4e80-bb7d-567fbdbcec73 |
