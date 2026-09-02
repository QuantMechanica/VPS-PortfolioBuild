# QM5_41142_eurusd-month-end-benchmark-fix-hedge-flow — Strategy Spec

**EA ID:** QM5_41142
**Slug:** eurusd-month-end-benchmark-fix-hedge-flow
**Source:** MELVIN-PRINS-LONDON-FIX-2015
**Author of this spec:** Codex
**Last revised:** 2026-09-02

---

## 1. Strategy Logic

On the last Europe/London business day of each month, the EA takes one decision
at the first executable M15 bar at or after 14:00 London. It measures the
completed GDAXI.DWX month-to-date return from the preceding month's final
available M15 close to the latest completed GDAXI M15 close at the decision
time (normally the bar ending at 14:00 London); a positive return sells
EURUSD.DWX, a negative return buys it, and exact zero consumes the date without
a trade. The entry carries a two-times completed H1 ATR(14) hard stop and is
flattened at 16:00 London, with no re-entry or post-fix reversal.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| entry_lead_minutes | 120 | locked 120 | Minutes before the 16:00 London fix at which the signal is anchored |
| atr_period_h1 | 14 | locked 14 | Completed H1 ATR period for the initial hard stop |
| hard_stop_atr | 2.0 | locked 2.0 | Initial hard-stop distance in completed H1 ATR units |

## 3. Symbol Universe

**Designed for:**

- EURUSD.DWX — the only execution carrier, registered in slot 0 with magic 411420000.
- GDAXI.DWX — signal-only local-equity proxy used for the month-to-date sign; it never receives an order and has no magic row.

**Explicitly not for:**

- Other FX carriers or equity indices; changing either leg changes the card's economic translation and requires a new identity.
- Post-fix reversal trading, multi-leg hedges, scale-ins, grids, martingale, or overnight exposure.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base and execution timeframe | M15 |
| Multi-timeframe reference | completed EURUSD.DWX H1 ATR(14) for the stop |
| Cross-series reference | latest completed GDAXI.DWX M15 bar at the first executable decision at or after 14:00 London |
| Bar gating | one QM_IsNewBar(EURUSD.DWX, PERIOD_M15) consume per tick |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Eligible dates / year / symbol | approximately 12 before no-trade filters |
| Card frontmatter frequency | expected_trades_per_year_per_symbol: 100, inconsistent with the once-per-month mechanics; Q02 measures the literal mechanics |
| Typical hold time | zero to two hours, always flat at the 16:00 London fix |
| Regime preference | month-end benchmark hedge flows following positive or negative German-equity month-to-date returns |
| Drawdown profile | sparse event-window losses, including gap/slippage risk around month-end macro releases |

## 6. Source Citation

**Source ID:** MELVIN-PRINS-LONDON-FIX-2015
**Citation:** Michael Melvin and John Prins (2015), “Equity Hedging and Exchange Rates at the London 4 p.m. Fix,” *Journal of Financial Markets* 22, 50–72, DOI 10.1016/j.finmar.2014.11.001.
**Card pointer:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_41142_eurusd-month-end-benchmark-fix-hedge-flow.md
**R1–R4 verdict:** Tier-A R1 lineage recorded and R2–R4 PASS in the OWNER-approved card. GDAXI direction is explicitly a QuantMechanica implementation proxy, not a statistic transferred from the paper.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | RISK_FIXED | $1,000 per trade with RISK_PERCENT=0 |
| Live | not authorized by this build | Any future live risk requires the governed downstream portfolio and deployment gates |

The hard stop is installed from the actual directional fill geometry and is
never widened. Framework spread validation, account-loss, kill-switch, and
Friday safety controls remain authoritative.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | Initial build from approved card | build task 9d978a4c-4161-4e15-982d-0d1c56b696a7; fleet claim f3fba72c-a3be-453e-9e15-830e46135c53 |
