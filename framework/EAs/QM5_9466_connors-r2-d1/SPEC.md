# QM5_9466_connors-r2-d1 — Strategy Spec

**EA ID:** QM5_9466
**Slug:** connors-r2-d1
**Source:** ef14a5d7-e3f1-52be-910a-3ca6b736a152
**Author of this spec:** Development
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

The EA implements Larry Connors' Improved R2 Market Timing Strategy on daily bars.
On closed D1 bars, it evaluates a 2-period RSI, a 200-day SMA, and ATR(14).
A long entry is triggered when price closes above the 200-day SMA and a three-day declining RSI(2) sequence occurs:

- Day 1 (bar 3): RSI(2) < 65.0
- Day 2 (bar 2): RSI(2) < Day 1 RSI(2)
- Day 3 (bar 1): RSI(2) < Day 2 RSI(2)

Buying occurs on the next tradable bar open as a market order. The position is closed when RSI(2) closes above 75.0 or when the restart-safe ten-D1-bar time stop is reached. A protective stop loss of 2.5 × ATR(14) is placed at entry. Entry is skipped when spread exceeds 0.25 × ATR(14); entry eligibility never suppresses open-position management or either card exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| strategy_rsi_period | 2 | 2–5 | Lookback period for the Connors short-term RSI |
| strategy_sma_period | 200 | 50–300 | Lookback period for the macro trend filter SMA |
| strategy_rsi_day1_max | 65.0 | 50.0–75.0 | Maximum RSI(2) threshold for Day 1 of the sequence |
| strategy_rsi_exit_thresh | 75.0 | 65.0–85.0 | RSI(2) exit threshold |
| strategy_atr_period | 14 | 7–30 | ATR period for the stop and spread ceiling |
| strategy_sl_atr_mult | 2.5 | 1.5–4.0 | ATR multiplier for the protective stop loss |
| strategy_time_stop_bars | 10 | 5–20 | Maximum number of completed daily bars to hold |
| strategy_spread_max_atr | 0.25 | 0.10–0.50 | Maximum spread as a fraction of ATR(14) |
| strategy_warmup_bars | 200 | 100–300 | Minimum D1 history before new entries |

---

## 3. Symbol Universe

Approved package:

- SP500.DWX — S&P 500 benchmark index; backtest baseline and not broker-routable for live deployment
- NDX.DWX — Nasdaq 100 index CFD; approved parallel-validation port
- WS30.DWX — Dow Jones Industrial Average CFD; approved parallel-validation port

No FX, metals, or additional equity-index ports are authorized by the approved card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | PERIOD_D1 |
| Multi-timeframe references | none |
| Execution contract | `QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` |
| Decision boundary | `QM_IsNewBar(_Symbol, PERIOD_D1)` |
| Friday close | V5 framework safety override; the card itself has no Friday-close rule |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 9 |
| Typical hold time | 2–6 days, capped at 10 completed D1 bars |
| Expected drawdown profile | Short mean-reversion pullbacks with rapid profit taking |
| Regime preference | Long-term bull-market pullbacks and upward-drift regimes |
| Win-rate target | Qualitatively high in the cited Connors research; pipeline evidence remains authoritative |

---

## 6. Source Citation

**Source ID:** ef14a5d7-e3f1-52be-910a-3ca6b736a152
**Source type:** Article / Larry Connors / Connors Research LLC
**Pointer:** https://tradingmarkets.com/recent/the_improved_r2_strategy_84_correct_with_just_6_rules_-674361
**Approved card:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_9466_connors-r2-d1.md
**Q00 authorization:** `g0_status: APPROVED`

---

## 7. Risk Model

| Environment | Active risk mode | Inactive risk mode |
|---|---|---|
| Backtest | `RISK_FIXED = $1,000` per trade | `RISK_PERCENT = 0` |
| Live | `RISK_PERCENT` per OWNER-approved policy | `RISK_FIXED = 0` |

The V5 framework initialization and setfile checks enforce that exactly one risk mode is active. Build conformance does not authorize live deployment.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-22 | Initial build from approved card | Task ffdbf22e-3ec4-4027-88d5-5a6e4ba6c1c7 |
| v2 | 2026-08-24 | Review rework | Declared D1 contract, restored exit reachability, restricted package to approved ports, and regenerated clean UTF-8 text |
