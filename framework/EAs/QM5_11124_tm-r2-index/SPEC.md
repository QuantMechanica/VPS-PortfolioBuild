# QM5_11124_tm-r2-index - Strategy Spec

**EA ID:** QM5_11124
**Slug:** tm-r2-index
**Source:** 63b6d09c-d79f-561b-b577-eb5bf5878af1
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades long-only daily index pullbacks. On each new D1 bar it checks the last three closed daily RSI(2) values: Day 1 must be below 65, Day 2 must close lower than Day 1, and Day 3 must close lower than Day 2. The Day 3 close must also be above the 200-day simple moving average. If all rules pass, the EA enters long at the next available market price with an initial stop at 2.5 x ATR(14). It exits when the last closed daily RSI(2) is above 75 or when 12 D1 periods have elapsed since entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_rsi_period | 2 | 1+ | RSI period used for entry sequence and exit. |
| strategy_rsi_day1_ceiling | 65.0 | 0-100 | Maximum RSI value allowed on the first pullback day. |
| strategy_exit_rsi | 75.0 | 0-100 | Closed-bar RSI value above which the EA exits. |
| strategy_sma_period | 200 | 1+ | Daily SMA trend filter period. |
| strategy_atr_period | 14 | 1+ | Daily ATR period used for initial stop placement. |
| strategy_atr_sl_mult | 2.5 | >0 | ATR multiple for the initial stop loss. |
| strategy_time_stop_bars | 12 | 1+ | Maximum hold expressed as elapsed D1 periods. |
| strategy_max_spread_points | 0 | 0+ | Optional spread cap in points; 0 leaves spread handling to framework/broker defaults. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom symbol; direct port of the SPX/SPY source logic, backtest-only per DWX symbol discipline.
- NDX.DWX - Nasdaq 100 index CFD; liquid US large-cap index analogue for the same pullback timing logic.
- WS30.DWX - Dow 30 index CFD; liquid US large-cap index analogue for basket saturation.

**Explicitly NOT for:**
- SPX500.DWX, SPY.DWX, ES.DWX - not canonical DWX symbols in the matrix.
- Single stocks, FX pairs, metals, energy, and crypto symbols - the card is an index timing strategy, not a cross-asset mean-reversion model.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | Source reports 5.76 average holding days; implementation time-stops after 12 D1 periods. |
| Expected drawdown profile | Mean-reversion pullback drawdowns, bounded by the ATR initial stop and fixed-risk sizing. |
| Regime preference | Mean-reversion inside a long-term uptrend. |
| Win rate target (qualitative) | High, based on source claim of 84.31% correct over 1995-2006. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 63b6d09c-d79f-561b-b577-eb5bf5878af1
**Source type:** article
**Pointer:** Larry Connors, "The Improved R2 Strategy: 84% Correct with Just 6 Rules", TradingMarkets, 2007-02-21, https://tradingmarkets.com/recent/the_improved_r2_strategy_84_correct_with_just_6_rules_-674361
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11124_tm-r2-index.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-07 | Initial build from card | ffe325f3-92b2-434f-a1dd-1a8e0973f7db |
