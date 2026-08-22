# QM5_9467_connors-crsi-pullback-d1 — Strategy Spec

**EA ID:** QM5_9467
**Slug:** connors-crsi-pullback-d1
**Source:** ef14a5d7-e3f1-52be-910a-3ca6b736a152
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The EA implements Larry Connors / Matt Radtke ConnorsRSI Pullback Limit Entry strategy on daily bars.
On closed D1 bars, it computes ConnorsRSI(3, 2, 100), ADX(10), Closing Range, and ATR(14).
A long entry setup is triggered when:
- ADX(10) > 30.0
- Current low <= previous close * 0.98
- Closing range (Close - Low) / (High - Low) <= 0.25
- ConnorsRSI(3, 2, 100) < 5.0

When the setup fires, a next-day buy limit order is placed at Close[1] * 0.90 (or market buy if market open is already below limit). The limit order expires after 1 day (86,400 seconds) if unfilled.
The position is closed when ConnorsRSI(3, 2, 100) closes > 80.0 on a daily close, or when an 8-bar time stop is reached.
A protective stop loss of 3.0 * ATR(14) is placed at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_crsi_rsi_period | 3 | 2-5 | Lookback period for price RSI component of ConnorsRSI |
| strategy_crsi_streak_period | 2 | 2-5 | Lookback period for streak RSI component of ConnorsRSI |
| strategy_crsi_rank_period | 100 | 50-200 | Lookback period for percent rank component of ConnorsRSI |
| strategy_crsi_entry_thresh | 5.0 | 2.0-10.0 | ConnorsRSI oversold entry threshold |
| strategy_crsi_exit_thresh | 80.0 | 70.0-90.0 | ConnorsRSI mean-reversion exit threshold |
| strategy_adx_period | 10 | 7-20 | Lookback period for ADX trend strength filter |
| strategy_adx_thresh | 30.0 | 20.0-40.0 | Minimum ADX threshold for strong trend filter |
| strategy_closing_range_thresh | 0.25 | 0.10-0.40 | Maximum closing range ratio (Close-Low)/(High-Low) |
| strategy_limit_mult | 0.90 | 0.85-0.95 | Limit buy order discount multiplier relative to prior close |
| strategy_atr_period | 14 | 7-30 | ATR period for stop-loss distance calculation |
| strategy_sl_atr_mult | 3.0 | 1.5-5.0 | ATR multiplier for protective stop loss |
| strategy_time_stop_bars | 8 | 4-15 | Maximum number of daily bars to hold a position |
| strategy_spread_max_atr | 0.25 | 0.10-0.50 | Maximum allowed spread as a fraction of ATR(14) |
| strategy_warmup_bars | 120 | 100-200 | Minimum required closed bars before trading |

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
| Trades / year / symbol | ~8 |
| Typical hold time | 2 to 5 days (up to 8 D1 bars) |
| Expected drawdown profile | Sharp pullback recovery with high win rate on limit fills |
| Regime preference | High-volatility strong bull trend pullbacks |
| Win rate target (qualitative) | High (75% - 85%) on filled limit orders |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** f14a5d7-e3f1-52be-910a-3ca6b736a152
**Source type:** Article / Matt Radtke / Larry Connors / Connors Research LLC
**Pointer:** https://tradingmarkets.com/recent/how-to-trade-pullbacks-u-part-3-finding-pullback-trades-1581392
**R1–R4 verdict (Q00):** all PASS per rtifacts/cards_approved/QM5_9467_connors-crsi-pullback-d1.md

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
| v1 | 2026-08-22 | Initial build from approved card | Task 5de38382-e3f2-4179-b63b-6f60222bccc3 |
