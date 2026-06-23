# QM5_11915_fielder-deadtime-midpoint-reversion-h1 - Strategy Spec

**EA ID:** QM5_11915
**Slug:** fielder-deadtime-midpoint-reversion-h1
**Source:** b8c4e9a2-5d76-5f48-9c37-d6a4b1e5f3c8
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades one H1 midpoint-reversion setup during the New York 17:00 bar. It reads the H1 close that ended at 15:00 New York time and the H1 close that ended at 17:00 New York time, then computes the midpoint between those two closes. At the open of the 17:00 New York H1 bar it buys when current price is below that midpoint and sells when current price is above it. Exits are a 12-pip take profit, a 12-pip stop loss, or a two-hour time stop aligned with the 19:00 New York window close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_entry_hour_ny | 17 | 0-23 | New York local hour for the one daily entry check. |
| strategy_exit_hour_ny | 19 | 0-23 | New York local hour for the time-stop close window. |
| strategy_time_stop_hours | 2 | 1-24 | Maximum hold time after entry if SL/TP has not fired. |
| strategy_target_pips | 12 | >0 | Fixed take-profit distance in pips. |
| strategy_stop_pips | 12 | >0 | Fixed stop-loss distance in pips. |
| strategy_close_15_shift | 3 | > strategy_close_17_shift | H1 closed-bar shift used for the bar that closed at 15:00 New York when the 17:00 bar opens. |
| strategy_close_17_shift | 1 | >=1 | H1 closed-bar shift used for the bar that closed at 17:00 New York when the 17:00 bar opens. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - major FX pair in the Fielder dead-time session universe.
- GBPUSD.DWX - major FX pair in the Fielder dead-time session universe.
- USDJPY.DWX - major FX pair in the Fielder dead-time session universe.
- USDCAD.DWX - major FX pair in the Fielder dead-time session universe.
- USDCHF.DWX - major FX pair in the Fielder dead-time session universe.
- AUDUSD.DWX - major FX pair in the Fielder dead-time session universe.
- NZDUSD.DWX - major FX pair in the Fielder dead-time session universe.
- EURJPY.DWX - liquid JPY cross in the Fielder dead-time session universe.
- GBPJPY.DWX - liquid JPY cross in the Fielder dead-time session universe.
- AUDJPY.DWX - liquid JPY cross in the Fielder dead-time session universe.

**Explicitly NOT for:**
- Index, metal, and energy `.DWX` symbols - the source card is an FX session-cycle scalp and does not authorize non-FX expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | 45-90 minutes, hard stop at 2 hours |
| Expected drawdown profile | Fixed 1:1 pip risk with many small session trades. |
| Regime preference | mean-revert during low-volume FX dead time |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8c4e9a2-5d76-5f48-9c37-d6a4b1e5f3c8
**Source type:** book / educational cheat sheet
**Pointer:** Jason Fielder, "Forex Scalping Cheat Sheets" (Sharptrade Partners LLC / TriadFormula.com, 2010), Cheat Sheet #1, Off-Hours Scalping Strategy #2.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11915_fielder-deadtime-midpoint-reversion-h1.md`.

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
| v1 | 2026-06-23 | Initial build from card | 47709476-7a25-4ad2-b76e-4934d2517684 |
