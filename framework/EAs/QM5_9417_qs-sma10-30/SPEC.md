# QM5_9417_qs-sma10-30 — Strategy Spec

**EA ID:** QM5_9417
**Slug:** qs-sma10-30
**Source:** 842161b9-a728-55c7-97e8-33e33719b70c
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The EA implements a deterministic long-only daily 10/30 moving average crossover system based on QuantStart.
On closed D1 bars, it computes a 10-day SMA and a 30-day SMA.
A long entry is triggered when the 10-day SMA crosses above the 30-day SMA (after at least 30 warmup bars) and no position is currently open.
The long position is closed when the 10-day SMA crosses back below or equals the 30-day SMA.
A protective ATR stop loss at 2.5 * ATR(14) is applied at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma` | 10 | 5-50 | Fast SMA lookback period in daily bars |
| `strategy_slow_sma` | 30 | 15-100 | Slow SMA lookback period in daily bars |
| `strategy_atr_period` | 14 | 7-30 | ATR period for stop-loss distance calculation |
| `strategy_sl_atr_mult` | 2.5 | 1.0-5.0 | ATR multiplier for protective stop loss |
| `strategy_spread_max_atr` | 0.30 | 0.10-1.0 | Maximum allowed spread as a fraction of ATR(14) |
| `strategy_warmup_bars` | 30 | 20-100 | Minimum required closed bars before trading |

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
- Illiquid single stocks.

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
| Trades / year / symbol | ~20 |
| Typical hold time | days to weeks |
| Expected drawdown profile | Standard intermediate trend-following equity curve with typical choppy period whipsaws |
| Regime preference | Intermediate multi-week trending markets |
| Win rate target (qualitative) | Medium (40% - 50%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `842161b9-a728-55c7-97e8-33e33719b70c`
**Source type:** Article / QuantStart / QuarkGluon Ltd.
**Pointer:** https://www.quantstart.com/articles/market-regime-detection-using-hidden-markov-models-in-qstrader/
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9417_qs-sma10-30.md`

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
| v1 | 2026-08-22 | Initial build from approved card | Task cc4549cc-1955-47fb-9801-78d2aad3f77b |
