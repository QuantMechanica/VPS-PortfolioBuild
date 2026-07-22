# QM5_20033_moc-imom — Strategy Spec

**EA ID:** QM5_20033
**Slug:** `moc-imom`
**Source:** `GAO-HAN-LI-ZHOU-2018`
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

The EA reads immutable, provenance-bearing cash-session timestamps and measures
the signed move during each market's first 30 minutes. A positive opening move
buys and a negative opening move sells at the start of the final cash-session
M30 interval. The hard stop is one frozen opening-move distance from the actual
entry, there is no profit target or trailing logic, and any remainder is closed
at the governed cash-session close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_signal_tf` | `PERIOD_M30` | fixed M30 | Opening-return and final-interval signal timeframe. |
| `strategy_max_cost_r` | `0.10` | fixed 0.10 | Maximum commission-plus-spread cost as a fraction of initial risk. |
| `strategy_session_ledger_file` | `QM5_20033_cash_sessions.csv` | immutable file | Common-Files exchange-session and early-close ledger. |
| `strategy_calendar_valid_through` | `2025.12.31` | fixed date | Required finite-study calendar horizon. |

Framework-level risk, news, seed, stress, and Friday-close inputs are documented
in `framework/V5_FRAMEWORK_DESIGN.md` and are not duplicated here.

---

## 3. Symbol Universe

**Designed for:**

- `SP500.DWX` — canonical S&P 500 route for the source's US large-cap market.
- `NDX.DWX` — Nasdaq 100 portability route exposed to closing-auction and ETF-rebalancing flow.
- `WS30.DWX` — Dow 30 portability route for the same US cash-close mechanism.
- `GDAXI.DWX` — DAX 40 portability test using governed Xetra session timestamps.

**Explicitly NOT for:**

- All other `.DWX` symbols — the approved card authorizes only these four index routes.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 250 before calendar and cost gates |
| Typical hold time | one final cash-session M30 interval |
| Expected drawdown profile | approximately 13% prior, concentrated in index cash-close reversals |
| Regime preference | closing-auction intraday momentum |
| Win rate target (qualitative) | medium; expected PF prior 1.35 |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `GAO-HAN-LI-ZHOU-2018`
**Source type:** academic paper
**Pointer:** Gao, Han, Li & Zhou (2018), JFE 129(2):394–414, DOI `10.1016/j.jfineco.2018.05.009`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_20033_moc-imom.md`

The paper supports same-direction continuation from the first half-hour into
the final half-hour. Exact CFD routes, session ledgers, stop construction, cost
gate, and cash-close handling are explicit QuantMechanica interpretations from
the approved card.

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
| v1 | 2026-07-22 | Initial build from card | `d6c25ce6-d80e-4b25-bbf3-f1d4ecdd2b2d` |
