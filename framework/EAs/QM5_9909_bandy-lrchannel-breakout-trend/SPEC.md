# QM5_9909_bandy-lrchannel-breakout-trend — Strategy Spec

**EA ID:** QM5_9909
**Slug:** bandy-lrchannel-breakout-trend
**Source:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Author of this spec:** Gemini
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

The EA implements Howard Bandy's Linear Regression Channel (LRC) Breakout Trend strategy on daily bars.
On each closed D1 bar, it computes an Ordinary Least Squares (OLS) linear regression over a 50-bar lookback window and forms a channel at ±2.0 residual standard deviations from the regression line.
A long entry is triggered on the next bar open when the closed bar price closes above the upper regression channel.
A short entry is triggered on the next bar open when the closed bar price closes below the lower regression channel.
Open positions are trailed via a Chandelier ATR stop (2.5 * ATR(14)), with a maximum holding time of 40 trading days.
A protective catastrophic stop loss is placed at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lr_window` | 50 | 30-100 | Lookback window for OLS linear regression fit |
| `strategy_channel_sigma` | 2.0 | 1.5-3.0 | Channel width multiplier in residual standard deviations |
| `strategy_atr_period` | 14 | 7-30 | Lookback period for ATR stop loss and trailing calculation |
| `strategy_trail_atr_mult` | 2.5 | 1.5-4.0 | ATR multiplier for Chandelier trailing stop |
| `strategy_sl_atr_mult` | 5.0 | 3.0-8.0 | ATR multiplier for catastrophic protective stop loss |
| `strategy_time_stop_bars` | 40 | 20-80 | Maximum holding period in trading days |
| `strategy_spread_max_atr` | 0.30 | 0.10-0.50 | Maximum allowed spread as a fraction of ATR(14) |
| `strategy_warmup_bars` | 60 | 50-120 | Minimum required closed bars before trading |

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
- Choppy or mean-reverting range-bound symbols with no trend persistence.

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
| Trades / year / symbol | ~16 |
| Typical hold time | 5 to 25 days (up to 40 D1 bars) |
| Expected drawdown profile | Trend breakout equity curve with trailing stop lock-in of gains |
| Regime preference | Strong directional trend and channel expansion regimes |
| Win rate target (qualitative) | Medium (45% - 55%) with high payoff ratio |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** Book / Howard B. Bandy
**Pointer:** Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 9780979183850
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9909_bandy-lrchannel-breakout-trend.md`

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
| v1 | 2026-08-23 | Initial build from approved card | Task a944cf09-4a86-43b5-90b5-1d6fc5108ae6 |
