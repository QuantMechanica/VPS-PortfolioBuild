# QM5_9466_connors-r2-d1 — Strategy Spec

**EA ID:** QM5_9466
**Slug:** connors-r2-d1
**Source:** ef14a5d7-e3f1-52be-910a-3ca6b736a152
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The EA implements Larry Connors' Improved R2 Market Timing Strategy on daily bars.
On closed D1 bars, it evaluates a 2-period RSI, a 200-day SMA, and ATR(14).
A long entry is triggered when price closes above the 200-day SMA and a 3-day declining RSI(2) sequence occurs:
- Day 1 (bar 3): RSI(2) < 65.0
- Day 2 (bar 2): RSI(2) < Day 1 RSI(2)
- Day 3 (bar 1): RSI(2) < Day 2 RSI(2)
Buying occurs on the next bar open (market order at ask).
The position is closed when RSI(2) closes > 75.0 on a daily close, or when a 10-bar time stop is reached.
A protective stop loss of 2.5 * ATR(14) is placed at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_rsi_period | 2 | 2-5 | Lookback period for the Connors short-term RSI |
| strategy_sma_period | 200 | 50-300 | Lookback period for the macro trend filter SMA |
| strategy_rsi_day1_max | 65.0 | 50.0-75.0 | Maximum RSI(2) threshold for Day 1 of the sequence |
| strategy_rsi_exit_thresh | 75.0 | 65.0-85.0 | RSI(2) exit threshold |
| strategy_atr_period | 14 | 7-30 | ATR period for stop-loss distance calculation |
| strategy_sl_atr_mult | 2.5 | 1.5-4.0 | ATR multiplier for protective stop loss |
| strategy_time_stop_bars | 10 | 5-20 | Maximum number of daily bars to hold a position |
| strategy_spread_max_atr | 0.25 | 0.10-0.50 | Maximum allowed spread as a fraction of ATR(14) |
| strategy_warmup_bars | 200 | 100-300 | Minimum required closed bars before trading |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX — S&P 500 benchmark index (backtest baseline)
- NDX.DWX — Nasdaq 100 index CFD
- WS30.DWX — Dow Jones Industrial Average CFD
- GDAXI.DWX — DAX 40 index CFD
- UK100.DWX — FTSE 100 index CFD
- EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, USDCAD.DWX, NZDUSD.DWX — FX majors trend/pullback basket
- XAUUSD.DWX — Gold commodity CFD

**Explicitly NOT for:**
- Illiquid non-trending equities.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | PERIOD_D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~9 |
| Typical hold time | 2 to 6 days (up to 10 D1 bars) |
| Expected drawdown profile | Short mean-reversion pullbacks with rapid profit taking |
| Regime preference | Long-term bull market pullbacks and upward drift regimes |
| Win rate target (qualitative) | High (70% - 85%) per Connors published historical research |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** f14a5d7-e3f1-52be-910a-3ca6b736a152
**Source type:** Article / Larry Connors / Connors Research LLC
**Pointer:** https://tradingmarkets.com/recent/the_improved_r2_strategy_84_correct_with_just_6_rules_-674361
**R1–R4 verdict (Q00):** all PASS per rtifacts/cards_approved/QM5_9466_connors-r2-d1.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | ,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by QM_FrameworkInit (EA_INPUT_RISK_MODE_MISMATCH).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-22 | Initial build from approved card | Task ffdbf22e-3ec4-4027-88d5-5a6e4ba6c1c7 |
