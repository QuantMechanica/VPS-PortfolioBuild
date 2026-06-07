# QM5_11085_box-breakout — Strategy Spec

**EA ID:** QM5_11085
**Slug:** box-breakout
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86 (see approved card frontmatter)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

On each completed H1 bar, the EA compares the closed bar's close against the highest high and lowest low of the previous 10 completed bars, excluding the signal bar. It opens long when the close is above that box high and opens short when the close is below that box low, but only when the previous closed bar was neutral. It closes a long when a completed close breaks below the current 10-bar box low, and closes a short when a completed close breaks above the current 10-bar box high. Baseline protective orders use ATR(14): stop loss at 2.0 ATR and take profit at 3.0 ATR.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_box_bars` | 10 | 1+ | Number of completed bars used to define the breakout box. |
| `strategy_atr_period` | 14 | 1+ | ATR lookback for baseline catastrophic stop and optional target. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiple used for the stop loss. |
| `strategy_atr_tp_mult` | 3.0 | >0 | ATR multiple used for the take profit. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Approved R3 forex symbol with DWX OHLC data available.
- `GBPUSD.DWX` — Approved R3 forex symbol with DWX OHLC data available.
- `USDJPY.DWX` — Approved R3 forex symbol with DWX OHLC data available.
- `XAUUSD.DWX` — Approved R3 metals symbol with DWX OHLC data available.

**Explicitly NOT for:**
- Non-DWX symbols — V5 research and backtest artifacts require canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | H1 breakout hold; P3 may test 12, 24, and 48 H1 bars |
| Expected drawdown profile | Breakout strategy with ATR-defined catastrophic risk per trade |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** public GitHub repository and MQL5 source
**Pointer:** https://github.com/EarnForex/Box-Breakout-Alert
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11085_box-breakout.md`

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
| v1 | 2026-06-07 | Initial build from card | eb7484d8-9ba0-47be-bb3c-266ea8d699e6 |
