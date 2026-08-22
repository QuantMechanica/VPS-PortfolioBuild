# QM5_9406_qs-daily-mac — Strategy Spec

**EA ID:** QM5_9406
**Slug:** qs-daily-mac
**Source:** 842161b9-a728-55c7-97e8-33e33719b70c
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The EA implements a classical long-only daily moving average crossover system based on the QuantStart framework.
On closed D1 bars, it computes a 100-day SMA and a 400-day SMA.
A long entry is triggered when the 100-day SMA crosses above the 400-day SMA (after at least 400 warmup bars) and no position is currently open.
The long position is closed when the 100-day SMA crosses back below or equals the 400-day SMA.
A protective ATR stop loss at 2.5 * ATR(14) is applied at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma` | 100 | 10-200 | Fast SMA lookback period in daily bars |
| `strategy_slow_sma` | 400 | 200-500 | Slow SMA lookback period in daily bars |
| `strategy_atr_period` | 14 | 7-30 | ATR period for stop-loss distance calculation |
| `strategy_sl_atr_mult` | 2.5 | 1.0-5.0 | ATR multiplier for protective stop loss |
| `strategy_spread_max_atr` | 0.30 | 0.10-1.0 | Maximum allowed spread as a fraction of ATR(14) |
| `strategy_warmup_bars` | 400 | 100-500 | Minimum required closed bars before trading |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 benchmark index (backtest baseline)
- `NDX.DWX` — Nasdaq 100 index CFD
- `WS30.DWX` — Dow Jones Industrial Average CFD
- `GDAXI.DWX` — DAX 40 index CFD
- `UK100.DWX` — FTSE 100 index CFD
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX` — FX majors trend following basket
- `XAUUSD.DWX` — Gold commodity trend following

**Explicitly NOT for:**
- Single-stock equities without continuous history.

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
| Trades / year / symbol | ~6 |
| Typical hold time | weeks to months |
| Expected drawdown profile | Moderate trend-following equity curve with extended flat periods during consolidation |
| Regime preference | Persistent medium-to-long term bull markets and multi-month trends |
| Win rate target (qualitative) | Low to medium (35% - 45%) with large profit factor |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `842161b9-a728-55c7-97e8-33e33719b70c`
**Source type:** Article / QuantStart / QuarkGluon Ltd.
**Pointer:** https://www.quantstart.com/articles/Backtesting-a-Moving-Average-Crossover-in-Python-with-pandas/
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9406_qs-daily-mac.md`

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
| v1 | 2026-08-22 | Initial build from approved card | Task 52fc3ee3-bd54-41c4-a3fd-d3616da86b62 |
