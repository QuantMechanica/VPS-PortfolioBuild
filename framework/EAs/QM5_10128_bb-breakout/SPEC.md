# QM5_10128_bb-breakout — Strategy Spec

**EA ID:** QM5_10128
**Slug:** `bb-breakout`
**Source:** `d3c009d7-a8d6-5251-b572-4777b207c2b9` (see `strategy-seeds/sources/d3c009d7-a8d6-5251-b572-4777b207c2b9/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On the close of each D1 bar, compute the typical price TP = (High + Low + Close) / 3 for the last 20 bars, then derive SMA(TP, 20) and a 1-sigma Bollinger Band. Enter LONG when the just-closed bar's close exceeds the upper band (SMA + 1×StdDev). Enter SHORT when close falls below the lower band (SMA − 1×StdDev). Exit a LONG when the close is no longer above the upper band (close ≤ upper), and exit a SHORT when the close is no longer below the lower band (close ≥ lower). No take-profit target; exits are signal-driven. An ATR(14)-based emergency stop is applied at entry as the sole hard floor.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 5–100 | BB lookback in D1 bars (card specifies 20) |
| `strategy_bb_dev` | 1.0 | 0.5–3.0 | Entry sigma multiplier (card specifies 1-sigma) |
| `strategy_sl_atr_period` | 14 | 5–50 | ATR period for emergency stop distance |
| `strategy_sl_atr_mult` | 5.0 | 2.0–10.0 | Emergency stop = ATR × multiplier (card has no explicit stop) |

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` — liquid FX major, typical-price BB applicable
- `AUDCHF.DWX` — liquid FX major
- `AUDJPY.DWX` — liquid FX major
- `AUDNZD.DWX` — liquid FX major
- `AUDUSD.DWX` — liquid FX major
- `CADCHF.DWX` — liquid FX cross
- `CADJPY.DWX` — liquid FX cross
- `CHFJPY.DWX` — liquid FX cross
- `EURAUD.DWX` — liquid FX major
- `EURCAD.DWX` — liquid FX major
- `EURCHF.DWX` — liquid FX major
- `EURGBP.DWX` — liquid FX major
- `EURJPY.DWX` — liquid FX major
- `EURNZD.DWX` — liquid FX major
- `EURUSD.DWX` — primary FX major
- `GBPAUD.DWX` — liquid FX major
- `GBPCAD.DWX` — liquid FX major
- `GBPCHF.DWX` — liquid FX major
- `GBPJPY.DWX` — liquid FX major
- `GBPNZD.DWX` — liquid FX major
- `GBPUSD.DWX` — primary FX major
- `GDAXI.DWX` — EU index, high liquidity
- `NDX.DWX` — US Nasdaq 100 index, high liquidity (live-tradable)
- `NZDCAD.DWX` — liquid FX cross
- `NZDCHF.DWX` — liquid FX cross
- `NZDJPY.DWX` — liquid FX cross
- `NZDUSD.DWX` — liquid FX major
- `SP500.DWX` — US S&P 500 analog, backtest-only
- `UK100.DWX` — FTSE 100 index
- `USDCAD.DWX` — liquid FX major
- `USDCHF.DWX` — liquid FX major
- `USDJPY.DWX` — primary FX major
- `WS30.DWX` — US Dow Jones 30 index, live-tradable
- `XAGUSD.DWX` — silver commodity
- `XAUUSD.DWX` — gold commodity (card R3: volatile, breakout-prone)
- `XNGUSD.DWX` — natural gas commodity
- `XTIUSD.DWX` — WTI crude oil (card R3: oil CFD)

**Explicitly NOT for:**
- Intraday timeframes (H4 and below) — 20-bar warmup impractical, signal frequency too low

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~20 |
| Typical hold time | 1–10 trading days |
| Expected drawdown profile | Moderate; source noted large drawdown after strong spikes |
| Regime preference | trend / volatility-expansion / breakout |
| Win rate target (qualitative) | medium (trend-following, whipsaw risk in ranging markets) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d3c009d7-a8d6-5251-b572-4777b207c2b9`
**Source type:** forum / blog
**Pointer:** https://raposa.trade/blog/4-simple-strategies-to-trade-bollinger-bands/ (section "Trading Bollinger Band Breakouts", 2021-07-21)
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10128_bb-breakout.md`

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
| v1 | 2026-06-10 | Initial build from card | 5f6227aa-81bc-478f-a4df-f2f39b8af83b |
