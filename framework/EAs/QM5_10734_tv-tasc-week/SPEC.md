# QM5_10734_tv-tasc-week - Strategy Spec

**EA ID:** QM5_10734
**Slug:** tv-tasc-week
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source citation in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA opens one long position on the first tick of a Monday D1 bar. It starts with a fixed stop at 98.5% of entry and a fixed target at 107% of entry. After the Monday bar closes, it adjusts the target: strong open profit raises the target, while flat or negative open profit cuts the target to 102.5% of entry. After the Tuesday bar closes, it closes the trade if Monday was strong but Tuesday failed to continue; any remaining position is handled by the framework Friday-close rule.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_initial_tp_mult | 1.070 | > 1.0 | Initial take-profit price as entry multiplied by this value. |
| strategy_hard_stop_mult | 0.985 | 0.0-1.0 | Initial stop-loss price as entry multiplied by this value. |
| strategy_monday_profit_pct | 0.300 | >= 0.0 | Monday close open-profit threshold for raising the target. |
| strategy_monday_tp_boost | 1.011 | > 1.0 | Multiplier applied to the initial target after a strong Monday. |
| strategy_monday_weak_tp | 1.025 | > 1.0 | Reduced target multiplier when Monday open profit is flat or negative. |
| strategy_tuesday_monday_min_pct | 2.000 | >= 0.0 | Monday daily return threshold for the Tuesday weakness exit. |
| strategy_tuesday_max_pct | 3.000 | >= 0.0 | Tuesday daily return ceiling that triggers the weakness exit when Monday was strong. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - Card R3 primary S&P 500 port for the source equity-index weekly model; backtest-only custom symbol.
- NDX.DWX - Card R3 Nasdaq 100 validation symbol and closest live-tradable analogue to the TQQQ source context.
- WS30.DWX - Card R3 Dow 30 validation symbol for broad US large-cap weekly index behavior.

**Explicitly NOT for:**
- SPY.DWX - Not present in the DWX matrix; SP500.DWX is the canonical S&P 500 custom symbol.
- ES.DWX - Not present in the DWX matrix; SP500.DWX is the canonical S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Monday entry through Friday close, with possible Tuesday/Wednesday exit after weakness confirmation |
| Expected drawdown profile | Fixed 1.5% hard stop per weekly cycle, one active position per symbol and magic. |
| Regime preference | Weekly long equity-index momentum with adaptive exit management |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/CSGmHoik-TASC-2026-06-One-Percent-A-Week-Adaptive/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10734_tv-tasc-week.md`

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
| v1 | 2026-06-14 | Initial build from card | 50acbb1c-4103-42bc-9637-d0bc58c2bc55 |
