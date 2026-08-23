# QM5_9730_bandy-weekly-rsi-extreme-d1-trigger-mr-index — Strategy Spec

**EA ID:** QM5_9730
**Slug:** bandy-weekly-rsi-extreme-d1-trigger-mr-index
**Source:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Author of this spec:** Gemini
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

The EA implements Howard Bandy's multi-timeframe mean-reversion strategy combining a weekly RSI setup with a daily RSI trigger.
On each closed D1 bar, it evaluates the 3-period RSI on weekly bars (W1), the 2-period RSI on daily bars (D1), and the 200-day SMA on daily bars (D1).
A long entry is triggered on the next D1 bar open when W1 RSI(3) <= 20.0 (weekly oversold setup), D1 RSI(2) <= 10.0 (daily oversold trigger), and Close > SMA(200) (bullish macro regime).
Long positions are closed when D1 RSI(2) >= 70.0 (daily overbought profit target), when W1 RSI(3) >= 50.0 (weekly failsafe exit), or when a 10-day time stop is reached.
A catastrophic protective stop loss of 3.0 * ATR(14) is placed at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_w1_rsi_period` | 3 | 2-7 | Lookback period for weekly setup RSI |
| `strategy_w1_rsi_entry_thresh` | 20.0 | 10.0-30.0 | Weekly RSI threshold for oversold setup |
| `strategy_w1_rsi_failsafe_thresh` | 50.0 | 40.0-60.0 | Weekly RSI failsafe exit threshold |
| `strategy_d1_rsi_period` | 2 | 2-5 | Lookback period for daily trigger RSI |
| `strategy_d1_rsi_entry_thresh` | 10.0 | 5.0-20.0 | Daily RSI oversold trigger threshold |
| `strategy_d1_rsi_exit_thresh` | 70.0 | 60.0-80.0 | Daily RSI overbought profit target threshold |
| `strategy_sma_period` | 200 | 50-300 | Lookback period for daily macro regime SMA |
| `strategy_atr_period` | 14 | 7-30 | ATR period for catastrophic stop loss distance |
| `strategy_sl_atr_mult` | 3.0 | 1.5-5.0 | ATR multiplier for catastrophic protective stop loss |
| `strategy_time_stop_bars` | 10 | 5-20 | Maximum holding period in trading days |
| `strategy_spread_max_atr` | 0.30 | 0.10-0.50 | Maximum allowed spread as a fraction of ATR(14) |
| `strategy_warmup_bars` | 200 | 100-300 | Minimum required closed D1 bars before trading |
| `strategy_w1_warmup_bars` | 20 | 10-50 | Minimum required closed W1 bars before trading |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 benchmark index (backtest baseline)
- `NDX.DWX` — Nasdaq 100 index CFD
- `WS30.DWX` — Dow Jones Industrial Average CFD
- `GDAXI.DWX` — DAX 40 index CFD
- `UK100.DWX` — FTSE 100 index CFD
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX` — Major FX currency pairs
- `XAUUSD.DWX` — Gold commodity CFD

**Explicitly NOT for:**
- Non-mean-reverting illiquid single equities.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_D1` |
| Multi-timeframe refs | `PERIOD_W1` (W1 setup gate) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~14 |
| Typical hold time | 2 to 6 days (up to 10 D1 bars) |
| Expected drawdown profile | Sharp dip buying with high win rate and rapid recovery upon mean reversion |
| Regime preference | Long-term uptrends with high-conviction deep pullbacks |
| Win rate target (qualitative) | High (65% - 80%) with short holding period |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** Book / Howard Bandy
**Pointer:** Howard Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9730_bandy-weekly-rsi-extreme-d1-trigger-mr-index.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | Initial build from approved card | Task b3706cb0-1e2f-403c-a3a9-ffc9e87e6835 |
