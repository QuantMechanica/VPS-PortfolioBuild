# QM5_10049_ff-dailyopen-h1 - Strategy Spec

**EA ID:** QM5_10049
**Slug:** ff-dailyopen-h1
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

At the broker daily open the EA uses the current D1 open as the daily-open level. It waits for the first H1 candle of the broker day to close, then enters long if that H1 close is above the daily-open level or short if it is below. If the first H1 candle closes exactly at the daily-open level, no trade is opened. Each trade uses a fixed 10-pip stop, fixed 10-pip target, and an end-of-day time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_daily_open_hour_broker | 0 | 0-23 | Broker hour used to identify the first H1 candle after daily open. |
| strategy_daily_open_minute | 0 | 0-59 | Broker minute used with the daily-open hour. |
| strategy_stop_loss_pips | 10 | >0 | Fixed stop loss distance in pips. |
| strategy_take_profit_pips | 10 | >0 | Fixed take profit distance in pips. |
| strategy_max_spread_pips | 2.0 | >=0 | Skip new entries when spread is above this pip threshold. |
| strategy_time_stop_hour_broker | 23 | 0-23 | Close any still-open position at or after this broker hour. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Source instrument and available DWX H1 forex symbol.
- GBPUSD.DWX - Source instrument and available DWX H1 forex symbol.

**Explicitly NOT for:**
- Non-DWX symbols - Research and backtest artifacts must use canonical `.DWX` symbols.
- Symbols outside the card's R3 basket - The source and card restrict the baseline to EURUSD and GBPUSD.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 open for broker daily-open level |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, from the second H1 bar until fixed TP, fixed SL, or end-of-day time stop |
| Expected drawdown profile | Fixed 10-pip loss per failed signal with V5 fixed-risk sizing |
| Regime preference | Daily-open breakout / first-hour directional continuation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/535657-1-hour-after-daily-open
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10049_ff-dailyopen-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | 8e7db77d-5c59-4eed-8b40-4936fa667564 |
