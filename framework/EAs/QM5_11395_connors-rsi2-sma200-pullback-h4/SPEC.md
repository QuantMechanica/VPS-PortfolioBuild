# QM5_11395_connors-rsi2-sma200-pullback-h4 — Strategy Spec

**EA ID:** QM5_11395
**Slug:** `connors-rsi2-sma200-pullback-h4`
**Source:** `ea4596d1-24e0-5e43-9106-66fd575a5370` (see `strategy-seeds/sources/ea4596d1-24e0-5e43-9106-66fd575a5370/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

Larry Connors' RSI(2) mean-reversion pullback, adapted to Forex H4. The SMA(200)
defines the trend state: trade longs only when the last closed H4 close is above
SMA(200), and shorts only when below. Within that trend, enter long when the last
closed H4 RSI(2) is below 5, and enter short when RSI(2) is above 95. Exit long
when RSI(2) closes above 70, and exit short when RSI(2) closes below 30.
Protective stop is ATR(14) x 2.0 from entry, capped at 50 pips. There is no
fixed take-profit because the RSI revert is the card's primary exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | H4 | H1-D1 | Native timeframe; EA refuses other charts |
| `strategy_rsi_period` | 2 | 2-5 | Connors RSI(2) lookback (ultra-short) |
| `strategy_sma_trend_period` | 200 | 100-200 | SMA trend-state filter period |
| `strategy_atr_period` | 14 | 7-21 | ATR period for the protective stop |
| `strategy_entry_rsi_long` | 5.0 | 5-15 | RSI(2) below this crosses into oversold (long) |
| `strategy_entry_rsi_short` | 95.0 | 85-95 | RSI(2) above this crosses into overbought (short) |
| `strategy_exit_rsi_long` | 70.0 | 65-80 | RSI(2) above this exits long |
| `strategy_exit_rsi_short` | 30.0 | 20-35 | RSI(2) below this exits short |
| `strategy_atr_stop_mult` | 2.0 | 1.0-3.0 | Stop distance = mult × ATR(14) |
| `strategy_max_sl_pips` | 50.0 | 20-80 | P2 cap: stop distance never wider than this (pips) |
| `strategy_enable_shorts` | true | bool | Mirror shorts below SMA(200) |
| `strategy_spread_cap_pips` | 20 | 1-50 | Card spread cap; block only genuinely wide spread and allow zero-spread `.DWX` tests |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean RSI(2) mean-reversion on H4
- `GBPUSD.DWX` — liquid major with adequate H4 swing range for the pullback edge
- `USDJPY.DWX` — major with distinct trend regimes; SMA(200) filter fits well
- `AUDUSD.DWX` — commodity major; mean-reverts within trend on H4

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — card scopes this to the four FX majors above; RSI(2) thresholds (5/95) calibrated to FX H4 volatility

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H4)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~60` |
| Typical hold time | `hours to a few days (RSI revert exit on H4)` |
| Expected drawdown profile | `moderate; ATR×2.0 stop capped at 50 pips bounds per-trade loss` |
| Regime preference | `mean-revert within an SMA(200) trend` |
| Win rate target (qualitative) | `high (RSI(2) pullback = high hit-rate, small edge per trade)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ea4596d1-24e0-5e43-9106-66fd575a5370`
**Source type:** `book`
**Pointer:** Larry Connors & Cesar Alvarez, "Short Term Trading Strategies That Work" (2009, Wiley/TradingMarkets), "The 2-Period RSI" chapter — `strategy-seeds/sources/ea4596d1-24e0-5e43-9106-66fd575a5370/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11395_connors-rsi2-sma200-pullback-h4.md`

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
| v1 | 2026-06-20 | Initial build from card | 378b97af-48a0-46be-b882-e393f8a4756f |
