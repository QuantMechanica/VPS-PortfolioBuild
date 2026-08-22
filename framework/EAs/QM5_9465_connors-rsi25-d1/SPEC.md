# QM5_9465_connors-rsi25-d1 — Strategy Spec

**EA ID:** QM5_9465
**Slug:** connors-rsi25-d1
**Source:** ef14a5d7-e3f1-52be-910a-3ca6b736a152
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The EA implements Larry Connors' 4-period RSI 25 Pullback Mean Reversion strategy on daily bars.
On closed D1 bars, it computes a 4-period RSI, a 200-day SMA, and ATR(14).
A long entry is triggered when price closes above the 200-day SMA and RSI(4) drops below 25.0, buying on the next bar open.
The position is closed when RSI(4) rises above 55.0 on a daily close, or when a 12-bar time stop is reached.
A protective stop loss of 3.0 * ATR(14) is placed at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 4 | 2-10 | Lookback period for the Connors short-term RSI |
| `strategy_sma_period` | 200 | 50-300 | Lookback period for the macro trend filter SMA |
| `strategy_rsi_entry_thresh` | 25.0 | 10.0-35.0 | RSI(4) oversold entry threshold |
| `strategy_rsi_exit_thresh` | 55.0 | 45.0-70.0 | RSI(4) mean-reversion exit threshold |
| `strategy_atr_period` | 14 | 7-30 | ATR period for stop-loss distance calculation |
| `strategy_sl_atr_mult` | 3.0 | 1.5-5.0 | ATR multiplier for protective stop loss |
| `strategy_time_stop_bars` | 12 | 5-30 | Maximum number of daily bars to hold a position |
| `strategy_spread_max_atr` | 0.25 | 0.10-0.50 | Maximum allowed spread as a fraction of ATR(14) |
| `strategy_warmup_bars` | 200 | 100-300 | Minimum required closed bars before trading |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 benchmark index (backtest baseline)
- `NDX.DWX` — Nasdaq 100 index CFD
- `WS30.DWX` — Dow Jones Industrial Average CFD
- `GDAXI.DWX` — DAX 40 index CFD
- `UK100.DWX` — FTSE 100 index CFD
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX` — FX majors trend/pullback basket
- `XAUUSD.DWX` — Gold commodity CFD

**Explicitly NOT for:**
- Illiquid non-trending equities.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~10 |
| Typical hold time | 2 to 8 days (up to 12 D1 bars) |
| Expected drawdown profile | Smooth mean-reversion equity curve with quick exits upon trend resumption |
| Regime preference | Long-term bull market pullbacks and upward drift regimes |
| Win rate target (qualitative) | High (60% - 75%) with short duration |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ef14a5d7-e3f1-52be-910a-3ca6b736a152`
**Source type:** Article / Larry Connors / Connors Research LLC
**Pointer:** https://tradingmarkets.com/recent/does-mean-reversion-still-work-1593757
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9465_connors-rsi25-d1.md`

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
| v1 | 2026-08-22 | Initial build from approved card | Task 1b490cf7-9172-410b-8e5b-07b24c0cb517 |
